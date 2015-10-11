//
//  Game.swift
//  Delta
//
//  Created by Riley Testut on 10/3/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

import DeltaCore
import SNESDeltaCore

@objc(Game)
class Game: NSManagedObject, GameType
{
}

extension Game
{
    class func typeIdentifierForURL(URL: NSURL) -> String?
    {
        guard let pathExtension = URL.pathExtension else { return nil }
        
        switch pathExtension
        {
            case "smc": fallthrough
            case "sfc": fallthrough
            case "fig": return kUTTypeSNESGame as String
            
            default: return nil
        }
    }
    
    class func supportedTypeIdentifiers() -> Set<String>
    {
        return [kUTTypeSNESGame as String]
    }
}
