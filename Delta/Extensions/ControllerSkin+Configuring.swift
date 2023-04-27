//
//  ControllerSkin+Configuring.swift
//  Delta
//
//  Created by Riley Testut on 11/2/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import UIKit

import DeltaCore

extension ControllerSkin
{
    convenience init?(system: System, context: NSManagedObjectContext)
    {
        guard let deltaControllerSkin = DeltaCore.ControllerSkin.standardControllerSkin(for: system.gameType) else { return nil }
        
        self.init(context: context)
        
        self.isStandard = true
        self.filename = deltaControllerSkin.fileURL.lastPathComponent
        
        self.configure(with: deltaControllerSkin)
    }
    
    func configure(with skin: DeltaCore.ControllerSkin)
    {
        // Manually copy values to be stored in database.
        // Remaining ControllerSkinProtocol requirements will be provided by the ControllerSkin's private DeltaCore.ControllerSkin instance.
        self.name = skin.name
        self.identifier = skin.identifier
        self.gameType = skin.gameType
        
        var configurations = ControllerSkinConfigurations()
        
        let allTraitCombinations = DeltaCore.ControllerSkin.Device.allCases.flatMap { device in
            DeltaCore.ControllerSkin.DisplayType.allCases.flatMap { displayType in
                DeltaCore.ControllerSkin.Orientation.allCases.map { orientation in
                    DeltaCore.ControllerSkin.Traits(device: device, displayType: displayType, orientation: orientation)
                }
            }
        }
        
        for traits in allTraitCombinations
        {
            guard let configuration = ControllerSkinConfigurations(traits: traits), skin.supports(traits) else { continue }
            configurations.formUnion(configuration)
        }
        
        self.supportedConfigurations = configurations
    }
}
