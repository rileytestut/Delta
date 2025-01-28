//
//  PHPhotoLibrary+Screenshots.swift
//  Delta
//
//  Created by Chris Rittenhouse on 4/24/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import UIKit
import Photos
import UniformTypeIdentifiers

extension PHPhotoLibrary
{
    class func requestAuthorizationIfNeeded() async throws
    {
        lazy var accessDeniedError: PHPhotosError = {
            let errorMessage = NSLocalizedString("Delta does not have permission to write to your Photos library.", comment: "")
            
            if #available(iOS 15, *)
            {
                return PHPhotosError(.accessUserDenied, userInfo: [NSLocalizedDescriptionKey: errorMessage])
            }
            else
            {
                return PHPhotosError(.internalError, userInfo: [NSLocalizedDescriptionKey: errorMessage])
            }
        }()
        
        let status = self.authorizationStatus(for: .addOnly)
        switch status
        {
        case .authorized, .limited: return
        case .denied, .restricted: throw accessDeniedError
        case .notDetermined: break
        @unknown default: break
        }
        
        try await withCheckedThrowingContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                switch status
                {
                case .authorized, .limited: continuation.resume()
                case .denied, .restricted, .notDetermined: continuation.resume(throwing: accessDeniedError)
                @unknown default: continuation.resume(throwing: accessDeniedError)
                }
            }
        }
    }
    
    func saveScreenshotData(_ data: Data) async throws
    {
        guard let screenshotsAlbum = try await self.fetchAlbum(named: "Delta Screenshots", createIfNeeded: true) else {
            // This should never be called as long as we pass `true` to createIfNeeded:
            throw PHPhotosError(.internalError, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("Unable to fetch “Delta Screenshots” album.", comment: "")])
        }
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var changeError: Error?
            
            PHPhotoLibrary.shared().performChanges({
                let options = PHAssetResourceCreationOptions()
                options.uniformTypeIdentifier = UTType.png.identifier
                
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, data: data, options: options)
                                
                do
                {
                    guard let changeRequest = PHAssetCollectionChangeRequest(for: screenshotsAlbum), let placeholderAsset = request.placeholderForCreatedAsset else {
                        throw PHPhotosError(.internalError, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("Could not add screenshot to album.", comment: "")])
                    }
                    
                    changeRequest.addAssets([placeholderAsset] as NSArray)
                }
                catch
                {
                    Logger.main.error("Failed to save screenshot to album. \(error.localizedDescription, privacy: .public)")
                    changeError = error
                }
                
            }) { success, error in
                if let error = error ?? changeError // Prioritize error over changeError
                {
                    // Error saving image
                    continuation.resume(throwing: error)
                }
                else
                {
                    // Image saved successfully
                    Logger.main.info("Saved screenshot of size \(data.count) to Photos app.")
                    continuation.resume()
                }
            }
        }
    }
}

private extension PHPhotoLibrary
{
    func fetchAlbum(named name: String, createIfNeeded: Bool) async throws -> PHAssetCollection?
    {
        if let album = self._fetchAlbum(named: name)
        {
            return album
        }
        
        guard createIfNeeded else { return nil }
        
        let album = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<PHAssetCollection, Error>) in
            PHPhotoLibrary.shared().performChanges({
                PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: name)
            }) { success, error in
                do
                {
                    if let error
                    {
                        throw error
                    }
                    
                    // Fetch album after creating it.
                    guard let album = self._fetchAlbum(named: name) else {
                        throw PHPhotosError(.internalError, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("The “Delta Screenshots” album could not be found.", comment: "")])
                    }
                    
                    continuation.resume(returning: album)
                }
                catch
                {
                    continuation.resume(throwing: error)
                }
            }
        }
        
        return album
    }
    
    // Can't call async function from inside PHPhotoLibrary completion handler,
    // so we pull out this logic into separate synchronous function.
    func _fetchAlbum(named name: String) -> PHAssetCollection?
    {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "title = %@", name)
        
        let fetchResult = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: options)
        
        let album = fetchResult.firstObject
        return album
    }
}
