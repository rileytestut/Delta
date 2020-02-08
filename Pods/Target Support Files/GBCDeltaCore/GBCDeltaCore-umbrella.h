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

#import "GBCDeltaCore/Types/GBCTypes.h"
#import "GBCDeltaCore/Bridge/GBCEmulatorBridge.h"

FOUNDATION_EXPORT double GBCDeltaCoreVersionNumber;
FOUNDATION_EXPORT const unsigned char GBCDeltaCoreVersionString[];

