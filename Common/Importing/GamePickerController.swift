//
//  GamePickerController.swift
//  Delta
//
//  Created by Riley Testut on 10/10/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import UIKit
import ObjectiveC

import DeltaCore

protocol GamePickerControllerDelegate
{
    func gamePickerController(_ gamePickerController: GamePickerController, didImportGames games: [Game])
    
    /** Optional **/
    func gamePickerControllerDidCancel(_ gamePickerController: GamePickerController)
}

extension GamePickerControllerDelegate
{
    func gamePickerControllerDidCancel(_ gamePickerController: GamePickerController)
    {
        // Empty Implementation
    }
}

class GamePickerController: NSObject
{
    var delegate: GamePickerControllerDelegate?
    
    private weak var presentingViewController: UIViewController?
    
    private func presentGamePickerControllerFromPresentingViewController(_ presentingViewController: UIViewController, animated: Bool, completion: ((Void) -> Void)?)
    {
        self.presentingViewController = presentingViewController
        
        #if os(iOS)
            let documentMenuController = UIDocumentMenuViewController(documentTypes: Array(Game.supportedTypeIdentifiers()), in: .import)
            documentMenuController.delegate = self
            documentMenuController.addOption(withTitle: NSLocalizedString("iTunes", comment: ""), image: nil, order: .first) { self.importFromiTunes(nil) }
            self.presentingViewController?.present(documentMenuController, animated: true, completion: nil)
        #else
            self.importFromiTunes(completion)
        #endif
    }
    
    private func importFromiTunes(_ completion: ((Void) -> Void)?)
    {
        let alertController = UIAlertController(title: NSLocalizedString("Import from iTunes?", comment: ""), message: NSLocalizedString("Delta will import the games copied over via iTunes.", comment: ""), preferredStyle: .alert)
        
        let importAction = UIAlertAction(title: NSLocalizedString("Import", comment: ""), style: .default) { action in
            
            let documentsDirectoryURL = DatabaseManager.defaultDirectoryURL().deletingLastPathComponent()
            
            do
            {
                let contents = try FileManager.default.contentsOfDirectory(at: documentsDirectoryURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
                
                DatabaseManager.shared.performBackgroundTask { (context) in
                    let gameURLs = contents.filter({ GameCollection.gameSystemCollectionForPathExtension($0.pathExtension, inManagedObjectContext: context).identifier != GameType.delta.rawValue })
                    self.importGamesAtURLs(gameURLs)
                }
                
            }
            catch let error as NSError
            {
                print(error)
            }
            
            self.presentingViewController?.gamePickerController = nil
            
        }
        alertController.addAction(importAction)
        
        let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel) { action in
            self.delegate?.gamePickerControllerDidCancel(self)
            self.presentingViewController?.gamePickerController = nil
        }
        alertController.addAction(cancelAction)
        
        self.presentingViewController?.present(alertController, animated: true, completion: completion)
    }
    
    private func importGamesAtURLs(_ URLs: [URL])
    {
        DatabaseManager.shared.importGames(at: URLs) { identifiers in
            
            DatabaseManager.shared.viewContext.perform() {
                
                let predicate = NSPredicate(format: "%K IN (%@)", Game.Attributes.identifier.rawValue, identifiers)
                let games = Game.instancesWithPredicate(predicate, inManagedObjectContext: DatabaseManager.shared.viewContext, type: Game.self)
                                
                self.delegate?.gamePickerController(self, didImportGames: games)
                
                self.presentingViewController?.gamePickerController = nil
                
            }            
        }
    }
}

#if os(iOS)
    
    extension GamePickerController: UIDocumentMenuDelegate
    {
        func documentMenu(_ documentMenu: UIDocumentMenuViewController, didPickDocumentPicker documentPicker: UIDocumentPickerViewController)
        {
            documentPicker.delegate = self
            self.presentingViewController?.present(documentPicker, animated: true, completion: nil)
            
            self.presentingViewController?.gamePickerController = nil
        }
        
        func documentMenuWasCancelled(_ documentMenu: UIDocumentMenuViewController)
        {
            self.delegate?.gamePickerControllerDidCancel(self)
            
            self.presentingViewController?.gamePickerController = nil
        }
        
    }
    
    extension GamePickerController: UIDocumentPickerDelegate
    {
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL)
        {
            self.importGamesAtURLs([url])
            
            self.presentingViewController?.gamePickerController = nil
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController)
        {
            self.delegate?.gamePickerControllerDidCancel(self)
            
            self.presentingViewController?.gamePickerController = nil
        }
    }
    
#endif

private var GamePickerControllerKey: UInt8 = 0

extension UIViewController
{
    fileprivate(set) var gamePickerController: GamePickerController?
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
    
    func presentGamePickerController(_ gamePickerController: GamePickerController, animated: Bool, completion: ((Void) -> Void)?)
    {
        self.gamePickerController = gamePickerController
        
        gamePickerController.presentGamePickerControllerFromPresentingViewController(self, animated: animated, completion: completion)
    }
}
