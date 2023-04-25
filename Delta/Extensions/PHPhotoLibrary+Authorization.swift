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
    static var isAuthorized: Bool
    {
        // Check for authorization status
        let status = PHPhotoLibrary.authorizationStatus()
        switch status
        {
        case .authorized:
            return true
            
        case .denied, .restricted:
            return false
            
        case .notDetermined:
            // Request photo access from the user
            var success = false
            PHPhotoLibrary.requestAuthorization({ status in
                switch status
                {
                case .authorized:
                    success = true
                    
                case .denied, .restricted, .notDetermined: break
                    
                @unknown default: break
                }
            })
            return success
        @unknown default:
            return false
        }
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
