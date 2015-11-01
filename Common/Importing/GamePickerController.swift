//
//  GamePickerController.swift
//  Delta
//
//  Created by Riley Testut on 10/10/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import UIKit
import ObjectiveC

protocol GamePickerControllerDelegate
{
    func gamePickerController(gamePickerController: GamePickerController, didImportGames games: [Game])
    
    /** Optional **/
    func gamePickerControllerDidCancel(gamePickerController: GamePickerController)
}

extension GamePickerControllerDelegate
{
    func gamePickerControllerDidCancel(gamePickerController: GamePickerController)
    {
        // Empty Implementation
    }
}

class GamePickerController: NSObject
{
    var delegate: GamePickerControllerDelegate?
    
    private weak var presentingViewController: UIViewController?
    
    private func presentGamePickerControllerFromPresentingViewController(presentingViewController: UIViewController, animated: Bool, completion: (Void -> Void)?)
    {
        self.presentingViewController = presentingViewController
        
        #if os(iOS)
            let documentMenuController = UIDocumentMenuViewController(documentTypes: Array(Game.supportedTypeIdentifiers()), inMode: .Import)
            documentMenuController.delegate = self
            documentMenuController.addOptionWithTitle(NSLocalizedString("iTunes", comment: ""), image: nil, order: .First) { self.importFromiTunes(nil) }
            self.presentingViewController?.presentViewController(documentMenuController, animated: true, completion: nil)
        #else
            self.importFromiTunes(completion)
        #endif
    }
    
    private func importFromiTunes(completion: (Void -> Void)?)
    {
        let alertController = UIAlertController(title: NSLocalizedString("Import from iTunes?", comment: ""), message: NSLocalizedString("Delta will import the games copied over via iTunes.", comment: ""), preferredStyle: .Alert)
        
        let importAction = UIAlertAction(title: NSLocalizedString("Import", comment: ""), style: .Default) { action in
            
            let documentsDirectoryURL = DatabaseManager.databaseDirectoryURL.URLByDeletingLastPathComponent
            
            do
            {
                let contents = try NSFileManager.defaultManager().contentsOfDirectoryAtURL(documentsDirectoryURL!, includingPropertiesForKeys: nil, options: .SkipsHiddenFiles)
                
                let gameURLs = contents.filter({ Game.typeIdentifierForURL($0) != nil })
                self.importGamesAtURLs(gameURLs)
                
            }
            catch let error as NSError
            {
                print(error)
            }
            
            self.presentingViewController?.gamePickerController = nil
            
        }
        alertController.addAction(importAction)
        
        let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .Cancel) { action in
            self.delegate?.gamePickerControllerDidCancel(self)
            self.presentingViewController?.gamePickerController = nil
        }
        alertController.addAction(cancelAction)
        
        self.presentingViewController?.presentViewController(alertController, animated: true, completion: completion)
    }
    
    private func importGamesAtURLs(URLs: [NSURL])
    {
        DatabaseManager.sharedManager.importGamesAtURLs(URLs) { identifiers in
            
            DatabaseManager.sharedManager.managedObjectContext.performBlock() {
                
                let predicate = NSPredicate(format: "%K IN (%@)", GameAttributes.identifier.rawValue, identifiers)
                let games = Game.instancesWithPredicate(predicate, inManagedObjectContext: DatabaseManager.sharedManager.managedObjectContext, type: Game.self)
                                
                self.delegate?.gamePickerController(self, didImportGames: games)
                
                self.presentingViewController?.gamePickerController = nil
                
            }            
        }
    }
}

#if os(iOS)
    
    extension GamePickerController: UIDocumentMenuDelegate
    {
        func documentMenu(documentMenu: UIDocumentMenuViewController, didPickDocumentPicker documentPicker: UIDocumentPickerViewController)
        {
            documentPicker.delegate = self
            self.presentingViewController?.presentViewController(documentPicker, animated: true, completion: nil)
            
            self.presentingViewController?.gamePickerController = nil
        }
        
        func documentMenuWasCancelled(documentMenu: UIDocumentMenuViewController)
        {
            self.delegate?.gamePickerControllerDidCancel(self)
            
            self.presentingViewController?.gamePickerController = nil
        }
        
    }
    
    extension GamePickerController: UIDocumentPickerDelegate
    {
        func documentPicker(controller: UIDocumentPickerViewController, didPickDocumentAtURL url: NSURL)
        {
            self.importGamesAtURLs([url])
            
            self.presentingViewController?.gamePickerController = nil
        }
        
        func documentPickerWasCancelled(controller: UIDocumentPickerViewController)
        {
            self.delegate?.gamePickerControllerDidCancel(self)
            
            self.presentingViewController?.gamePickerController = nil
        }
    }
    
#endif

private var GamePickerControllerKey: UInt8 = 0

extension UIViewController
{
    private(set) var gamePickerController: GamePickerController?
    {
        set
        {
            objc_setAssociatedObject(self, &GamePickerControllerKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        get
        {
            return objc_getAssociatedObject(self, &GamePickerControllerKey) as? GamePickerController
        }
    }
    
    func presentGamePickerController(gamePickerController: GamePickerController, animated: Bool, completion: (Void -> Void)?)
    {
        self.gamePickerController = gamePickerController
        
        gamePickerController.presentGamePickerControllerFromPresentingViewController(self, animated: animated, completion: completion)
    }
}