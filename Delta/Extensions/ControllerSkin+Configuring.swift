//
//  ControllerSkin+Configuring.swift
//  Delta
//
//  Created by Riley Testut on 11/2/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import DeltaCore

extension ControllerSkin
{
    func configure(with skin: DeltaCore.ControllerSkin)
    {
        // Manually copy values to be stored in database.
        // Remaining ControllerSkinProtocol requirements will be provided by the ControllerSkin's private DeltaCore.ControllerSkin instance.
        self.name = skin.name
        self.identifier = skin.identifier
        self.gameType = skin.gameType
        
        var configurations = ControllerSkinConfigurations()
        
        if UIDevice.current.userInterfaceIdiom == .pad
        {
            var portraitTraits = DeltaCore.ControllerSkin.Traits(deviceType: .ipad, displayMode: .fullScreen, orientation: .portrait)
            
            var landscapeTraits = portraitTraits
            landscapeTraits.orientation = .landscape
            
            
            if skin.supports(portraitTraits)
            {
                configurations.formUnion(.fullScreenPortrait)
            }
            
            if skin.supports(landscapeTraits)
            {
                configurations.formUnion(.fullScreenLandscape)
            }
            
            
            portraitTraits.displayMode = .splitView
            landscapeTraits.displayMode = .splitView
            
            
            if skin.supports(portraitTraits)
            {
                configurations.formUnion(.splitViewPortrait)
            }
            
            if skin.supports(landscapeTraits)
            {
                configurations.formUnion(.splitViewLandscape)
            }
        }
        else
        {
            let portraitTraits = DeltaCore.ControllerSkin.Traits(deviceType: .iphone, displayMode: .fullScreen, orientation: .portrait)
            
            var landscapeTraits = portraitTraits
            landscapeTraits.orientation = .landscape
            
            if skin.supports(portraitTraits)
            {
                configurations.formUnion(.fullScreenPortrait)
            }
            
            if skin.supports(landscapeTraits)
            {
                configurations.formUnion(.fullScreenLandscape)
            }
        }
        
        self.supportedConfigurations = configurations
    }
}
