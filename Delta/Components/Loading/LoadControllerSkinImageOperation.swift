//
//  LoadControllerSkinImageOperation.swift
//  Delta
//
//  Created by Riley Testut on 10/28/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import UIKit

import DeltaCore

class ControllerSkinImageCacheKey: NSObject
{
    let controllerSkin: ControllerSkin
    let traits: DeltaCore.ControllerSkin.Traits
    let size: DeltaCore.ControllerSkin.Size
    
    override var hash: Int {
        return self.controllerSkin.hashValue ^ self.traits.hashValue ^ self.size.hashValue
    }
    
    init(controllerSkin: ControllerSkin, traits: DeltaCore.ControllerSkin.Traits, size: DeltaCore.ControllerSkin.Size)
    {
        self.controllerSkin = controllerSkin
        self.traits = traits
        self.size = size
        
        super.init()
    }
    
    override func isEqual(_ object: Any?) -> Bool
    {
        guard let object = object as? ControllerSkinImageCacheKey else { return false }
        return self.controllerSkin == object.controllerSkin && self.traits == object.traits && self.size == object.size
    }
}

class LoadControllerSkinImageOperation: LoadImageOperation<ControllerSkinImageCacheKey>
{
    let controllerSkin: ControllerSkin
    let traits: DeltaCore.ControllerSkin.Traits
    let size: DeltaCore.ControllerSkin.Size
    
    init(controllerSkin: ControllerSkin, traits: DeltaCore.ControllerSkin.Traits, size: DeltaCore.ControllerSkin.Size)
    {
        self.controllerSkin = controllerSkin
        self.traits = traits
        self.size = size
        
        let cacheKey = ControllerSkinImageCacheKey(controllerSkin: controllerSkin, traits: traits, size: size)
        super.init(cacheKey: cacheKey)
    }
    
    override func loadImage() -> UIImage?
    {
        let image = self.controllerSkin.image(for: self.traits, preferredSize: self.size)
        return image
    }
}
