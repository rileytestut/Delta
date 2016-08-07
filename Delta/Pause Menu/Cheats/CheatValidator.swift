//
//  CheatValidator.swift
//  Delta
//
//  Created by Riley Testut on 7/27/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import Foundation

import DeltaCore

extension CheatValidator
{
    enum Error: Swift.Error
    {
        case invalidCode
        case invalidName
        case duplicateName
        case duplicateCode
    }
}

struct CheatValidator
{
    let format: CheatFormat
    let managedObjectContext: NSManagedObjectContext
    
    func validate(_ cheat: Cheat) throws
    {
        guard let name = cheat.name else { throw Error.invalidName }
        
        let code = cheat.code
        
        // Find all cheats that are for the same game, don't have the same identifier as the current cheat, but have either the same name or code
        let predicate = Predicate(format: "%K == %@ AND %K != %@ AND (%K == %@ OR %K == %@)", Cheat.Attributes.game.rawValue, cheat.game, Cheat.Attributes.identifier.rawValue, cheat.identifier, Cheat.Attributes.code.rawValue, code, Cheat.Attributes.name.rawValue, name)
        
        let cheats = Cheat.instancesWithPredicate(predicate, inManagedObjectContext: self.managedObjectContext, type: Cheat.self)
        for cheat in cheats
        {
            if cheat.name == name
            {
                throw Error.duplicateName
            }
            else if cheat.code == code
            {
                throw Error.duplicateCode
            }
        }
        
        // Remove newline characters (code should already be formatted)
        let sanitizedCode = (cheat.code as NSString).replacingOccurrences(of: "\n", with: "")
        
        if sanitizedCode.characters.count % self.format.format.characters.count != 0
        {
            throw Error.invalidCode
        }
    }
}
