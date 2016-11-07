//
//  ControllerSkinConfigurations.h
//  Delta
//
//  Created by Riley Testut on 11/1/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

#ifndef ControllerSkinConfigurations_h
#define ControllerSkinConfigurations_h

typedef NS_OPTIONS(int16_t, ControllerSkinConfigurations)
{
    ControllerSkinConfigurationFullScreenPortrait   = 1 << 0,
    ControllerSkinConfigurationFullScreenLandscape  = 1 << 1,
    
    ControllerSkinConfigurationSplitViewPortrait    = 1 << 2,
    ControllerSkinConfigurationSplitViewLandscape   = 1 << 3,
};

#endif /* ControllerSkinConfigurations_h */
