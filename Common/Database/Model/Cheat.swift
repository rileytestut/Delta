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

extension CheatType
{
    var rawValue: Int16
    {
        switch self
        {
        case .actionReplay: return 0
        case .gameGenie: return 1
        }
    }
    
    init?(rawValue: Int16)
    {
        switch rawValue
        {
        case 0: self = .actionReplay
        case 1: self = .gameGenie
        default: return nil
        }
    }
}

@objc(Cheat)
class Cheat: NSManagedObject, CheatProtocol
{
    //TODO: Change type to String! when Swift 3 allows it
    @NSManaged var name: String?
    @NSManaged var code: String
    @NSManaged var modifiedDate: NSDate
    @NSManaged var enabled: Bool
    
    @NSManaged private(set) var identifier: String
    @NSManaged private(set) var creationDate: NSDate
    
    // Must be optional relationship to satisfy weird Core Data requirement
    // https://forums.developer.apple.com/thread/20535
    @NSManaged var game: Game!
    
    var type: CheatType
    {
        get
        {
            self.willAccessValueForKey(Attributes.type.rawValue)
            let type = CheatType(rawValue: self.primitiveType.shortValue)!
            self.didAccessValueForKey(Attributes.type.rawValue)
            return type
        }
        set
        {
            self.willChangeValueForKey(Attributes.type.rawValue)
            self.primitiveType = NSNumber(short: newValue.rawValue)
            self.didChangeValueForKey(Attributes.type.rawValue)
        }
    }
}

extension Cheat
{
    @NSManaged private var primitiveIdentifier: String
    @NSManaged private var primitiveCreationDate: NSDate
    @NSManaged private var primitiveModifiedDate: NSDate
    @NSManaged private var primitiveType: NSNumber
    
    override func awakeFromInsert()
    {
        super.awakeFromInsert()
        
        let identifier = NSUUID().UUIDString
        let date = NSDate()
        
        self.primitiveIdentifier = identifier
        self.primitiveCreationDate = date
        self.primitiveModifiedDate = date
    }
}
