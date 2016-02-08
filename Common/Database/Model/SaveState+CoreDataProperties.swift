//
//  SaveState+CoreDataProperties.swift
//  Delta
//
//  Created by Riley Testut on 1/31/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData

enum SaveStateAttributes: String
{
    case filename
    case identifier
    case name
    case creationDate
    case modifiedDate
    
    case game
}

extension SaveState
{
    @NSManaged var filename: String
    @NSManaged var identifier: String
    @NSManaged var name: String?
    @NSManaged var creationDate: NSDate
    @NSManaged var modifiedDate: NSDate
    
    // Must be optional relationship to satisfy weird Core Data requirement
    // https://forums.developer.apple.com/thread/20535
    @NSManaged var game: Game!
}
