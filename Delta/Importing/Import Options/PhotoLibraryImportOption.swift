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
    private var completionHandler: ((Set<URL>?) -> Void)?
    
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
        imagePickerController.view.backgroundColor = .white
        self.presentingViewController.present(imagePickerController, animated: true, completion: nil)
    }
}

extension PhotoLibraryImportOption: UIImagePickerControllerDelegate, UINavigationControllerDelegate
{
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any])
    {
// Local variable inserted by Swift 4.2 migrator.
let info = convertFromUIImagePickerControllerInfoKeyDictionary(info)

        guard let image = info[convertFromUIImagePickerControllerInfoKey(UIImagePickerController.InfoKey.originalImage)] as? UIImage, let data = image.jpegData(compressionQuality: 0.85) else {
            self.completionHandler?([])
            return
        }
        
        do
        {
            let temporaryURL = FileManager.default.uniqueTemporaryURL()
            try data.write(to: temporaryURL, options: .atomic)
            
            self.completionHandler?([temporaryURL])
        }
        catch
        {
            self.completionHandler?([])
        }
    }
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromUIImagePickerControllerInfoKeyDictionary(_ input: [UIImagePickerController.InfoKey: Any]) -> [String: Any] {
	return Dictionary(uniqueKeysWithValues: input.map {key, value in (key.rawValue, value)})
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromUIImagePickerControllerInfoKey(_ input: UIImagePickerController.InfoKey) -> String {
	return input.rawValue
}
