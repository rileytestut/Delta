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
        
        let documentMenuController = UIDocumentMenuViewController(documentTypes: Array(Game.supportedTypeIdentifiers()), inMode: .Import)
        documentMenuController.delegate = self
        
        documentMenuController.addOptionWithTitle(NSLocalizedString("iTunes", comment: ""), image: nil, order: .First, handler: self.importFromiTunes)
        
        self.presentingViewController?.presentViewController(documentMenuController, animated: true, completion: nil)
    }
    
    private func importFromiTunes()
    {
        let documentsDirectoryURL = NSFileManager.defaultManager().URLsForDirectory(NSSearchPathDirectory.DocumentDirectory, inDomains: NSSearchPathDomainMask.UserDomainMask).first
        
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

private var GamePickerControllerKey: UInt8 = 0

extension UIViewController
{
    var gamePickerController: GamePickerController?
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