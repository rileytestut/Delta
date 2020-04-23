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

#import "MelonDSDeltaCore/Types/MelonDSTypes.h"
#import "MelonDSDeltaCore/Bridge/MelonDSEmulatorBridge.h"
#import "MelonDSDeltaCore/MelonDSDeltaCore.h"

FOUNDATION_EXPORT double MelonDSDeltaCoreVersionNumber;
FOUNDATION_EXPORT const unsigned char MelonDSDeltaCoreVersionString[];

