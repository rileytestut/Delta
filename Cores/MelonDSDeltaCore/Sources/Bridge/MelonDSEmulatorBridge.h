//
//  MelonDSEmulatorBridge.h
//  MelonDSDeltaCore
//
//  Created by Riley Testut on 10/31/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol DLTAEmulatorBridging;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, MelonDSSystemType)
{
    MelonDSSystemTypeDS NS_SWIFT_NAME(ds) = 0,
    MelonDSSystemTypeDSi NS_SWIFT_NAME(dsi) = 1
};

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Weverything" // Silence "Cannot find protocol definition" warning due to forward declaration.
@interface MelonDSEmulatorBridge : NSObject <DLTAEmulatorBridging>
#pragma clang diagnostic pop

@property (class, nonatomic, readonly) MelonDSEmulatorBridge *sharedBridge;

@property (nonatomic) MelonDSSystemType systemType;
@property (nonatomic, getter=isJITEnabled) BOOL jitEnabled;

@property (nonatomic, readonly) NSURL *bios7URL;
@property (nonatomic, readonly) NSURL *bios9URL;
@property (nonatomic, readonly) NSURL *firmwareURL;

@property (nonatomic, readonly) NSURL *dsiBIOS7URL;
@property (nonatomic, readonly) NSURL *dsiBIOS9URL;
@property (nonatomic, readonly) NSURL *dsiFirmwareURL;
@property (nonatomic, readonly) NSURL *dsiNANDURL;

@end

NS_ASSUME_NONNULL_END
