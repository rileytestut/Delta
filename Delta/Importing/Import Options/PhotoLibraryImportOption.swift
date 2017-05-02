//
//  PhotoLibraryImportOption.swift
//  Delta
//
//  Created by Riley Testut on 5/2/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import UIKit
import MobileCoreServices

class PhotoLibraryImportOption: NSObject, ImportOption
{
    let title = NSLocalizedString("Photo Library", comment: "")
    let image: UIImage? = nil
    
    private let presentingViewController: UIViewController
    fileprivate var completionHandler: ((Set<URL>?) -> Void)?
    
    init(presentingViewController: UIViewController)
    {
        self.presentingViewController = presentingViewController
        
        super.init()
    }
    
    func `import`(withCompletionHandler completionHandler: @escaping (Set<URL>?) -> Void)
    {
        self.completionHandler = completionHandler
        
        let imagePickerController = UIImagePickerController()
        imagePickerController.delegate = self
        imagePickerController.sourceType = .photoLibrary
        imagePickerController.mediaTypes = [kUTTypeImage as String]
        self.presentingViewController.present(imagePickerController, animated: true, completion: nil)
    }
}

extension PhotoLibraryImportOption: UIImagePickerControllerDelegate, UINavigationControllerDelegate
{
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any])
    {
        guard let image = info[UIImagePickerControllerOriginalImage] as? UIImage, let data = UIImageJPEGRepresentation(image, 0.85) else {
            self.completionHandler?([])
            return
        }
        
        do
        {
            let temporaryURL = FileManager.uniqueTemporaryURL()
            try data.write(to: temporaryURL, options: .atomic)
            
            self.completionHandler?([temporaryURL])
        }
        catch
        {
            self.completionHandler?([])
        }
    }
}
