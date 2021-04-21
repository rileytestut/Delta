#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "GBADeltaCore/Types/GBATypes.h"
#import "GBADeltaCore/Bridge/GBAEmulatorBridge.h"
#import "GBADeltaCore/GBADeltaCore.h"

FOUNDATION_EXPORT double GBADeltaCoreVersionNumber;
FOUNDATION_EXPORT const unsigned char GBADeltaCoreVersionString[];

