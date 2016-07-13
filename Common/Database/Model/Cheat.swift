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
        case .gameShark: return 2
        case .codeBreaker: return 3
        }
    }
    
    init?(rawValue: Int16)
    {
        switch rawValue
        {
        case 0: self = .actionReplay
        case 1: self = .gameGenie
        case 2: self = .gameShark
        case 3: self = .codeBreaker
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
    @NSManaged var modifiedDate: Date
    @NSManaged var enabled: Bool
    
    @NSManaged private(set) var identifier: String
    @NSManaged private(set) var creationDate: Date
    
    // Must be optional relationship to satisfy weird Core Data requirement
    // https://forums.developer.apple.com/thread/20535
    @NSManaged var game: Game!
    
    var type: CheatType
    {
        get
        {
            self.willAccessValue(forKey: Attributes.type.rawValue)
            let type = CheatType(rawValue: self.primitiveType.int16Value)!
            self.didAccessValue(forKey: Attributes.type.rawValue)
            return type
        }
        set
        {
            self.willChangeValue(forKey: Attributes.type.rawValue)
            self.primitiveType = NSNumber(value: newValue.rawValue)
            self.didChangeValue(forKey: Attributes.type.rawValue)
        }
    }
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
