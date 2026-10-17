//
//  DolphinEmulatorBridge.h
//  DolphinDeltaCore
//
//  Created by Riley Testut on 1/28/21.
//  Copyright © 2026 Riley Testut. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

@protocol DLTAEmulatorBridging;

NS_ASSUME_NONNULL_BEGIN

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Weverything"
__attribute__((visibility("default")))
@interface DolphinEmulatorBridge : NSObject <DLTAEmulatorBridging>
#pragma clang diagnostic pop

@property (class, nonatomic, readonly) DolphinEmulatorBridge *sharedBridge;

@property (nonatomic, readonly) AVAudioFormat *preferredAudioFormat;
@property (nonatomic, readonly) CGSize preferredVideoResolution;

@property (nonatomic, assign) BOOL isJITEnabled;

- (void)registerRenderView:(UIView *)renderView;

@end

NS_ASSUME_NONNULL_END
