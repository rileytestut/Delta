//
//  ImportController.swift
//  Delta
//
//  Created by Riley Testut on 10/10/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import UIKit
import MobileCoreServices
import ObjectiveC

import DeltaCore

import Roxas

protocol ImportControllerDelegate
{
    func importController(_ importController: ImportController, didImportItemsAt urls: Set<URL>)
    
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
    let documentTypes: Set<String>
    
    var delegate: ImportControllerDelegate?
    var importOptions: [ImportOption]?
    
    init(documentTypes: Set<String>)
    {
        self.documentTypes = documentTypes
        
        super.init()
    }
    
    fileprivate weak var presentingViewController: UIViewController?
    
    fileprivate func presentImportController(from presentingViewController: UIViewController, animated: Bool, completionHandler: ((Void) -> Void)?)
    {
        self.presentingViewController = presentingViewController
        
#if IMPACTOR
    
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alertController.addAction(UIAlertAction.cancel)
        
        if let importOptions = self.importOptions
        {
            for importOption in importOptions
            {
                alertController.add(importOption, completionHandler: finish(with:))
            }
        }
    
        self.presentingViewController?.present(alertController, animated: true, completion: nil)
    
#else
    
        let documentMenuController = UIDocumentMenuViewController(documentTypes: Array(self.documentTypes), in: .import)
        documentMenuController.delegate = self
        
        if let reversedImportOptions = self.importOptions?.reversed()
        {
            for importOption in reversedImportOptions
            {
                documentMenuController.add(importOption, order: .first, completionHandler: finish(with:))
            }
        }
    
        self.presentingViewController?.present(documentMenuController, animated: true, completion: nil)
#endif
        
    }
    
    fileprivate func finish(with urls: Set<URL>?)
    {
        if let urls = urls
        {
            self.delegate?.importController(self, didImportItemsAt: urls)
        }
        else
        {
            self.delegate?.importControllerDidCancel(self)
        }
        
        self.presentingViewController?.importController = nil
    }
}


extension ImportController: UIDocumentMenuDelegate
{
    func documentMenu(_ documentMenu: UIDocumentMenuViewController, didPickDocumentPicker documentPicker: UIDocumentPickerViewController)
    {
        documentPicker.delegate = self
        self.presentingViewController?.present(documentPicker, animated: true, completion: nil)
    }
    
    func documentMenuWasCancelled(_ documentMenu: UIDocumentMenuViewController)
    {
        self.finish(with: nil)
    }
}

extension ImportController: UIDocumentPickerDelegate
{
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL)
    {
        self.finish(with: [url])
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController)
    {
        self.finish(with: nil)
    }
}


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
        
        importController.presentImportController(from: self, animated: animated, completionHandler: completion)
    }
}
