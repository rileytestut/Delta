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
        let fileURL = DatabaseManager.saveStatesDirectoryURLForGame(self.game!).appendingPathComponent(self.filename)
        return fileURL
    }
    
    public var imageFileURL: URL {
        let imageFilename = (self.filename as NSString).deletingPathExtension + ".png"
        let imageFileURL = DatabaseManager.saveStatesDirectoryURLForGame(self.game!).appendingPathComponent(imageFilename)
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
