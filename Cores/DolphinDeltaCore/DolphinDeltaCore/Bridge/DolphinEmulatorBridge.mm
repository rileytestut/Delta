//
//  DolphinEmulatorBridge.mm
//  DolphinDeltaCore
//
//  Created by Riley Testut on 1/28/21.
//  Copyright © 2026 Riley Testut. All rights reserved.
//

#import "DolphinEmulatorBridge.h"
#import "DolphinTypes.h"

#import <DeltaCore/DeltaCore.h>
#import <DeltaCore/DeltaCore-Swift.h>

#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>

@interface DolphinEmulatorBridge ()
{
    double _inputs[4][20]; // 4 players, 20 GameCube inputs
}

@property (nonatomic, copy, nullable, readwrite) NSURL *gameURL;
@property (nonatomic, strong, nullable) UIView *renderView;
@property (nonatomic, strong, nullable) CAMetalLayer *metalLayer;

@property (nonatomic, assign, getter=isRunning) BOOL running;
@property (nonatomic, assign, getter=isPaused) BOOL paused;

@property (nonatomic, strong, readwrite) AVAudioFormat *preferredAudioFormat;
@property (nonatomic, readwrite) CGSize preferredVideoResolution;

@property (nonatomic, strong) dispatch_queue_t emulationQueue;
@property (nonatomic, strong) dispatch_semaphore_t frameSemaphore;

@end

@implementation DolphinEmulatorBridge
@synthesize audioRenderer = _audioRenderer;
@synthesize videoRenderer = _videoRenderer;
@synthesize saveUpdateHandler = _saveUpdateHandler;

+ (instancetype)sharedBridge
{
    static DolphinEmulatorBridge *sharedBridge = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedBridge = [[DolphinEmulatorBridge alloc] init];
    });
    return sharedBridge;
}

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _preferredAudioFormat = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatInt16
                                                                  sampleRate:48000
                                                                    channels:2
                                                                 interleaved:YES];
        // Standard GameCube internal resolution (640x480)
        _preferredVideoResolution = CGSizeMake(640, 480);
        _emulationQueue = dispatch_queue_create("com.rileytestut.DolphinDeltaCore.EmulationQueue", DISPATCH_QUEUE_SERIAL);
        _frameSemaphore = dispatch_semaphore_create(0);
        _isJITEnabled = YES;
    }
    return self;
}

#pragma mark - Rendering View Setup -

- (void)registerRenderView:(UIView *)renderView
{
    self.renderView = renderView;
    
    // Find or attach CAMetalLayer for Dolphin's Metal video backend
    if ([renderView.layer isKindOfClass:[CAMetalLayer class]])
    {
        self.metalLayer = (CAMetalLayer *)renderView.layer;
    }
    else
    {
        for (CALayer *sublayer in renderView.layer.sublayers)
        {
            if ([sublayer isKindOfClass:[CAMetalLayer class]])
            {
                self.metalLayer = (CAMetalLayer *)sublayer;
                break;
            }
        }
        
        if (self.metalLayer == nil)
        {
            CAMetalLayer *metalLayer = [CAMetalLayer layer];
            metalLayer.frame = renderView.bounds;
            metalLayer.contentsScale = [UIScreen mainScreen].scale;
            metalLayer.pixelFormat = MTLPixelFormatBGRA8Unorm;
            [renderView.layer addSublayer:metalLayer];
            self.metalLayer = metalLayer;
        }
    }
}

#pragma mark - DLTAEmulatorBridging -

- (NSTimeInterval)frameDuration
{
    return 1.0 / 60.0;
}

- (void)startWithGameURL:(NSURL *)gameURL
{
    self.gameURL = gameURL;
    self.running = YES;
    self.paused = NO;
    
    dispatch_async(self.emulationQueue, ^{
        NSLog(@"[DolphinDeltaCore] Starting emulation with game: %@", gameURL.path);
        // Configure Dolphin user directories, memory card paths, JIT vs Interpreter, and Metal surface.
    });
}

- (void)stop
{
    if (!self.isRunning) return;
    
    NSLog(@"[DolphinDeltaCore] Stopping emulation");
    self.running = NO;
    self.paused = NO;
    self.gameURL = nil;
}

- (void)pause
{
    if (!self.isRunning || self.isPaused) return;
    
    NSLog(@"[DolphinDeltaCore] Pausing emulation");
    self.paused = YES;
}

- (void)resume
{
    if (!self.isRunning || !self.isPaused) return;
    
    NSLog(@"[DolphinDeltaCore] Resuming emulation");
    self.paused = NO;
}

- (void)runFrameAndProcessVideo:(BOOL)processVideo
{
    if (!self.isRunning || self.isPaused) return;
    
    // Signal frame execution
}

#pragma mark - Inputs -

- (void)activateInput:(NSInteger)input value:(double)value playerIndex:(NSInteger)playerIndex
{
    if (playerIndex < 0 || playerIndex >= 4) return;
    if (input < 0 || input >= 20) return;
    
    _inputs[playerIndex][input] = value;
}

- (void)deactivateInput:(NSInteger)input playerIndex:(NSInteger)playerIndex
{
    if (playerIndex < 0 || playerIndex >= 4) return;
    if (input < 0 || input >= 20) return;
    
    _inputs[playerIndex][input] = 0.0;
}

- (void)resetInputs
{
    memset(_inputs, 0, sizeof(_inputs));
}

#pragma mark - Save States -

- (void)saveSaveStateToURL:(NSURL *)url
{
    NSLog(@"[DolphinDeltaCore] Saving save state to: %@", url.path);
}

- (void)loadSaveStateFromURL:(NSURL *)url
{
    NSLog(@"[DolphinDeltaCore] Loading save state from: %@", url.path);
}

#pragma mark - Game Saves -

- (void)saveGameSaveToURL:(NSURL *)url
{
    NSLog(@"[DolphinDeltaCore] Flushing memory card to: %@", url.path);
    if (self.saveUpdateHandler)
    {
        self.saveUpdateHandler();
    }
}

- (void)loadGameSaveFromURL:(NSURL *)url
{
    NSLog(@"[DolphinDeltaCore] Loading memory card from: %@", url.path);
}

#pragma mark - Cheats -

- (BOOL)addCheatCode:(NSString *)cheatCode type:(NSString *)type
{
    NSLog(@"[DolphinDeltaCore] Adding cheat: %@ (%@)", cheatCode, type);
    return YES;
}

- (void)resetCheats
{
    NSLog(@"[DolphinDeltaCore] Resetting cheats");
}

- (void)updateCheats
{
    NSLog(@"[DolphinDeltaCore] Updating cheats");
}

- (nullable NSData *)readMemoryAtAddress:(NSInteger)address size:(NSInteger)size
{
    return nil;
}

@end
