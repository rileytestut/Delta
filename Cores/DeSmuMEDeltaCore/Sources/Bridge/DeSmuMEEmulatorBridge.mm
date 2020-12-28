//
//  DeSmuMEEmulatorBridge.m
//  DeSmuMEDeltaCore
//
//  Created by Riley Testut on 8/2/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

#import "DeSmuMEEmulatorBridge.h"

#import <UIKit/UIKit.h>
#import <DeltaCore/DeltaCore-Swift.h>

#if STATIC_LIBRARY
#import "DeSmuMEDeltaCore-Swift.h"
#else
#import <DeSmuMEDeltaCore/DeSmuMEDeltaCore-Swift.h>
#endif

// DeSmuME
#include "types.h"
#include "render3D.h"
#include "rasterize.h"
#include "SPU.h"
#include "debug.h"
#include "NDSSystem.h"
#include "path.h"
#include "slot1.h"
#include "saves.h"
#include "cheatSystem.h"
#include "slot1.h"
#include "version.h"
#include "metaspu.h"
#include "GPU.h"

#undef BOOL

#define SNDCORE_DELTA 1

void DLTAUpdateAudio(s16 *buffer, u32 num_samples);
u32 DLTAGetAudioSpace();

SoundInterface_struct DeltaAudio = {
    SNDCORE_DELTA,
    "CoreAudio Sound Interface",
    SNDDummy.Init,
    SNDDummy.DeInit,
    DLTAUpdateAudio,
    DLTAGetAudioSpace,
    SNDDummy.MuteAudio,
    SNDDummy.UnMuteAudio,
    SNDDummy.SetVolume,
};

volatile bool execute = true;

GPU3DInterface *core3DList[] = {
    &gpu3DNull,
    &gpu3DRasterize,
    NULL
};

SoundInterface_struct *SNDCoreList[] = {
    &SNDDummy,
    &DeltaAudio,
    NULL
};

@interface DeSmuMEEmulatorBridge () <DLTAEmulatorBridging>
{
    BOOL _isPrepared;
}

@property (nonatomic, copy, nullable, readwrite) NSURL *gameURL;

@property (nonatomic) uint32_t activatedInputs;
@property (nonatomic) CGPoint touchScreenPoint;

@end

@implementation DeSmuMEEmulatorBridge
@synthesize audioRenderer = _audioRenderer;
@synthesize videoRenderer = _videoRenderer;
@synthesize saveUpdateHandler = _saveUpdateHandler;

+ (instancetype)sharedBridge
{
    static DeSmuMEEmulatorBridge *_emulatorBridge = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _emulatorBridge = [[self alloc] init];
    });
    
    return _emulatorBridge;
}

#pragma mark - Emulation State -

- (void)startWithGameURL:(NSURL *)gameURL
{
    self.gameURL = gameURL;
    
    path.ReadPathSettings();
    
    // General
    CommonSettings.num_cores = (int)sysconf( _SC_NPROCESSORS_ONLN );
    CommonSettings.advanced_timing = false;
    CommonSettings.cheatsDisable = true;
    CommonSettings.autodetectBackupMethod = 1;
    CommonSettings.use_jit = false;
    CommonSettings.micMode = TCommonSettings::Physical;
    CommonSettings.showGpu.main = 1;
    CommonSettings.showGpu.sub = 1;
    
    // HUD
    CommonSettings.hud.FpsDisplay = false;
    CommonSettings.hud.FrameCounterDisplay = false;
    CommonSettings.hud.ShowInputDisplay = false;
    CommonSettings.hud.ShowGraphicalInputDisplay = false;
    CommonSettings.hud.ShowLagFrameCounter = false;
    CommonSettings.hud.ShowMicrophone = false;
    CommonSettings.hud.ShowRTC = false;
    
    // Graphics
    CommonSettings.GFX3D_HighResolutionInterpolateColor = 0;
    CommonSettings.GFX3D_EdgeMark = 0;
    CommonSettings.GFX3D_Fog = 1;
    CommonSettings.GFX3D_Texture = 1;
    CommonSettings.GFX3D_LineHack = 0;
    
    // Sound
    CommonSettings.spuInterpolationMode = SPUInterpolation_Cosine;
    CommonSettings.spu_advanced = false;
    
    // Firmware
    CommonSettings.fwConfig.language = NDS_FW_LANG_ENG;
    CommonSettings.fwConfig.favoriteColor = 15;
    CommonSettings.fwConfig.birthdayMonth = 10;
    CommonSettings.fwConfig.birthdayDay = 7;
    CommonSettings.fwConfig.consoleType = NDS_CONSOLE_TYPE_LITE;
    
    static const char *nickname = "Delta";
    CommonSettings.fwConfig.nicknameLength = strlen(nickname);
    for(int i = 0 ; i < CommonSettings.fwConfig.nicknameLength ; ++i)
    {
        CommonSettings.fwConfig.nickname[i] = nickname[i];
    }
    
    static const char *message = "Delta is the best!";
    CommonSettings.fwConfig.messageLength = strlen(message);
    for(int i = 0 ; i < CommonSettings.fwConfig.messageLength ; ++i)
    {
        CommonSettings.fwConfig.message[i] = message[i];
    }
    
    if (!_isPrepared)
    {
        Desmume_InitOnce();
        
        NDS_Init();
        cur3DCore = 1;
        
        GPU->Change3DRendererByID(1);
        GPU->SetColorFormat(NDSColorFormat_BGR888_Rev);
        
        SPU_ChangeSoundCore(SNDCORE_DELTA, DESMUME_SAMPLE_RATE * 8/60);
        
        _isPrepared = true;
    }
    
    NSURL *gameDirectory = [NSURL URLWithString:@"/dev/null"];
    path.setpath(PathInfo::BATTERY, gameDirectory.fileSystemRepresentation);
    
    if (!NDS_LoadROM(gameURL.relativePath.UTF8String))
    {
        NSLog(@"Error loading ROM: %@", gameURL);
    }
}

- (void)stop
{
    NDS_FreeROM();
}

- (void)pause
{
}

- (void)resume
{
}

#pragma mark - Game Loop -

- (void)runFrameAndProcessVideo:(BOOL)processVideo
{
    // Inputs
    NDS_setPad(self.activatedInputs & DeSmuMEGameInputRight,
               self.activatedInputs & DeSmuMEGameInputLeft,
               self.activatedInputs & DeSmuMEGameInputDown,
               self.activatedInputs & DeSmuMEGameInputUp,
               self.activatedInputs & DeSmuMEGameInputSelect,
               self.activatedInputs & DeSmuMEGameInputStart,
               self.activatedInputs & DeSmuMEGameInputB,
               self.activatedInputs & DeSmuMEGameInputA,
               self.activatedInputs & DeSmuMEGameInputY,
               self.activatedInputs & DeSmuMEGameInputX,
               self.activatedInputs & DeSmuMEGameInputL,
               self.activatedInputs & DeSmuMEGameInputR,
               false,
               false);
    
    if (self.activatedInputs & DeSmuMEGameInputTouchScreenX || self.activatedInputs & DeSmuMEGameInputTouchScreenY)
    {
        NDS_setTouchPos(self.touchScreenPoint.x, self.touchScreenPoint.y);
    }
    else
    {
        NDS_releaseTouch();
    }
    
    NDS_beginProcessingInput();
    NDS_endProcessingInput();
    
    if (!processVideo)
    {
        NDS_SkipNextFrame();
    }
    
    NDS_exec<false>();
    
    if (processVideo)
    {
        memcpy(self.videoRenderer.videoBuffer, GPU->GetDisplayInfo().masterNativeBuffer, 256 * 384 * 4);
        [self.videoRenderer processFrame];
    }
    
    SPU_Emulate_user();
}

#pragma mark - Inputs -

- (void)activateInput:(NSInteger)input value:(double)value
{
    self.activatedInputs |= (uint32_t)input;
    
    CGPoint touchPoint = self.touchScreenPoint;
    
    switch ((DeSmuMEGameInput)input)
    {
    case DeSmuMEGameInputTouchScreenX:
        touchPoint.x = value * 256;
        break;
        
    case DeSmuMEGameInputTouchScreenY:
        touchPoint.y = value * 192;
        break;
            
    default: break;
    }

    self.touchScreenPoint = touchPoint;
}

- (void)deactivateInput:(NSInteger)input
{    
    self.activatedInputs &= ~((uint32_t)input);
    
    CGPoint touchPoint = self.touchScreenPoint;
    
    switch ((DeSmuMEGameInput)input)
    {
        case DeSmuMEGameInputTouchScreenX:
            touchPoint.x = 0;
            break;
            
        case DeSmuMEGameInputTouchScreenY:
            touchPoint.y = 0;
            break;
            
        default: break;
    }
    
    self.touchScreenPoint = touchPoint;
}

- (void)resetInputs
{
    self.activatedInputs = 0;
    self.touchScreenPoint = CGPointZero;
}

#pragma mark - Game Saves -

- (void)saveGameSaveToURL:(NSURL *)URL
{
    MMU_new.backupDevice.export_raw(URL.fileSystemRepresentation);
}

- (void)loadGameSaveFromURL:(NSURL *)URL
{
    if ([[NSFileManager defaultManager] fileExistsAtPath:URL.path])
    {
        MMU_new.backupDevice.import_raw(URL.fileSystemRepresentation);
    }
}

#pragma mark - Save States -

- (void)saveSaveStateToURL:(NSURL *)URL
{
    savestate_save(URL.fileSystemRepresentation);
}

- (void)loadSaveStateFromURL:(NSURL *)URL
{
    savestate_load(URL.fileSystemRepresentation);
}

#pragma mark - Cheats -

- (BOOL)addCheatCode:(NSString *)cheatCode type:(NSString *)type
{
    return NO;
}

- (void)resetCheats
{
}

- (void)updateCheats
{
}

#pragma mark - Audio -

void DLTAUpdateAudio(s16 *buffer, u32 num_samples)
{
    [DeSmuMEEmulatorBridge.sharedBridge.audioRenderer.audioBuffer writeBuffer:(uint8_t *)buffer size:num_samples * 4];
}

u32 DLTAGetAudioSpace()
{
    NSInteger availableBytes = DeSmuMEEmulatorBridge.sharedBridge.audioRenderer.audioBuffer.availableBytesForWriting;
    
    u32 availableFrames = (u32)availableBytes / 4;
    return availableFrames;
}

#pragma mark - Getters/Setters -

- (NSTimeInterval)frameDuration
{
    return (1.0 / 60.0);
}

@end
