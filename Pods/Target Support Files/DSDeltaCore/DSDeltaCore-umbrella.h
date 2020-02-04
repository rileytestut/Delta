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

#import "DSDeltaCore/Types/DSTypes.h"
#import "DSDeltaCore/Bridge/DSEmulatorBridge.h"

FOUNDATION_EXPORT double DSDeltaCoreVersionNumber;
FOUNDATION_EXPORT const unsigned char DSDeltaCoreVersionString[];

