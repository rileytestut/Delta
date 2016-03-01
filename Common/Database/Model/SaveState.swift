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

@objc(SaveState)
class SaveState: NSManagedObject, SaveStateType
{
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
