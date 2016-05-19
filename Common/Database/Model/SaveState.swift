//
//  SaveState.swift
//  Delta
//
//  Created by Riley Testut on 1/31/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

import DeltaCore

extension SaveState
{
    enum Attributes: String
    {
        case filename
        case identifier
        case name
        case creationDate
        case modifiedDate
        case type
        
        case game
        case previewGame
    }
    
    @objc enum Type: Int16
    {
        case Auto
        case General
        case Locked
    }
}

@objc(SaveState)
class SaveState: NSManagedObject, SaveStateType
{
    @NSManaged var name: String?
    @NSManaged var modifiedDate: NSDate
    @NSManaged var type: Type
    
    @NSManaged private(set) var filename: String
    @NSManaged private(set) var identifier: String
    @NSManaged private(set) var creationDate: NSDate
    
    // Must be optional relationship to satisfy weird Core Data requirement
    // https://forums.developer.apple.com/thread/20535
    @NSManaged var game: Game!
    
    @NSManaged var previewGame: Game?
    
    var fileURL: NSURL {
        let fileURL = DatabaseManager.saveStatesDirectoryURLForGame(self.game).URLByAppendingPathComponent(self.filename)
        return fileURL
    }
    
    var imageFileURL: NSURL {
        let imageFilename = (self.filename as NSString).stringByDeletingPathExtension + ".png"
        let imageFileURL = DatabaseManager.saveStatesDirectoryURLForGame(self.game).URLByAppendingPathComponent(imageFilename)
        return imageFileURL
    }
}

extension SaveState
{
    @NSManaged private var primitiveFilename: String
    @NSManaged private var primitiveIdentifier: String
    @NSManaged private var primitiveCreationDate: NSDate
    @NSManaged private var primitiveModifiedDate: NSDate
    
    override func awakeFromInsert()
    {
        super.awakeFromInsert()
        
        let identifier = NSUUID().UUIDString
        let date = NSDate()
        
        self.primitiveIdentifier = identifier
        self.primitiveFilename = identifier
        self.primitiveCreationDate = date
        self.primitiveModifiedDate = date
    }
}