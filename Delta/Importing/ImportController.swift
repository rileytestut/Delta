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
    func importController(_ importController: ImportController, didImportItemsAt urls: Set<URL>, errors: [Error])
    
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
    
    private weak var presentingViewController: UIViewController?
    
    // Store presentedViewController separately, since when we dismiss we don't know if it has already been dismissed.
    // Calling dismiss on presentingViewController in that case would dismiss presentingViewController, which is bad.
    private weak var presentedViewController: UIViewController?
    
    private let importQueue: OperationQueue
    private let fileCoordinator: NSFileCoordinator
    
    init(documentTypes: Set<String>)
    {
        self.documentTypes = documentTypes
        
        let dispatchQueue = DispatchQueue(label: "com.rileytestut.Delta.ImportController.dispatchQueue", qos: .userInitiated, attributes: .concurrent)
        
        self.importQueue = OperationQueue()
        self.importQueue.name = "com.rileytestut.Delta.ImportController.importQueue"
        self.importQueue.underlyingQueue = dispatchQueue
        
        self.fileCoordinator = NSFileCoordinator(filePresenter: nil)
        
        super.init()
    }
    
    fileprivate func presentImportController(from presentingViewController: UIViewController, animated: Bool, completionHandler: (() -> Void)?)
    {
        self.presentingViewController = presentingViewController
        
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alertController.addAction(UIAlertAction.cancel)
        
        if let importOptions = self.importOptions
        {
            for importOption in importOptions
            {
                alertController.add(importOption) { [unowned self] (urls) in
                    self.finish(with: urls, errors: [])
                }
            }
        }
        
        let filesAction = UIAlertAction(title: NSLocalizedString("Files", comment: ""), style: .default) { (action) in
            let cancelButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(ImportController.cancel))
            
            let documentBrowserViewController = UIDocumentBrowserViewController(forOpeningFilesWithContentTypes: Array(self.documentTypes))
            documentBrowserViewController.delegate = self
            documentBrowserViewController.browserUserInterfaceStyle = .dark
            documentBrowserViewController.allowsPickingMultipleItems = true
            documentBrowserViewController.allowsDocumentCreation = false
            documentBrowserViewController.additionalTrailingNavigationBarButtonItems = [cancelButton]
            
            self.presentedViewController = documentBrowserViewController
            self.presentingViewController?.present(documentBrowserViewController, animated: true, completion: nil)
        }
        alertController.addAction(filesAction)
        
        self.presentedViewController = alertController
        self.presentingViewController?.present(alertController, animated: true, completion: nil)
    }
    
    @objc private func cancel()
    {
        self.finish(with: nil, errors: [])
    }
    
    private func finish(with urls: Set<URL>?, errors: [Error])
    {
        if let urls = urls
        {
            self.delegate?.importController(self, didImportItemsAt: urls, errors: errors)
        }
        else
        {
            self.delegate?.importControllerDidCancel(self)
        }
        
        self.presentedViewController?.dismiss(animated: true)
        
        self.presentingViewController?.importController = nil
    }
}

extension ImportController: UIDocumentBrowserViewControllerDelegate
{
    func documentBrowser(_ controller: UIDocumentBrowserViewController, didPickDocumentURLs documentURLs: [URL])
    {
        var coordinatedURLs = Set<URL>()
        var errors = [Error]()
        
        let dispatchGroup = DispatchGroup()
        
        for url in documentURLs
        {
            dispatchGroup.enter()
            
            let intent = NSFileAccessIntent.readingIntent(with: url)
            self.fileCoordinator.coordinate(with: [intent], queue: self.importQueue) { (error) in
                
                do
                {
                    if let error = error
                    {
                        throw error
                    }
                    else
                    {
                        // User intent.url, not url, as the system may have updated it when requesting access.
                        guard intent.url.startAccessingSecurityScopedResource() else { throw CocoaError.error(.fileReadNoPermission) }
                        defer { intent.url.stopAccessingSecurityScopedResource() }
                        
                        // Use url, not intent.url, to ensure the file name matches what was in the document browser.
                        let temporaryURL = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
                        
                        try FileManager.default.copyItem(at: intent.url, to: temporaryURL)
                        
                        coordinatedURLs.insert(temporaryURL)
                    }
                }
                catch
                {
                    errors.append(error)
                }
                
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: self.importQueue.underlyingQueue!) {
            self.finish(with: coordinatedURLs, errors: errors)
        }
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
    
    func present(_ importController: ImportController, animated: Bool, completion: (() -> Void)?)
    {
        self.importController = importController
        
        importController.presentImportController(from: self, animated: animated, completionHandler: completion)
    }
}
