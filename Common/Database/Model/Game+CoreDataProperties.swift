//
//  Game+CoreDataProperties.swift
//  Delta
//
//  Created by Riley Testut on 10/4/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData

enum GameAttributes: String
{
    case artworkURL
    case fileURL
    case identifier
    case name
    case typeIdentifier
}

extension Game
{
    @NSManaged var artworkURL: NSURL?
    @NSManaged var fileURL: NSURL
    @NSManaged var identifier: String
    @NSManaged var name: String
    @NSManaged var typeIdentifier: String
}
