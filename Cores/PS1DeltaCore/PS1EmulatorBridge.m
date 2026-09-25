#import "PS1EmulatorBridge.h"
#import "PS1DiscControl.h"

@import DeltaCore;

#import <dlfcn.h>
#import <stdlib.h>
#import <string.h>

#define CORE_FUNCTION(name) static __typeof__(&name) core_##name
CORE_FUNCTION(retro_init);
CORE_FUNCTION(retro_deinit);
CORE_FUNCTION(retro_set_environment);
CORE_FUNCTION(retro_set_video_refresh);
CORE_FUNCTION(retro_set_audio_sample_batch);
CORE_FUNCTION(retro_set_input_poll);
CORE_FUNCTION(retro_set_input_state);
CORE_FUNCTION(retro_load_game);
CORE_FUNCTION(retro_unload_game);
CORE_FUNCTION(retro_run);
CORE_FUNCTION(retro_get_system_av_info);
CORE_FUNCTION(retro_get_memory_data);
CORE_FUNCTION(retro_get_memory_size);
CORE_FUNCTION(retro_serialize_size);
CORE_FUNCTION(retro_serialize);
CORE_FUNCTION(retro_unserialize);

static PS1EmulatorBridge *activeBridge;
static char *systemPath;
static uint16_t buttons[2];
static unsigned previousVideoWidth, previousVideoHeight;

static bool environmentCallback(unsigned command, void *data);
static void videoCallback(const void *data, unsigned width, unsigned height, size_t pitch);
static size_t audioCallback(const int16_t *samples, size_t frames);
static void inputPollCallback(void);
static int16_t inputStateCallback(unsigned port, unsigned device, unsigned index, unsigned id);

@interface PS1EmulatorBridge ()
@property (nonatomic, copy, nullable, readwrite) NSURL *gameURL;
@property (nonatomic, copy, nullable) NSString *systemDirectory;
@property (nonatomic, assign) BOOL shouldRender;
@property (nonatomic, assign) BOOL hasVideo;
@property (nonatomic, assign) NSTimeInterval frameDuration;
@property (nonatomic, assign) struct retro_disk_control_ext_callback diskControl;
@property (nonatomic, assign) BOOL hasDiskControl;
@end

@implementation PS1EmulatorBridge
{
    void *_library;
}
@synthesize audioRenderer = _audioRenderer;
@synthesize videoRenderer = _videoRenderer;
@synthesize saveUpdateHandler = _saveUpdateHandler;

+ (instancetype)sharedBridge
{
    static PS1EmulatorBridge *bridge;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ bridge = [self new]; });
    return bridge;
}

- (instancetype)init
{
    if ((self = [super init])) _frameDuration = 1.0 / 60.0;
    return self;
}

- (void)startWithGameURL:(NSURL *)gameURL
{
    self.hasDiskControl = NO;
    self.gameURL = gameURL;
    self.systemDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"Cores/PS1"];
    [[NSFileManager defaultManager] createDirectoryAtPath:self.systemDirectory withIntermediateDirectories:YES attributes:nil error:nil];
    systemPath = strdup(self.systemDirectory.fileSystemRepresentation);

    NSString *path = [[NSBundle mainBundle].privateFrameworksPath stringByAppendingPathComponent:@"pcsx_rearmed_libretro_ios.dylib"];
    _library = dlopen(path.fileSystemRepresentation, RTLD_NOW | RTLD_LOCAL);
    if (!_library) {
        NSLog(@"PCSX ReARMed load failed: %s", dlerror());
        return;
    }

#define LOAD(name) do { core_##name = (__typeof__(core_##name))dlsym(_library, #name); if (!core_##name) { NSLog(@"PCSX ReARMed missing %s", #name); [self stop]; return; } } while (0)
    LOAD(retro_init);
    LOAD(retro_deinit);
    LOAD(retro_set_environment);
    LOAD(retro_set_video_refresh);
    LOAD(retro_set_audio_sample_batch);
    LOAD(retro_set_input_poll);
    LOAD(retro_set_input_state);
    LOAD(retro_load_game);
    LOAD(retro_unload_game);
    LOAD(retro_run);
    LOAD(retro_get_system_av_info);
    LOAD(retro_get_memory_data);
    LOAD(retro_get_memory_size);
    LOAD(retro_serialize_size);
    LOAD(retro_serialize);
    LOAD(retro_unserialize);
#undef LOAD

    activeBridge = self;
    core_retro_set_environment(environmentCallback);
    core_retro_set_video_refresh(videoCallback);
    core_retro_set_audio_sample_batch(audioCallback);
    core_retro_set_input_poll(inputPollCallback);
    core_retro_set_input_state(inputStateCallback);
    core_retro_init();

    struct retro_game_info info = { .path = gameURL.fileSystemRepresentation };
    if (!core_retro_load_game(&info)) {
        NSLog(@"PCSX ReARMed could not load %@", gameURL);
        core_retro_deinit();
        activeBridge = nil;
        dlclose(_library);
        _library = NULL;
        return;
    }

    struct retro_system_av_info avInfo;
    core_retro_get_system_av_info(&avInfo);
    if (avInfo.timing.fps > 0) self.frameDuration = 1.0 / avInfo.timing.fps;
}

- (void)stop
{
    if (activeBridge == self && core_retro_unload_game) {
        core_retro_unload_game();
        core_retro_deinit();
        activeBridge = nil;
    }
    if (_library) dlclose(_library);
    _library = NULL;
    self.hasDiskControl = NO;
    free(systemPath);
    systemPath = NULL;
    self.gameURL = nil;
    previousVideoWidth = previousVideoHeight = 0;
    [self resetInputs];
}

- (void)pause {}
- (void)resume {}

- (void)runFrameAndProcessVideo:(BOOL)processVideo
{
    if (activeBridge != self) return;
    self.shouldRender = processVideo;
    self.hasVideo = NO;
    core_retro_run();
    if (processVideo && self.hasVideo) [self.videoRenderer processFrame];
}

- (void)activateInput:(NSInteger)input value:(double)value playerIndex:(NSInteger)playerIndex
{
    if (playerIndex >= 0 && playerIndex < 2 && input >= 0 && input < 16) buttons[playerIndex] |= 1u << input;
}

- (void)deactivateInput:(NSInteger)input playerIndex:(NSInteger)playerIndex
{
    if (playerIndex >= 0 && playerIndex < 2 && input >= 0 && input < 16) buttons[playerIndex] &= ~(1u << input);
}

- (void)resetInputs { buttons[0] = buttons[1] = 0; }

- (NSArray<NSString *> *)discLabels
{
    if (activeBridge != self || !self.hasDiskControl) return @[];
    NSMutableArray<NSString *> *labels = [NSMutableArray array];
    unsigned count = self.diskControl.get_num_images();
    for (unsigned index = 0; index < count; index++) {
        char label[1024] = {0};
        NSString *name = self.diskControl.get_image_label(index, label, sizeof(label)) ? [NSString stringWithUTF8String:label] : nil;
        [labels addObject:name.length ? name : [NSString stringWithFormat:@"Disc %u", index + 1]];
    }
    return labels;
}

- (NSInteger)currentDiscIndex
{
    return activeBridge == self && self.hasDiskControl ? self.diskControl.get_image_index() : NSNotFound;
}

- (BOOL)swapToDiscAtIndex:(NSUInteger)index
{
    if (activeBridge != self || !self.hasDiskControl || index >= self.diskControl.get_num_images()) return NO;
    return PS1SwapDisc(&_diskControl, (unsigned)index);
}

- (void)saveGameSaveToURL:(NSURL *)url
{
    if (activeBridge != self) return;
    void *memory = core_retro_get_memory_data(RETRO_MEMORY_SAVE_RAM);
    size_t size = core_retro_get_memory_size(RETRO_MEMORY_SAVE_RAM);
    if (memory && size) [[NSData dataWithBytes:memory length:size] writeToURL:url atomically:YES];
}

- (void)loadGameSaveFromURL:(NSURL *)url
{
    if (activeBridge != self) return;
    NSData *data = [NSData dataWithContentsOfURL:url];
    void *memory = core_retro_get_memory_data(RETRO_MEMORY_SAVE_RAM);
    size_t size = core_retro_get_memory_size(RETRO_MEMORY_SAVE_RAM);
    if (memory && size && data.length == size) memcpy(memory, data.bytes, size);
}

- (void)saveSaveStateToURL:(NSURL *)url
{
    if (activeBridge != self) return;
    size_t size = core_retro_serialize_size();
    NSMutableData *data = [NSMutableData dataWithLength:size];
    if (size && core_retro_serialize(data.mutableBytes, size)) [data writeToURL:url atomically:YES];
}

- (void)loadSaveStateFromURL:(NSURL *)url
{
    if (activeBridge != self) return;
    NSData *data = [NSData dataWithContentsOfURL:url];
    if (data.length == core_retro_serialize_size()) core_retro_unserialize(data.bytes, data.length);
}

- (BOOL)addCheatCode:(NSString *)code type:(NSString *)type { return NO; }
- (void)resetCheats {}
- (void)updateCheats {}

static bool environmentCallback(unsigned command, void *data)
{
    switch (command) {
        case RETRO_ENVIRONMENT_GET_DISK_CONTROL_INTERFACE_VERSION:
            *(unsigned *)data = 1;
            return true;
        case RETRO_ENVIRONMENT_SET_DISK_CONTROL_EXT_INTERFACE:
            activeBridge.diskControl = *(struct retro_disk_control_ext_callback *)data;
            activeBridge.hasDiskControl = YES;
            return true;
        case RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY:
        case RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY:
            *(const char **)data = systemPath;
            return systemPath != NULL;
        case RETRO_ENVIRONMENT_GET_VARIABLE: {
            struct retro_variable *variable = data;
            if (!strcmp(variable->key, "pcsx_rearmed_memcard1")) variable->value = "libretro";
            else if (!strcmp(variable->key, "pcsx_rearmed_memcard2")) variable->value = "none";
            else variable->value = NULL;
            return variable->value != NULL;
        }
        case RETRO_ENVIRONMENT_GET_VARIABLE_UPDATE:
            *(bool *)data = false;
            return true;
        case RETRO_ENVIRONMENT_SET_PIXEL_FORMAT:
            return *(enum retro_pixel_format *)data == RETRO_PIXEL_FORMAT_RGB565;
        case RETRO_ENVIRONMENT_GET_CAN_DUPE:
            *(bool *)data = true;
            return true;
        default: return false;
    }
}

static void videoCallback(const void *data, unsigned width, unsigned height, size_t pitch)
{
    PS1EmulatorBridge *bridge = activeBridge;
    if (!bridge.shouldRender || !data || width > 1024 || height > 512 || pitch < width * 2) return;
    uint8_t *destination = bridge.videoRenderer.videoBuffer;
    if (!destination) return;
    for (unsigned row = 0; row < height; row++) {
        memcpy(destination + row * 1024 * 2, (const uint8_t *)data + row * pitch, width * 2);
    }
    bridge.videoRenderer.viewport = CGRectMake(0, 0, width, height);
    bridge.hasVideo = YES;
    if (width != previousVideoWidth || height != previousVideoHeight) {
        previousVideoWidth = width;
        previousVideoHeight = height;
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:@"PS1VideoDimensionsDidChange" object:nil
                                                              userInfo:@{@"height": @(height)}];
        });
    }
}

static size_t audioCallback(const int16_t *samples, size_t frames)
{
    [activeBridge.audioRenderer.audioBuffer writeBuffer:samples size:frames * 2 * sizeof(int16_t)];
    return frames;
}

static void inputPollCallback(void) {}

static int16_t inputStateCallback(unsigned port, unsigned device, unsigned index, unsigned id)
{
    if (port >= 2 || device != RETRO_DEVICE_JOYPAD || index != 0 || id >= 16) return 0;
    return (buttons[port] & (1u << id)) != 0;
}

@end
