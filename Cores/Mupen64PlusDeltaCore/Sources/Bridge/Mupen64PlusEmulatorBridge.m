//
//  Mupen64PlusEmulatorBridge.m
//  Mupen64PlusDeltaCore
//
//  Created by Riley Testut on 3/27/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

#import "Mupen64PlusEmulatorBridge.h"

#import <DeltaCore/DeltaCore-Swift.h>

#if STATIC_LIBRARY
#import "Mupen64PlusDeltaCore-Swift.h"
#else
#import <Mupen64PlusDeltaCore/Mupen64PlusDeltaCore-Swift.h>
#endif

#define M64P_CORE_PROTOTYPES
#define N64_ANALOG_MAX 80

#include "api/m64p_common.h"
#include "api/m64p_config.h"
#include "api/m64p_frontend.h"
#include "api/m64p_vidext.h"
#include "api/callbacks.h"
#include "main/rom.h"
#include "main/savestates.h"
#include "main/cheat.h"
#include "osal/dynamiclib.h"
#include "main/version.h"
#include "main/main.h"
#include "osd.h"
#include "backends/api/storage_backend.h"
#include "backends/file_storage.h"

#include "plugin/plugin.h"

#import <dlfcn.h>
#import <mach-o/ldsyms.h>

m64p_error CALL Video_PluginStartup(m64p_dynlib_handle CoreLibHandle, void *Context, void (*DebugCallback)(void *, int, const char *));
m64p_error CALL Video_PluginShutdown(void);
m64p_error CALL Video_PluginGetVersion(m64p_plugin_type *PluginType, int *PluginVersion, int *APIVersion, const char **PluginNamePtr, int *Capabilities);
int  CALL Video_RomOpen(void);
void CALL Video_RomClosed(void);

m64p_error CALL RSP_PluginStartup(m64p_dynlib_handle CoreLibHandle, void *Context, void (*DebugCallback)(void *, int, const char *));
m64p_error CALL RSP_PluginShutdown(void);
m64p_error CALL RSP_PluginGetVersion(m64p_plugin_type *PluginType, int *PluginVersion, int *APIVersion, const char **PluginNamePtr, int *Capabilities);
void CALL RSP_RomClosed(void);

@interface Mupen64PlusEmulatorBridge () <DLTAEmulatorBridging>
{
@public
    double inputs[20];
}

@property (nonatomic, copy, nullable, readwrite) NSURL *gameURL;

@property (nonatomic, readonly) NSURL *gameSaveDirectoryURL;
@property (nonatomic, readonly) NSURL *configDirectoryURL;

@property (nonatomic, assign) BOOL isNTSC;
@property (nonatomic, assign) double sampleRate;

@property (nonatomic, strong) dispatch_semaphore_t beginFrameSemaphore;
@property (nonatomic, strong) dispatch_semaphore_t endFrameSemaphore;
@property (nonatomic, strong) dispatch_semaphore_t stopEmulationSemaphore;

@property (nonatomic) BOOL didLoadPlugins;
@property (nonatomic, assign, getter=isRunning) BOOL running;

@property (nonatomic, strong, readonly) NSMutableDictionary<NSNumber *, void (^)(void)> *stateCallbacks;

@property (nonatomic, strong, readwrite) AVAudioFormat *preferredAudioFormat;
@property (nonatomic, readwrite) CGSize preferredVideoDimensions;

@property (nonatomic, strong) NSMutableSet *activeCheats;
@property (nonatomic) m64p_plugin_type activePluginType;

@end

@implementation Mupen64PlusEmulatorBridge
@synthesize audioRenderer = _audioRenderer;
@synthesize videoRenderer = _videoRenderer;
@synthesize saveUpdateHandler = _saveUpdateHandler;

static void MupenDebugCallback(void *context, int level, const char *message)
{
    NSLog(@"Mupen (%d): %s", level, message);
}

static void MupenStateCallback(void *context, m64p_core_param paramType, int newValue)
{
    NSLog(@"Mupen: param %d -> %d", paramType, newValue);
    
    void (^callback)(void) = Mupen64PlusEmulatorBridge.sharedBridge.stateCallbacks[@(paramType)];
    
    if (callback)
    {
        callback();
    }
    
    Mupen64PlusEmulatorBridge.sharedBridge.stateCallbacks[@(paramType)] = nil;
}

static void *dlopen_Mupen64PlusDeltaCore()
{
    Dl_info info;
    
    dladdr((void *)dlopen_Mupen64PlusDeltaCore, &info);
    
    return dlopen(info.dli_fname, RTLD_LAZY | RTLD_NOLOAD);
}

static void MupenGetKeys(int Control, BUTTONS *Keys)
{
    Keys->R_DPAD = Mupen64PlusEmulatorBridge.sharedBridge->inputs[Mupen64PlusGameInputRight];
    Keys->L_DPAD = Mupen64PlusEmulatorBridge.sharedBridge->inputs[Mupen64PlusGameInputLeft];
    Keys->D_DPAD = Mupen64PlusEmulatorBridge.sharedBridge->inputs[Mupen64PlusGameInputDown];
    Keys->U_DPAD = Mupen64PlusEmulatorBridge.sharedBridge->inputs[Mupen64PlusGameInputUp];
    Keys->START_BUTTON = Mupen64PlusEmulatorBridge.sharedBridge->inputs[Mupen64PlusGameInputStart];
    Keys->Z_TRIG = Mupen64PlusEmulatorBridge.sharedBridge->inputs[Mupen64PlusGameInputZ];
    Keys->B_BUTTON = Mupen64PlusEmulatorBridge.sharedBridge->inputs[Mupen64PlusGameInputB];
    Keys->A_BUTTON = Mupen64PlusEmulatorBridge.sharedBridge->inputs[Mupen64PlusGameInputA];
    Keys->R_CBUTTON = Mupen64PlusEmulatorBridge.sharedBridge->inputs[Mupen64PlusGameInputCRight];
    Keys->L_CBUTTON = Mupen64PlusEmulatorBridge.sharedBridge->inputs[Mupen64PlusGameInputCLeft];
    Keys->D_CBUTTON = Mupen64PlusEmulatorBridge.sharedBridge->inputs[Mupen64PlusGameInputCDown];
    Keys->U_CBUTTON = Mupen64PlusEmulatorBridge.sharedBridge->inputs[Mupen64PlusGameInputCUp];
    Keys->R_TRIG = Mupen64PlusEmulatorBridge.sharedBridge->inputs[Mupen64PlusGameInputR];
    Keys->L_TRIG = Mupen64PlusEmulatorBridge.sharedBridge->inputs[Mupen64PlusGameInputL];
    
    if (Mupen64PlusEmulatorBridge.sharedBridge->inputs[Mupen64PlusGameInputAnalogStickLeft])
    {
        Keys->X_AXIS = Mupen64PlusEmulatorBridge.sharedBridge->inputs[Mupen64PlusGameInputAnalogStickLeft] * -N64_ANALOG_MAX;
    }
    else if (Mupen64PlusEmulatorBridge.sharedBridge->inputs[Mupen64PlusGameInputAnalogStickRight])
    {
        Keys->X_AXIS = Mupen64PlusEmulatorBridge.sharedBridge->inputs[Mupen64PlusGameInputAnalogStickRight] * N64_ANALOG_MAX;
    }
    else
    {
        Keys->X_AXIS = 0.0;
    }
    
    if (Mupen64PlusEmulatorBridge.sharedBridge->inputs[Mupen64PlusGameInputAnalogStickUp])
    {
        Keys->Y_AXIS = Mupen64PlusEmulatorBridge.sharedBridge->inputs[Mupen64PlusGameInputAnalogStickUp] * N64_ANALOG_MAX;
    }
    else if (Mupen64PlusEmulatorBridge.sharedBridge->inputs[Mupen64PlusGameInputAnalogStickDown])
    {
        Keys->Y_AXIS = Mupen64PlusEmulatorBridge.sharedBridge->inputs[Mupen64PlusGameInputAnalogStickDown] * -N64_ANALOG_MAX;
    }
    else
    {
        Keys->Y_AXIS = 0.0;
    }
}

static void MupenInitiateControllers (CONTROL_INFO ControlInfo)
{
    ControlInfo.Controls[0].Present = 1;
    ControlInfo.Controls[0].Plugin = PLUGIN_RAW;
    ControlInfo.Controls[1].Present = 0;
    ControlInfo.Controls[1].Plugin = PLUGIN_MEMPAK;
    ControlInfo.Controls[2].Present = 0;
    ControlInfo.Controls[2].Plugin = PLUGIN_MEMPAK;
    ControlInfo.Controls[3].Present = 0;
    ControlInfo.Controls[3].Plugin = PLUGIN_MEMPAK;
}

static void MupenControllerCommand(int Control, unsigned char *Command)
{
}

static AUDIO_INFO AudioInfo;

static void MupenAudioSampleRateChanged(int SystemType)
{
    double previousSampleRate = Mupen64PlusEmulatorBridge.sharedBridge.preferredAudioFormat.sampleRate;
    double sampleRate = 0.0;
    
    switch (SystemType)
    {
        default:
        case SYSTEM_NTSC:
            sampleRate = 48681812 / (*AudioInfo.AI_DACRATE_REG + 1);
            break;
        case SYSTEM_PAL:
            sampleRate = 49656530 / (*AudioInfo.AI_DACRATE_REG + 1);
            break;
    }
    
    NSLog(@"Mupen rate changed %f -> %f\n", previousSampleRate, sampleRate);
    
    Mupen64PlusEmulatorBridge.sharedBridge.preferredAudioFormat = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatInt16 sampleRate:sampleRate channels:2 interleaved:YES];
}

static void MupenAudioLenChanged()
{
    int LenReg = *AudioInfo.AI_LEN_REG;
    uint8_t *ptr = (uint8_t*)(AudioInfo.RDRAM + (*AudioInfo.AI_DRAM_ADDR_REG & 0xFFFFFF));
    
    // Swap channels
    for (uint32_t i = 0; i < LenReg; i += 4)
    {
        ptr[i] ^= ptr[i + 2];
        ptr[i + 2] ^= ptr[i];
        ptr[i] ^= ptr[i + 2];
        ptr[i + 1] ^= ptr[i + 3];
        ptr[i + 3] ^= ptr[i + 1];
        ptr[i + 1] ^= ptr[i + 3];
    }
    
    [Mupen64PlusEmulatorBridge.sharedBridge.audioRenderer.audioBuffer writeBuffer:ptr size:LenReg];
}

static void SetIsNTSC()
{
    switch (ROM_HEADER.Country_code & 0xFF)
    {
        case 0x44:
        case 0x46:
        case 0x49:
        case 0x50:
        case 0x53:
        case 0x55:
        case 0x58:
        case 0x59:
            Mupen64PlusEmulatorBridge.sharedBridge.isNTSC = NO;
            break;
            
        case 0x37:
        case 0x41:
        case 0x45:
        case 0x4a:
            Mupen64PlusEmulatorBridge.sharedBridge.isNTSC = YES;
            break;
    }
}

static int MupenOpenAudio(AUDIO_INFO info)
{
    AudioInfo = info;
    
    SetIsNTSC();
    
    return M64ERR_SUCCESS;
}

static void MupenSetAudioSpeed(int percent)
{
}

+ (instancetype)sharedBridge
{
    static Mupen64PlusEmulatorBridge *_emulatorBridge = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _emulatorBridge = [[self alloc] init];
    });
    
    return _emulatorBridge;
}

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _beginFrameSemaphore = dispatch_semaphore_create(0);
        _endFrameSemaphore = dispatch_semaphore_create(0);
        _stopEmulationSemaphore = dispatch_semaphore_create(0);
        
        _stateCallbacks = [NSMutableDictionary dictionary];
        
        _preferredAudioFormat = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatInt16 sampleRate:44100 channels:2 interleaved:YES];
        _preferredVideoDimensions = CGSizeMake(640, 480);
        
        _activeCheats = [NSMutableSet set];
    }
    
    return self;
}

#pragma mark - Emulation State -

- (void)startWithGameURL:(NSURL *)gameURL
{
    self.gameURL = gameURL;
    
    /* Copy .ini files */
    NSArray<NSString *> *iniFiles = @[@"GLideN64", @"GLideN64.custom", @"mupen64plus"];
    for (NSString *filename in iniFiles)
    {
        NSURL *sourceURL = [Mupen64PlusEmulatorBridge.n64Resources URLForResource:filename withExtension:@"ini"];
        NSURL *destinationURL = [[Mupen64PlusEmulatorBridge.coreDirectoryURL URLByAppendingPathComponent:filename] URLByAppendingPathExtension:@"ini"];
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:destinationURL.path isDirectory:nil])
        {
            continue;
        }
        
        NSError *error = nil;
        if (![[NSFileManager defaultManager] copyItemAtURL:sourceURL toURL:destinationURL error:&error])
        {
            NSLog(@"Error copying %@. %@", filename, error);
        }
    }
    
    /* Prepare Emulation */
    CoreStartup(FRONTEND_API_VERSION, self.configDirectoryURL.fileSystemRepresentation, Mupen64PlusEmulatorBridge.coreDirectoryURL.fileSystemRepresentation, (__bridge void *)self, MupenDebugCallback, (__bridge void *)self, MupenStateCallback);
    
    /* Configure Core */
    m64p_handle config;
    ConfigOpenSection("Core", &config);
    
    ConfigSetParameter(config, "SaveSRAMPath", M64TYPE_STRING, self.gameSaveDirectoryURL.fileSystemRepresentation);
    ConfigSetParameter(config, "SharedDataPath", M64TYPE_STRING, Mupen64PlusEmulatorBridge.coreDirectoryURL.fileSystemRepresentation);
    
    // Pure Interpreter = 0, Cached Interpreter = 1, Dynamic Recompiler = 2
    int emulationMode = 1;
    ConfigSetParameter(config, "R4300Emulator", M64TYPE_INT, &emulationMode);
    
    ConfigSaveSection("Core");
    
    
    /* Configure Video */
    m64p_handle video;
    ConfigOpenSection("Video-General", &video);
    
    int useFullscreen = 1;
    ConfigSetParameter(video, "Fullscreen", M64TYPE_BOOL, &useFullscreen);
    
    int screenWidth = 640;
    ConfigSetParameter(video, "ScreenWidth", M64TYPE_INT, &screenWidth);
    
    int screenHeight = 480;
    ConfigSetParameter(video, "ScreenHeight", M64TYPE_INT, &screenHeight);
    
    ConfigSaveSection("Video-General");
    
    
    /* Configure GLideN64 */
    m64p_handle gliden64;
    ConfigOpenSection("Video-GLideN64", &gliden64);
    
    // 0 = stretch, 1 = 4:3, 2 = 16:9, 3 = adjust
    int aspectRatio = 1;
    ConfigSetParameter(gliden64, "AspectRatio", M64TYPE_INT, &aspectRatio);
    
    int enablePerPixelLighting = 1;
    ConfigSetParameter(gliden64, "EnableHWLighting", M64TYPE_BOOL, &enablePerPixelLighting);
    
    int osd = 0;
    ConfigSetParameter(gliden64, "OnScreenDisplay", M64TYPE_BOOL, &osd);
    ConfigSetParameter(gliden64, "ShowFPS", M64TYPE_BOOL, &osd);
    ConfigSetParameter(gliden64, "ShowVIS", M64TYPE_BOOL, &osd);
    ConfigSetParameter(gliden64, "ShowPercent", M64TYPE_BOOL, &osd);
    ConfigSetParameter(gliden64, "ShowInternalResolution", M64TYPE_BOOL, &osd);
    ConfigSetParameter(gliden64, "ShowRenderingResolution", M64TYPE_BOOL, &osd);
    
    ConfigSaveSection("Video-GLideN64");
    
    NSData *romData = [NSData dataWithContentsOfURL:gameURL options:NSDataReadingMappedAlways error:nil];
    if (romData.length == 0)
    {
        NSLog(@"Error loading ROM at path: %@\n File does not exist.", gameURL);
        return;
    }
    
    m64p_error openStatus = CoreDoCommand(M64CMD_ROM_OPEN, (int)[romData length], (void *)[romData bytes]);
    if (openStatus != M64ERR_SUCCESS)
    {
        NSLog(@"Error loading ROM at path: %@\n Error code was: %i", gameURL, openStatus);
        return;
    }
    
    
    /* Prepare Audio */
    audio.aiDacrateChanged = MupenAudioSampleRateChanged;
    audio.aiLenChanged = MupenAudioLenChanged;
    audio.initiateAudio = MupenOpenAudio;
    audio.setSpeedFactor = MupenSetAudioSpeed;
    plugin_start(M64PLUGIN_AUDIO);
    
    /* Prepare Input */
    input.getKeys = MupenGetKeys;
    input.initiateControllers = MupenInitiateControllers;
    input.controllerCommand = MupenControllerCommand;
    plugin_start(M64PLUGIN_INPUT);
        
    if (![self didLoadPlugins])
    {
        /* Prepare Plugins */
        
#if STATIC_LIBRARY
        // Ensure symbols are _not_ stripped by referencing them from log statements.
        NSLog(@"Address of Video_PluginStartup: %p", Video_PluginStartup);
        NSLog(@"Address of Video_PluginShutdown: %p", Video_PluginShutdown);
        NSLog(@"Address of Video_PluginGetVersion: %p", Video_PluginGetVersion);
        NSLog(@"Address of Video_RomOpen: %p", Video_RomOpen);
        NSLog(@"Address of Video_RomClosed: %p", Video_RomClosed);
        
        NSLog(@"Address of RSP_PluginStartup: %p", RSP_PluginStartup);
        NSLog(@"Address of RSP_PluginShutdown: %p", RSP_PluginShutdown);
        NSLog(@"Address of RSP_PluginGetVersion: %p", RSP_PluginGetVersion);
        NSLog(@"Address of RSP_RomClosed: %p", RSP_RomClosed);
#endif
        
        BOOL didLoadVideoPlugin = [self loadPlugin:@"mupen64plus_video_GLideN64" type:M64PLUGIN_GFX];
        NSAssert(didLoadVideoPlugin, @"Failed to load video plugin.");
        
        BOOL didLoadRSPPlugin = [self loadPlugin:@"mupen64plus_rsp_hle" type:M64PLUGIN_RSP];
        NSAssert(didLoadRSPPlugin, @"Failed to load RSP plugin.");
        
        self.didLoadPlugins = YES;
    }
    
    self.running = YES;
    
    [NSThread detachNewThreadSelector:@selector(startEmulationLoop) toTarget:self withObject:nil];
    
    dispatch_semaphore_wait(self.endFrameSemaphore, DISPATCH_TIME_FOREVER);
}

- (void)startEmulationLoop
{
    @autoreleasepool
    {
        [self.videoRenderer prepare];
        
        CoreDoCommand(M64CMD_EXECUTE, 0, NULL);
        
        dispatch_semaphore_signal(self.stopEmulationSemaphore);
    }
}

- (void)stop
{
    CoreDoCommand(M64CMD_STOP, 0, NULL);
    
    dispatch_semaphore_signal(self.beginFrameSemaphore);
    dispatch_semaphore_wait(self.stopEmulationSemaphore, DISPATCH_TIME_FOREVER);
    
    CoreDoCommand(M64CMD_ROM_CLOSE, 0, NULL);
    
    [self.activeCheats removeAllObjects];
    
    self.running = NO;    
}

- (void)pause
{
    self.running = NO;
}

- (void)resume
{
    self.running = YES;
}

#pragma mark - Game Loop -

- (void)runFrameAndProcessVideo:(BOOL)processVideo
{
    dispatch_semaphore_signal(self.beginFrameSemaphore);
    
    dispatch_semaphore_wait(self.endFrameSemaphore, DISPATCH_TIME_FOREVER);
}

#pragma mark - Inputs -

- (void)activateInput:(NSInteger)input
{
    inputs[input] = 1;
}

- (void)activateInput:(NSInteger)input value:(double)value
{
    inputs[input] = value;
}

- (void)deactivateInput:(NSInteger)input
{
    inputs[input] = 0;
}

- (void)resetInputs
{
    for (NSInteger input = 0; input < 18; input++)
    {
        [self deactivateInput:input];
    }
}

#pragma mark - Save States -

- (void)saveSaveStateToURL:(NSURL *)url
{
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [self registerCallbackForType:M64CORE_STATE_SAVECOMPLETE callback:^{
        dispatch_semaphore_signal(semaphore);
    }];
    
    CoreDoCommand(M64CMD_STATE_SAVE, 1, (void *)[url fileSystemRepresentation]);
    
    if (![self isRunning])
    {
        [self runFrameAndProcessVideo:YES];
    }
    
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
}

- (void)loadSaveStateFromURL:(NSURL *)url
{
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [self registerCallbackForType:M64CORE_STATE_LOADCOMPLETE callback:^{
        dispatch_semaphore_signal(semaphore);
    }];
    
    CoreDoCommand(M64CMD_STATE_LOAD, 1, (void *)[url fileSystemRepresentation]);
    
    if (![self isRunning])
    {
        [self runFrameAndProcessVideo:YES];
    }
    
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
}

#pragma mark - Game Saves -

- (void)saveGameSaveToURL:(NSURL *)url
{
    struct file_storage *storage = NULL;
    
    if (g_dev.cart.use_flashram == -1)
    {
        storage = (struct file_storage *)g_dev.cart.sram.storage;
    }
    else if (g_dev.cart.use_flashram == 0)
    {
        storage = (struct file_storage *)g_dev.cart.eeprom.storage;
    }
    else if (g_dev.cart.use_flashram == 1)
    {
        storage = (struct file_storage *)g_dev.cart.flashram.storage;
    }
    
    NSData *data = [NSData dataWithBytes:storage->data length:storage->size];
    [data writeToURL:url atomically:YES];
}

- (void)loadGameSaveFromURL:(NSURL *)url
{
    struct file_storage *storage = NULL;
    
    if (g_dev.cart.use_flashram == -1)
    {
        storage = (struct file_storage *)g_dev.cart.sram.storage;
    }
    else if (g_dev.cart.use_flashram == 0)
    {
        storage = (struct file_storage *)g_dev.cart.eeprom.storage;
    }
    else if (g_dev.cart.use_flashram == 1)
    {
        storage = (struct file_storage *)g_dev.cart.flashram.storage;
    }
    
    NSData *saveData = [NSData dataWithContentsOfURL:url];
    if (saveData == nil)
    {
        memset(storage->data, 0xFF, storage->size);
    }
    else
    {
        memcpy(storage->data, saveData.bytes, storage->size);
    }
}

#pragma mark - Cheats -

- (BOOL)addCheatCode:(NSString *)cheatCode type:(NSString *)type
{
    if ([self.activeCheats containsObject:cheatCode])
    {
        CoreCheatEnabled([cheatCode UTF8String], 1);
        return YES;
    }
    
    NSArray<NSString *> *codes = [cheatCode componentsSeparatedByString:@"\n"];
    m64p_cheat_code *codeList = (m64p_cheat_code *)calloc(codes.count, sizeof(m64p_cheat_code));
    
    for (int i = 0; i < codes.count; i++)
    {
        NSString *code = codes[i];
        code = [code stringByReplacingOccurrencesOfString:@" " withString:@""];
        
        if (code.length != 12)
        {
            return NO;
        }
        
        m64p_cheat_code *gsCode = codeList + i;
        
        NSString *address = [code substringWithRange:NSMakeRange(0, 8)];
        NSString *value = [code substringWithRange:NSMakeRange(8, 4)];
        
        unsigned int outAddress = 0;
        [[NSScanner scannerWithString:address] scanHexInt:&outAddress];
        
        unsigned int outValue = 0;
        [[NSScanner scannerWithString:value] scanHexInt:&outValue];
        
        gsCode->address = outAddress;
        gsCode->value = outValue;
    }
    
    if (CoreAddCheat([cheatCode UTF8String], codeList, codes.count) != M64ERR_SUCCESS)
    {
        return NO;
    }
    
    [self.activeCheats addObject:cheatCode];
    
    return YES;
}

- (void)resetCheats
{
    for (NSString *code in self.activeCheats)
    {
        CoreCheatEnabled([code UTF8String], 0);
    }
}

- (void)updateCheats
{
}

#pragma mark - Helper Methods -

- (void)processFrame
{
    [self.videoRenderer processFrame];
}

- (void)videoInterrupt
{
    dispatch_semaphore_signal(self.endFrameSemaphore);
    
    dispatch_semaphore_wait(self.beginFrameSemaphore, DISPATCH_TIME_FOREVER);
}

- (BOOL)loadPlugin:(NSString *)pluginName type:(m64p_plugin_type)type
{
    self.activePluginType = type;
    
    m64p_dynlib_handle mupen64PlusDeltaCoreHandle = dlopen_Mupen64PlusDeltaCore();
    
#if STATIC_LIBRARY
    m64p_dynlib_handle pluginHandle = mupen64PlusDeltaCoreHandle;
    ptr_PluginStartup pluginStart = (ptr_PluginStartup)osal_dynlib_getproc(pluginHandle, "PluginStartup");
#else
    NSString *frameworkPath = [NSString stringWithFormat:@"%@.framework/%@", pluginName, pluginName];
    NSString *pluginPath = [[[NSBundle mainBundle] privateFrameworksPath] stringByAppendingPathComponent:frameworkPath];
    
    m64p_dynlib_handle pluginHandle = dlopen([pluginPath fileSystemRepresentation], RTLD_LAZY | RTLD_LOCAL);
    ptr_PluginStartup pluginStart = dlsym(pluginHandle, "PluginStartup");
#endif
    
    m64p_error error = pluginStart(mupen64PlusDeltaCoreHandle, (__bridge void *)self, MupenDebugCallback);
    if (error != M64ERR_SUCCESS)
    {
        NSLog(@"Error code %@ loading plugin of type %@, name: %@", @(error), @(type), pluginName);
        self.activePluginType = M64PLUGIN_NULL;
        return NO;
    }
    
    error = CoreAttachPlugin(type, pluginHandle);
    self.activePluginType = M64PLUGIN_NULL;
    
    if (error != M64ERR_SUCCESS)
    {
        NSLog(@"Error code %@ attaching plugin of type %@, name: %@", @(error), @(type), pluginName);
        return NO;
    }
    
    return YES;
}

- (void)registerCallbackForType:(m64p_core_param)callbackType callback:(void (^)(void))callback
{
    self.stateCallbacks[@(callbackType)] = callback;
}

#pragma mark - Getters/Setters -

- (NSTimeInterval)frameDuration
{
    return [self isNTSC] ? (1.0 / 60.0) : (1.0 / 50.0);
}

- (NSURL *)gameSaveDirectoryURL
{
    NSURL *gameSaveDirectoryURL = [Mupen64PlusEmulatorBridge.coreDirectoryURL URLByAppendingPathComponent:@"Saves" isDirectory:YES];
    
    NSError *error = nil;
    if (![[NSFileManager defaultManager] createDirectoryAtURL:gameSaveDirectoryURL withIntermediateDirectories:YES attributes:nil error:nil])
    {
        NSLog(@"Unable to create Game Save Directory. %@", error);
    }
    
    return gameSaveDirectoryURL;
}

- (NSURL *)configDirectoryURL
{
    NSURL *configDirectoryURL = [Mupen64PlusEmulatorBridge.coreDirectoryURL URLByAppendingPathComponent:@"Config" isDirectory:YES];
    
    NSError *error = nil;
    if (![[NSFileManager defaultManager] createDirectoryAtURL:configDirectoryURL withIntermediateDirectories:YES attributes:nil error:nil])
    {
        NSLog(@"Unable to create Config Directory. %@", error);
    }
    
    return configDirectoryURL;
}

@end

#pragma mark - Mupen64Plus Callbacks -

EXPORT m64p_error CALL osal_dynlib_open(m64p_dynlib_handle *pLibHandle, const char *pccLibraryPath)
{
    if (pLibHandle == NULL || pccLibraryPath == NULL)
    {
        return M64ERR_INPUT_ASSERT;
    }

    *pLibHandle = dlopen(pccLibraryPath, RTLD_NOW);

    if (*pLibHandle == NULL)
    {
        return M64ERR_INPUT_NOT_FOUND;
    }

    return M64ERR_SUCCESS;
}

EXPORT m64p_function CALL osal_dynlib_getproc(m64p_dynlib_handle LibHandle, const char *pccProcedureName)
{
    if (pccProcedureName == NULL)
    {
        return NULL;
    }

#if STATIC_LIBRARY
    const char *getVersion = "PluginGetVersion";
    const char *romOpen = "RomOpen";
    const char *romClosed = "RomClosed";
    const char *pluginStartup = "PluginStartup";
    const char *pluginShutdown = "PluginShutdown";

    if (strncmp(pccProcedureName, getVersion, strlen(getVersion)) == 0 ||
        strncmp(pccProcedureName, pluginStartup, strlen(pluginStartup)) == 0 ||
        strncmp(pccProcedureName, pluginShutdown, strlen(pluginShutdown)) == 0 ||
        strncmp(pccProcedureName, romOpen, strlen(romOpen)) == 0 ||
        strncmp(pccProcedureName, romClosed, strlen(romClosed)) == 0)
    {
        const char *prefix = "";
                
        switch (Mupen64PlusEmulatorBridge.sharedBridge.activePluginType)
        {
            case M64PLUGIN_GFX:
                prefix = "Video_";
                break;
                
            case M64PLUGIN_RSP:
                prefix = "RSP_";
                break;
                
            default:
                break;
        }
        
        char prefixedName[64];
        prefixedName[0] = '\0';
        
        strcat(prefixedName, prefix);
        strcat(prefixedName, pccProcedureName);
        
        m64p_function address = (m64p_function)dlsym(LibHandle, prefixedName);
        return address;
    }
#endif

    m64p_function address = (m64p_function)dlsym(LibHandle, pccProcedureName);
    return address;
}

EXPORT m64p_error CALL osal_dynlib_close(m64p_dynlib_handle LibHandle)
{
    int result = dlclose(LibHandle);
    if (result != 0)
    {
        return M64ERR_INTERNAL;
    }

    return M64ERR_SUCCESS;
}


EXPORT m64p_error CALL VidExt_Init(void)
{
    return M64ERR_SUCCESS;
}

EXPORT m64p_error CALL VidExt_Quit(void)
{
    return M64ERR_SUCCESS;
}

EXPORT m64p_error CALL VidExt_ListFullscreenModes(m64p_2d_size *SizeArray, int *NumSizes)
{
    *NumSizes = 0;
    return M64ERR_SUCCESS;
}

EXPORT m64p_error CALL VidExt_SetVideoMode(int Width, int Height, int BitsPerPixel, m64p_video_mode ScreenMode, m64p_video_flags Flags)
{
    Mupen64PlusEmulatorBridge.sharedBridge.preferredVideoDimensions = CGSizeMake(Width, Height);
    return M64ERR_SUCCESS;
}

EXPORT m64p_error CALL VidExt_SetCaption(const char *Title)
{
    NSLog(@"Mupen caption: %s", Title);
    return M64ERR_SUCCESS;
}

EXPORT m64p_error CALL VidExt_ToggleFullScreen(void)
{
    return M64ERR_UNSUPPORTED;
}

EXPORT m64p_function CALL VidExt_GL_GetProcAddress(const char* Proc)
{
    return (m64p_function)dlsym(RTLD_NEXT, Proc);
}

EXPORT m64p_error CALL VidExt_GL_SetAttribute(m64p_GLattr Attr, int Value)
{
    return M64ERR_UNSUPPORTED;
}

EXPORT m64p_error CALL VidExt_GL_GetAttribute(m64p_GLattr Attr, int *pValue)
{
    return M64ERR_UNSUPPORTED;
}

EXPORT m64p_error CALL VidExt_GL_SwapBuffers(void)
{
    [Mupen64PlusEmulatorBridge.sharedBridge.videoRenderer processFrame];
    
    return M64ERR_SUCCESS;
}

EXPORT m64p_error OverrideVideoFunctions(m64p_video_extension_functions *VideoFunctionStruct)
{
    return M64ERR_SUCCESS;
}

EXPORT m64p_error CALL VidExt_ResizeWindow(int width, int height)
{
    return M64ERR_SUCCESS;
}

EXPORT int VidExt_InFullscreenMode(void)
{
    return 1;
}

EXPORT int VidExt_VideoRunning(void)
{
    return Mupen64PlusEmulatorBridge.sharedBridge.isRunning;
}

EXPORT void new_vi(void)
{
    struct r4300_core* r4300 = &g_dev.r4300;
    
    if (g_gs_vi_counter < 60)
    {
        if (g_gs_vi_counter == 0)
        {
            cheat_apply_cheats(&g_cheat_ctx, r4300, ENTRY_BOOT);
        }
        
        g_gs_vi_counter = 60;
    }
    else
    {
        cheat_apply_cheats(&g_cheat_ctx, r4300, ENTRY_VI);
    }
    
    [Mupen64PlusEmulatorBridge.sharedBridge videoInterrupt];
}

EXPORT void ScreenshotRomOpen(void)
{
}

EXPORT void TakeScreenshot(int iFrameNumber)
{
}

EXPORT osd_message_t * osd_message_valid(osd_message_t *m)
{
    return NULL;
}

EXPORT int event_set_core_defaults(void)
{
    return 1;
}

EXPORT void event_initialize(void)
{
}

EXPORT void event_sdl_keydown(int keysym, int keymod)
{
}

EXPORT void event_sdl_keyup(int keysym, int keymod)
{
}

EXPORT int event_gameshark_active(void)
{
    return 1;
}

EXPORT void event_set_gameshark(int active)
{
}
