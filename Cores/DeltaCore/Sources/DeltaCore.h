//
//  DeltaCore.h
//  DeltaCore
//
//  Created by Riley Testut on 3/8/15.
//  Copyright (c) 2015 Riley Testut. All rights reserved.
//

#import <UIKit/UIKit.h>

//! Project version number for DeltaCore.
FOUNDATION_EXPORT double DeltaCoreVersionNumber;

//! Project version string for DeltaCore.
FOUNDATION_EXPORT const unsigned char DeltaCoreVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <DeltaCore/PublicHeader.h>
#import <DeltaCore/DeltaTypes.h>
#import <DeltaCore/DLTAMuteSwitchMonitor.h>

// HACK: Needed because the generated DeltaCore-Swift header file uses @import syntax, which isn't supported in Objective-C++ code.
#import <GLKit/GLKit.h>
#import <AVFoundation/AVFoundation.h>
