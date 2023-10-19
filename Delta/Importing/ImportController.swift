//
//  ImportController.swift
//  Delta
//
//  Created by Riley Testut on 10/10/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import UIKit
import MobileCoreServices
import UniformTypeIdentifiers
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
    
    weak var presentingViewController: UIViewController?
    
    weak var barButtonItem: UIBarButtonItem?
    weak var sourceView: UIView?
    
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
    
    func makeActions() -> [Action]
    {
        assert(self.presentingViewController != nil, "presentingViewController must be set before calling makeActions()")
        
        var actions = (self.importOptions ?? []).map { (option) -> Action in
            let action = Action(title: option.title, style: .default, image: option.image) { _ in
                option.import { importedURLs in
                    self.finish(with: importedURLs, errors: [])
                }
            }
            
            return action
        }
        
        let filesAction = Action(title: NSLocalizedString("Files", comment: ""), style: .default, image: UIImage(symbolNameIfAvailable: "doc")) { action in
            self.presentDocumentBrowser()
        }
        actions.append(filesAction)
        
        return actions
    }
    
    fileprivate func presentImportController(from presentingViewController: UIViewController, animated: Bool, completionHandler: (() -> Void)?)
    {
        self.presentingViewController = presentingViewController
        
        let actions = self.makeActions()
        
        if actions.count > 1
        {
            let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
            alertController.addAction(UIAlertAction.cancel)
            
            let alertActions = actions.map { UIAlertAction($0) }
            for action in alertActions
            {
                alertController.addAction(action)
            }
            
            if let sourceView = self.sourceView
            {
                alertController.popoverPresentationController?.sourceView = sourceView.superview
                alertController.popoverPresentationController?.sourceRect = sourceView.frame
            }
            else
            {
                alertController.popoverPresentationController?.barButtonItem = self.barButtonItem
            }
            
            self.presentedViewController = alertController
            self.presentingViewController?.present(alertController, animated: true, completion: nil)
        }
        else
        {
            self.presentDocumentBrowser()
        }
    }
    
    @objc private func cancel()
    {
        self.finish(with: nil, errors: [])
    }
    
    private func finish(with urls: Set<URL>?, errors: [Error])
    {
        DispatchQueue.main.async {
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
    
    private func presentDocumentBrowser()
    {
        let supportedTypes = self.documentTypes.compactMap { UTType($0) }
        
        let presentedViewController: UIViewController
        
        if #available(iOS 17, *)
        {
            // Prior to iOS 17, UIDocumentPickerViewController was too buggy to reliably use with iCloud Drive.
            
            let documentPickerViewController = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes, asCopy: true)
            documentPickerViewController.delegate = self
            documentPickerViewController.overrideUserInterfaceStyle = .dark
            documentPickerViewController.allowsMultipleSelection = true
            
            presentedViewController = documentPickerViewController
        }
        else
        {
            let documentBrowserViewController = UIDocumentBrowserViewController(forOpening: supportedTypes)
            documentBrowserViewController.delegate = self
            documentBrowserViewController.modalPresentationStyle = .fullScreen
            documentBrowserViewController.browserUserInterfaceStyle = .dark
            documentBrowserViewController.allowsPickingMultipleItems = true
            documentBrowserViewController.allowsDocumentCreation = false
            
            let cancelButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(ImportController.cancel))
            documentBrowserViewController.additionalTrailingNavigationBarButtonItems = [cancelButton]
                        
            presentedViewController = documentBrowserViewController
        }
        
        self.presentedViewController = presentedViewController
        self.presentingViewController?.present(presentedViewController, animated: true, completion: nil)
    }
}

extension ImportController
{
    func importExternalFile(at fileURL: URL, completionHandler: @escaping (Result<URL, Error>) -> Void)
    {
        let intent = NSFileAccessIntent.readingIntent(with: fileURL)
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
                    let temporaryURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileURL.lastPathComponent)
                    try FileManager.default.copyItem(at: intent.url, to: temporaryURL, shouldReplace: true)
                    
                    completionHandler(.success(temporaryURL))
                }
            }
            catch
            {
                completionHandler(.failure(error))
            }
        }
    }
}

extension ImportController: UIDocumentPickerDelegate
{
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt documentURLs: [URL])
    {
        self.finish(with: Set(documentURLs), errors: [])
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController)
    {
        self.cancel()
    }
}

extension ImportController: UIDocumentBrowserViewControllerDelegate
{
    func documentBrowser(_ controller: UIDocumentBrowserViewController, didPickDocumentsAt documentURLs: [URL])
    {
        var coordinatedURLs = Set<URL>()
        var errors = [Error]()
        
        let dispatchGroup = DispatchGroup()
        
        for url in documentURLs
        {
            dispatchGroup.enter()
            
            self.importExternalFile(at: url) { (result) in
                switch result
                {
                case .failure(let error): errors.append(error)
                case .success(let fileURL): coordinatedURLs.insert(fileURL)
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
    fileprivate var importController: ImportController?
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
