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
    ControllerSkinConfigurationStandardPortrait   = 1 << 0,
    ControllerSkinConfigurationStandardLandscape  = 1 << 1,
    
    ControllerSkinConfigurationSplitViewPortrait    = 1 << 2,
    ControllerSkinConfigurationSplitViewLandscape   = 1 << 3,
    
    ControllerSkinConfigurationEdgeToEdgePortrait    = 1 << 4,
    ControllerSkinConfigurationEdgeToEdgeLandscape   = 1 << 5,
};

#endif /* ControllerSkinConfigurations_h */
