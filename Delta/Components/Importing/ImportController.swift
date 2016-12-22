//
//  ImportController.swift
//  Delta
//
//  Created by Riley Testut on 10/10/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import UIKit
import ObjectiveC

import DeltaCore

protocol ImportControllerDelegate
{
    func importController(_ importController: ImportController, didImport games: Set<Game>)
    func importController(_ importController: ImportController, didImport controllerSkins: Set<ControllerSkin>)
    
    /** Optional **/
    func importControllerDidCancel(_ importController: ImportController)
}

extension ImportControllerDelegate
{
    func importControllerDidCancel(_ importController: ImportController)
    {
        // Empty Implementation
    }
}

class ImportController: NSObject
{
    var delegate: ImportControllerDelegate?
    
    fileprivate weak var presentingViewController: UIViewController?
    
    fileprivate func presentImportController(from presentingViewController: UIViewController, animated: Bool, completion: ((Void) -> Void)?)
    {
        self.presentingViewController = presentingViewController
        
        var documentTypes = GameType.supportedTypes.map { $0.rawValue }
        documentTypes.append(kUTTypeDeltaControllerSkin as String)
        
        // Add GBA4iOS's exported UTIs in case user has GBA4iOS installed (which may override Delta's UTI declarations)
        documentTypes.append("com.rileytestut.gba")
        documentTypes.append("com.rileytestut.gbc")
        documentTypes.append("com.rileytestut.gb")
        
        #if os(iOS)
            let documentMenuController = UIDocumentMenuViewController(documentTypes: documentTypes, in: .import)
            documentMenuController.delegate = self
            documentMenuController.addOption(withTitle: NSLocalizedString("iTunes", comment: ""), image: nil, order: .first) { self.importFromiTunes(nil) }
            self.presentingViewController?.present(documentMenuController, animated: true, completion: nil)
        #else
            self.importFromiTunes(completion)
        #endif
    }
    
    private func importFromiTunes(_ completion: ((Void) -> Void)?)
    {
        let alertController = UIAlertController(title: NSLocalizedString("Import from iTunes?", comment: ""), message: NSLocalizedString("Delta will import the games and controller skins copied over via iTunes.", comment: ""), preferredStyle: .alert)
        
        let importAction = UIAlertAction(title: NSLocalizedString("Import", comment: ""), style: .default) { action in
            
            let documentsDirectoryURL = DatabaseManager.defaultDirectoryURL().deletingLastPathComponent()
            
            do
            {
                let contents = try FileManager.default.contentsOfDirectory(at: documentsDirectoryURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
                
                DatabaseManager.shared.performBackgroundTask { (context) in
                    let controllerSkinURLs = contents.filter { $0.pathExtension.lowercased() == "deltaskin" }
                    self.importControllerSkins(at: controllerSkinURLs)
                    
                    let gameURLs = contents.filter { GameType.gameType(forFileExtension: $0.pathExtension) != .unknown }
                    self.importGames(at: gameURLs)
                }
                
            }
            catch let error as NSError
            {
                print(error)
            }
            
            self.presentingViewController?.importController = nil
            
        }
        alertController.addAction(importAction)
        
        let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel) { action in
            self.delegate?.importControllerDidCancel(self)
            self.presentingViewController?.importController = nil
        }
        alertController.addAction(cancelAction)
        
        self.presentingViewController?.present(alertController, animated: true, completion: completion)
    }
    
    fileprivate func importGames(at urls: [URL])
    {
        DatabaseManager.shared.importGames(at: urls) { identifiers in
            
            DatabaseManager.shared.viewContext.perform() {
                
                let predicate = NSPredicate(format: "%K IN (%@)", #keyPath(Game.identifier), identifiers)
                let games = Game.instancesWithPredicate(predicate, inManagedObjectContext: DatabaseManager.shared.viewContext, type: Game.self)
                                
                self.delegate?.importController(self, didImport: Set(games))
                
                self.presentingViewController?.importController = nil
                
            }            
        }
    }
    
    fileprivate func importControllerSkins(at urls: [URL])
    {
        DatabaseManager.shared.importControllerSkins(at: urls) { identifiers in
            
            DatabaseManager.shared.viewContext.perform() {
                
                let predicate = NSPredicate(format: "%K IN (%@)", #keyPath(ControllerSkin.identifier), identifiers)
                let controllerSkins = ControllerSkin.instancesWithPredicate(predicate, inManagedObjectContext: DatabaseManager.shared.viewContext, type: ControllerSkin.self)
                
                self.delegate?.importController(self, didImport: Set(controllerSkins))
                
                self.presentingViewController?.importController = nil
                
            }
        }
    }
}

#if os(iOS)
    
    extension ImportController: UIDocumentMenuDelegate
    {
        func documentMenu(_ documentMenu: UIDocumentMenuViewController, didPickDocumentPicker documentPicker: UIDocumentPickerViewController)
        {
            documentPicker.delegate = self
            self.presentingViewController?.present(documentPicker, animated: true, completion: nil)
        }
        
        func documentMenuWasCancelled(_ documentMenu: UIDocumentMenuViewController)
        {
            self.delegate?.importControllerDidCancel(self)
            
            self.presentingViewController?.importController = nil
        }
        
    }
    
    extension ImportController: UIDocumentPickerDelegate
    {
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL)
        {
            if url.pathExtension.lowercased() == "deltaskin"
            {
                self.importControllerSkins(at: [url])
            }
            else
            {
                self.importGames(at: [url])
            }
            
            self.presentingViewController?.importController = nil
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController)
        {
            self.delegate?.importControllerDidCancel(self)
            
            self.presentingViewController?.importController = nil
        }
    }
    
#endif

private var ImportControllerKey: UInt8 = 0

extension UIViewController
{
    fileprivate(set) var importController: ImportController?
    {
        set
        {
            objc_setAssociatedObject(self, &ImportControllerKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        get
        {
            return objc_getAssociatedObject(self, &ImportControllerKey) as? ImportController
        }
    }
    
    func present(_ importController: ImportController, animated: Bool, completion: ((Void) -> Void)?)
    {
        self.importController = importController
        
        importController.presentImportController(from: self, animated: animated, completion: completion)
    }
}
