//
//  AppIcon.swift
//  Delta
//
//  Created by Kyle Grieder on 10/4/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import UIKit

class AppIcon: NSObject {
    
    public var assetName: String
    public var image: UIImage
    public var name: String
    
    public enum AssetName: String {
        case DeltaDefault
        case DeltaOrange
        case DeltaBlue
        case DeltaRed
        case DeltaGreen
        case Delta4iOS
        case Orange4iOS
        case Blue4iOS
        case Red4iOS
        case Green4iOS
        case Delta64
        case Delta64Dark
        case Nintendo
        case Nes
        case Snes
        case N64
    }
    
    init(name: String, assetName: AssetName) {
        self.assetName = assetName.rawValue
        self.image = UIImage(named: assetName.rawValue)!
        self.name = name
    }
}
