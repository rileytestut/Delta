//
//  Mupen64PlusDeltaCore.h
//  Mupen64PlusDeltaCore
//
//  Created by Riley Testut on 3/27/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

#import <UIKit/UIKit.h>

//! Project version number for N64DeltaCore.
FOUNDATION_EXPORT double Mupen64PlusDeltaCoreVersionNumber;

//! Project version string for N64DeltaCore.
FOUNDATION_EXPORT const unsigned char Mupen64PlusDeltaCoreVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <N64DeltaCore/PublicHeader.h>

#if !STATIC_LIBRARY
#import <Mupen64PlusDeltaCore/Mupen64PlusEmulatorBridge.h>
#endif
