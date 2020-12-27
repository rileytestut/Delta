//
//  SyncProgress.swift
//  Harmony
//
//  Created by Riley Testut on 3/21/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import Foundation

extension SyncProgress
{
    enum Status
    {
        case fetchingChanges
        case uploading
        case downloading
        case deleting
    }
}

class SyncProgress: Progress
{
    var status: Status = .fetchingChanges {
        didSet {
            self.updateLocalizedAdditionalDescription()
        }
    }
    
    var activeProgress: Progress? {
        didSet {
            self.activeProgressObservation?.invalidate()
            
            if let progress = self.activeProgress
            {                
                self.activeProgressObservation = progress.observe(\.completedUnitCount) { [weak self] (progress, change) in
                    self?.updateLocalizedAdditionalDescription()
                }
            }
            
            self.updateLocalizedAdditionalDescription()
        }
    }
    
    private var activeProgressObservation: NSKeyValueObservation?
    
    override init(parent parentProgressOrNil: Progress?, userInfo userInfoOrNil: [ProgressUserInfoKey : Any]? = nil)
    {
        super.init(parent: parentProgressOrNil, userInfo: userInfoOrNil)
        
        self.localizedDescription = NSLocalizedString("Syncing…", comment: "")
        self.updateLocalizedAdditionalDescription()
    }
    
    private func updateLocalizedAdditionalDescription()
    {
        let localizedAdditionalDescription: String
        
        if let progress = self.activeProgress
        {
            // Ensures we start at 1, but never go past totalUnitCount.
            let count = min(progress.completedUnitCount + 1, progress.totalUnitCount)
            
            switch self.status
            {
            case .fetchingChanges: localizedAdditionalDescription = ""
            case .uploading: localizedAdditionalDescription = String.localizedStringWithFormat(NSLocalizedString("Uploading %d of %d", comment: ""), count, progress.totalUnitCount)
            case .downloading: localizedAdditionalDescription = String.localizedStringWithFormat(NSLocalizedString("Downloading %d of %d", comment: ""), count, progress.totalUnitCount)
            case .deleting: localizedAdditionalDescription = "" // Intentionally don't display anything for deleting.
            }
        }
        else
        {
            localizedAdditionalDescription = ""
        }
        
        self.localizedAdditionalDescription = localizedAdditionalDescription
    }
}
