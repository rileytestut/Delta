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
    
    ControllerSkinConfigurationiPhoneEdgeToEdgePortrait NS_SWIFT_NAME(iphoneEdgeToEdgePortrait)    = 1 << 4,
    ControllerSkinConfigurationiPhoneEdgeToEdgeLandscape NS_SWIFT_NAME(iphoneEdgeToEdgeLandscape)  = 1 << 5,
    
    ControllerSkinConfigurationiPhoneSplitViewPortrait NS_SWIFT_NAME(iphoneSplitViewPortrait)      = 1 << 12,
    ControllerSkinConfigurationiPhoneSplitViewLandscape NS_SWIFT_NAME(iphoneSplitViewLandscape)    = 1 << 13,
    
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
    
    
    /* Duo */
    // Due to limited Int16 size, on iPhone Duo we re-use "standard" to mean outer display, and "edge-to-edge" to mean inner display
    
    ControllerSkinConfigurationiPhoneInsidePortrait NS_SWIFT_NAME(iphoneInsidePortrait)      = ControllerSkinConfigurationiPhoneEdgeToEdgePortrait,
    ControllerSkinConfigurationiPhoneInsideLandscape NS_SWIFT_NAME(iphoneInsideLandscape)    = ControllerSkinConfigurationiPhoneEdgeToEdgeLandscape,
    
    ControllerSkinConfigurationiPhoneOutsidePortrait NS_SWIFT_NAME(iphoneOutsidePortrait)    = ControllerSkinConfigurationiPhoneStandardPortrait,
    ControllerSkinConfigurationiPhoneOutsideLandscape NS_SWIFT_NAME(iphoneOutsideLandscape)  = ControllerSkinConfigurationiPhoneStandardLandscape,
};

#endif /* ControllerSkinConfigurations_h */
