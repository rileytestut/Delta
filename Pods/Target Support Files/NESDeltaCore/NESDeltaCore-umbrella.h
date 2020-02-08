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

#import "NestopiaJS/NESEmulatorBridge.hpp"

FOUNDATION_EXPORT double NESDeltaCoreVersionNumber;
FOUNDATION_EXPORT const unsigned char NESDeltaCoreVersionString[];

