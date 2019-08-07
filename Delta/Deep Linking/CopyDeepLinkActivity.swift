//
//  CopyDeepLinkActivity.swift
//  Delta
//
//  Created by Riley Testut on 8/5/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import UIKit

extension UIActivity.ActivityType
{
    static let copyDeepLink = UIActivity.ActivityType("com.rileytestut.Delta.CopyDeepLink")
}

class CopyDeepLinkActivity: UIActivity
{
    override class var activityCategory: UIActivity.Category {
        return .action
    }
    
    override var activityType: UIActivity.ActivityType? {
        return .copyDeepLink
    }
    
    override var activityTitle: String? {
        return NSLocalizedString("Copy Deep Link", comment: "")
    }
    
    override var activityImage: UIImage? {
        return UIImage(named: "Link")
    }
    
    override func canPerform(withActivityItems activityItems: [Any]) -> Bool
    {
        if activityItems.contains(where: { $0 is Game })
        {
            return true
        }
        else
        {
            return false
        }
    }
    
    override func prepare(withActivityItems activityItems: [Any])
    {
        guard let game = activityItems.first(where: { $0 is Game }) as? Game else { return }
        
        let deepLink = URL(action: .launchGame(identifier: game.identifier))
        UIPasteboard.general.url = deepLink
    }
}
