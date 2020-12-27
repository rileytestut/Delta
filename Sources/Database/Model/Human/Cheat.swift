//
//  Cheat.swift
//  Delta
//
//  Created by Riley Testut on 5/19/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import Foundation

import DeltaCore
import Harmony

@objc(Cheat)
public class Cheat: _Cheat, CheatProtocol
{    
    @NSManaged private var primitiveIdentifier: String
    @NSManaged private var primitiveCreationDate: Date
    @NSManaged private var primitiveModifiedDate: Date
    
    public override func awakeFromInsert()
    {
        super.awakeFromInsert()
        
        let identifier = UUID().uuidString
        let date = Date()
        
        self.primitiveIdentifier = identifier
        self.primitiveCreationDate = date
        self.primitiveModifiedDate = date
    }
}

extension Cheat: Syncable
{
    public static var syncablePrimaryKey: AnyKeyPath {
        return \Cheat.identifier
    }
    
    public var syncableKeys: Set<AnyKeyPath> {
        return [\Cheat.code, \Cheat.creationDate, \Cheat.modifiedDate, \Cheat.name, \Cheat.type]
    }
    
    public var syncableRelationships: Set<AnyKeyPath> {
        return [\Cheat.game as AnyKeyPath]
    }
    
    public var syncableMetadata: [HarmonyMetadataKey : String] {
        guard let game = self.game else { return [:] }
        return [.gameID: game.identifier, .gameName: game.name]
    }
    
    public var syncableLocalizedName: String? {
        return self.name
    }
}
