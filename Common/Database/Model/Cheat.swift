//
//  Cheat.swift
//  Delta
//
//  Created by Riley Testut on 5/19/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

import DeltaCore

extension Cheat
{
    enum Attributes: String
    {
        case identifier
        case name
        case code
        case type
        case enabled
        case creationDate
        case modifiedDate
        
        case game
    }
}

@objc(Cheat)
class Cheat: NSManagedObject, CheatProtocol
{
    @NSManaged var name: String?
    @NSManaged var code: String
    @NSManaged var type: CheatType
    @NSManaged var modifiedDate: Date
    @NSManaged var enabled: Bool
    
    @NSManaged private(set) var identifier: String
    @NSManaged private(set) var creationDate: Date
    
    // Must be optional relationship to satisfy weird Core Data requirement
    // https://forums.developer.apple.com/thread/20535
    @NSManaged var game: Game!
}

extension Cheat
{
    @NSManaged private var primitiveIdentifier: String
    @NSManaged private var primitiveCreationDate: Date
    @NSManaged private var primitiveModifiedDate: Date
    @NSManaged private var primitiveType: NSNumber
    
    override func awakeFromInsert()
    {
        super.awakeFromInsert()
        
        let identifier = UUID().uuidString
        let date = Date()
        
        self.primitiveIdentifier = identifier
        self.primitiveCreationDate = date
        self.primitiveModifiedDate = date
    }
}
