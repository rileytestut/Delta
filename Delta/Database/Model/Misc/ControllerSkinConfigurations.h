//
//  ControllerSkinConfigurations.h
//  Delta
//
//  Created by Riley Testut on 11/1/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

#ifndef ControllerSkinConfigurations_h
#define ControllerSkinConfigurations_h

// Every possible (supported) combination of traits.
typedef NS_OPTIONS(int16_t, ControllerSkinConfigurations)
{
    /* iPhone */
    ControllerSkinConfigurationiPhoneStandardPortrait NS_SWIFT_NAME(iphoneStandardPortrait)        = 1 << 0,
    ControllerSkinConfigurationiPhoneStandardLandscape NS_SWIFT_NAME(iphoneStandardLandscape)      = 1 << 1,
    
    // iPhone doesn't support Split View
    // ControllerSkinConfigurationiPhoneSplitViewPortrait                                          = 1 << 2,
    // ControllerSkinConfigurationiPhoneSplitViewLandscape                                         = 1 << 3,
    
    ControllerSkinConfigurationiPhoneEdgeToEdgePortrait NS_SWIFT_NAME(iphoneEdgeToEdgePortrait)    = 1 << 4,
    ControllerSkinConfigurationiPhoneEdgeToEdgeLandscape NS_SWIFT_NAME(iphoneEdgeToEdgeLandscape)  = 1 << 5,
    
    
    /* iPad */
    ControllerSkinConfigurationiPadStandardPortrait NS_SWIFT_NAME(ipadStandardPortrait)            = 1 << 6,
    ControllerSkinConfigurationiPadStandardLandscape NS_SWIFT_NAME(ipadStandardLandscape)          = 1 << 7,

    ControllerSkinConfigurationiPadSplitViewPortrait NS_SWIFT_NAME(ipadSplitViewPortrait)          = 1 << 2, // Backwards compatible with legacy ControllerSkinConfigurationSplitViewPortrait
    ControllerSkinConfigurationiPadSplitViewLandscape NS_SWIFT_NAME(ipadSplitViewLandscape)        = 1 << 3, // Backwards compatible with legacy ControllerSkinConfigurationSplitViewLandscape
    
    ControllerSkinConfigurationiPadEdgeToEdgePortrait NS_SWIFT_NAME(ipadEdgeToEdgePortrait)        = 1 << 8,
    ControllerSkinConfigurationiPadEdgeToEdgeLandscape NS_SWIFT_NAME(ipadEdgeToEdgeLandscape)      = 1 << 9,
    
    
    /* TV */
    ControllerSkinConfigurationTVStandardPortrait                                                  = 1 << 10,
    ControllerSkinConfigurationTVStandardLandscape                                                 = 1 << 11,
};

#endif /* ControllerSkinConfigurations_h */
