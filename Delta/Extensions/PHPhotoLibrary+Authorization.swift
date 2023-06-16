//
//  PHPhotoLibrary+Authorization.swift
//  Delta
//
//  Created by Chris Rittenhouse on 4/24/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import UIKit
import Photos

extension PHPhotoLibrary
{
    static func runIfAuthorized(code: @escaping () -> Void)
    {
        PHPhotoLibrary.requestAuthorization(for: .addOnly, handler: { success in
            switch success
            {
            case .authorized, .limited:
                code()
                
            case .denied, .restricted, .notDetermined:
                break
            }
        })
    }
    
    static func saveUIImage(image: UIImage)
    {
        // Save the image to the Photos app
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }, completionHandler: { success, error in
            if success
            {
                // Image saved successfully
                print("Image saved to Photos app.")
            }
            else
            {
                // Error saving image
                print("Error saving image: \(error?.localizedDescription ?? "Unknown error")")
            }
        })
    }
}
