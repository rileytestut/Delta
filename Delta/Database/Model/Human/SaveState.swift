//
//  SaveState.swift
//  Delta
//
//  Created by Riley Testut on 1/31/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import Foundation

import DeltaCore

@objc public enum SaveStateType: Int16
{
    case auto
    case general
    case locked
}

@objc(SaveState)
public class SaveState: _SaveState, SaveStateProtocol
{
    public var fileURL: URL {
        let fileURL = DatabaseManager.saveStatesDirectoryURL(for: self.game!).appendingPathComponent(self.filename)
        return fileURL
    }
    
    public var imageFileURL: URL {
        let imageFilename = (self.filename as NSString).deletingPathExtension + ".png"
        let imageFileURL = DatabaseManager.saveStatesDirectoryURL(for: self.game!).appendingPathComponent(imageFilename)
        return imageFileURL
    }
    
    public var gameType: GameType {
        return self.game!.type
    }
    
    @NSManaged private var primitiveFilename: String
    @NSManaged private var primitiveIdentifier: String
    @NSManaged private var primitiveCreationDate: Date
    @NSManaged private var primitiveModifiedDate: Date
    
    public override func awakeFromInsert()
    {
        super.awakeFromInsert()
        
        let identifier = UUID().uuidString
        let date = Date()
        
        self.primitiveIdentifier = identifier
        self.primitiveFilename = identifier
        self.primitiveCreationDate = date
        self.primitiveModifiedDate = date
    }
    
    public override func prepareForDeletion()
    {
        super.prepareForDeletion()
        
        // In rare cases, game may actually be nil if game is corrupted, so we ensure it is non-nil first
        guard self.game != nil else { return }
        
        guard let managedObjectContext = self.managedObjectContext else { return }
        
        // If a save state with the same identifier is also currently being inserted, Core Data is more than likely resolving a conflict by deleting the previous instance
        // In this case, we make sure we DON'T delete the save state file + misc other Core Data relationships, or else we'll just lose all that data
        guard !managedObjectContext.insertedObjects.contains(where: { ($0 as? SaveState)?.identifier == self.identifier }) else { return }
        
        guard FileManager.default.fileExists(atPath: self.fileURL.path) else { return }
        
        do
        {
            try FileManager.default.removeItem(at: self.fileURL)
            try FileManager.default.removeItem(at: self.imageFileURL)
        }
        catch
        {
            print(error)
        }
    }
}
