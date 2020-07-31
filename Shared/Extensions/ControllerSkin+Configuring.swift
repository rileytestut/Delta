//
//  ControllerSkin+Configuring.swift
//  Delta
//
//  Created by Riley Testut on 11/2/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import CoreData

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
        
        let device: DeltaCore.ControllerSkin.Device = (UIDevice.current.userInterfaceIdiom == .pad) ? .ipad : .iphone
        
        let traitCollections: [(displayType: DeltaCore.ControllerSkin.DisplayType, orientation: DeltaCore.ControllerSkin.Orientation)] =
            [(.standard, .portrait), (.standard, .landscape), (.edgeToEdge, .portrait), (.edgeToEdge, .landscape), (.splitView, .portrait), (.splitView, .landscape)]
        
        for collection in traitCollections
        {
            let traits = DeltaCore.ControllerSkin.Traits(device: device, displayType: collection.displayType, orientation: collection.orientation)
            if skin.supports(traits)
            {
                let configuration = ControllerSkinConfigurations(traits: traits)
                configurations.formUnion(configuration)
            }
        }
        
        self.supportedConfigurations = configurations
    }
}
