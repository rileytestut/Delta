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

#import "N64DeltaCore/Types/N64Types.h"
#import "N64DeltaCore/Bridge/N64EmulatorBridge.h"
#import "N64DeltaCore/N64DeltaCore.h"

FOUNDATION_EXPORT double N64DeltaCoreVersionNumber;
FOUNDATION_EXPORT const unsigned char N64DeltaCoreVersionString[];

