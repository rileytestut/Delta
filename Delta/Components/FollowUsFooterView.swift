//
//  FollowUsFooterView.swift
//  Delta
//
//  Created by Riley Testut on 2/26/25.
//  Copyright © 2025 Riley Testut. All rights reserved.
//

import UIKit

import Roxas

class FollowUsFooterView: RSTNibView
{
    let prefersFullColorIcons: Bool
    
    @IBOutlet var textLabel: UILabel!
    @IBOutlet var stackView: UIStackView!
    
    @IBOutlet private var mastodonButton: UIButton!
    @IBOutlet private var threadsButton: UIButton!
    @IBOutlet private var blueskyButton: UIButton!
    @IBOutlet private var githubButton: UIButton!
    @IBOutlet private var iconsStackView: UIStackView!
    
    @IBOutlet private var followRileyButton: UIButton!
    @IBOutlet private var followShaneButton: UIButton!
    @IBOutlet private var followCarolineButton: UIButton!
    
    @IBOutlet private var iconsHeightConstraint: NSLayoutConstraint!
    
    init(prefersFullColorIcons: Bool)
    {
        self.prefersFullColorIcons = prefersFullColorIcons
        
        super.init(frame: .zero)
        
        self.prepareFollowButtons()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private extension FollowUsFooterView
{
    func prepareFollowButtons()
    {
        struct MenuAction
        {
            var title: String
            var subtitle: String
            var image: UIImage?
            var handler: UIActionHandler
            
            func makeAction() -> UIAction
            {
                if #available(iOS 15, *)
                {
                    return UIAction(title: self.title, subtitle: self.subtitle, image: self.image, handler: self.handler)
                }
                else
                {
                    return UIAction(title: self.title, image: self.image, handler: self.handler)
                }
            }
        }
        
        let rileyActions = [
            MenuAction(title: NSLocalizedString("Mastodon", comment: ""), subtitle: NSLocalizedString("@rileytestut@mastodon.social", comment: ""), image: UIImage(named: "Mastodon")) { _ in
                let url = URL(string: "https://mastodon.social/@rileytestut")!
                UIApplication.shared.open(url, options: [:])
            },
            
            MenuAction(title: NSLocalizedString("Threads", comment: ""), subtitle: NSLocalizedString("@rileytestut", comment: ""), image: UIImage(named: "Threads")) { _ in
                let url = URL(string: "https://www.threads.net/@rileytestut")!
                UIApplication.shared.open(url, options: [:])
            },
            
            MenuAction(title: NSLocalizedString("Bluesky", comment: ""), subtitle: NSLocalizedString("@riley.social", comment: ""), image: UIImage(named: "Bluesky")) { _ in
                let url = URL(string: "https://bsky.app/profile/riley.social")!
                UIApplication.shared.open(url, options: [:])
            }
        ]
        
        let shaneActions = [
            MenuAction(title: NSLocalizedString("Threads", comment: ""), subtitle: NSLocalizedString("@shanegill.io", comment: ""), image: UIImage(named: "Threads")) { _ in
                let url = URL(string: "https://www.threads.net/@shanegill.io")!
                UIApplication.shared.open(url, options: [:])
            },
            
            MenuAction(title: NSLocalizedString("Bluesky", comment: ""), subtitle: NSLocalizedString("@shanegillio.bsky.social", comment: ""), image: UIImage(named: "Bluesky")) { _ in
                let url = URL(string: "https://bsky.app/profile/shanegillio.bsky.social")!
                UIApplication.shared.open(url, options: [:])
            }
        ]
        
        let carolineActions = [
            MenuAction(title: NSLocalizedString("Threads", comment: ""), subtitle: NSLocalizedString("@carolinemoore", comment: ""), image: UIImage(named: "Threads")) { _ in
                let url = URL(string: "https://threads.net/@carolinemoore")!
                UIApplication.shared.open(url, options: [:])
            }
        ]
        
        let followRileyMenu = UIMenu(children: rileyActions.map { $0.makeAction() })
        self.followRileyButton.menu = followRileyMenu
        self.followRileyButton.showsMenuAsPrimaryAction = true
        
        let followShaneMenu = UIMenu(children: shaneActions.map { $0.makeAction() })
        self.followShaneButton.menu = followShaneMenu
        self.followShaneButton.showsMenuAsPrimaryAction = true
        
        let followCarolineMenu = UIMenu(children: carolineActions.map { $0.makeAction() })
        self.followCarolineButton.menu = followCarolineMenu
        self.followCarolineButton.showsMenuAsPrimaryAction = true
        
        if #available(iOS 16, *)
        {
            // Always show actions in order we've listed them.
            self.followRileyButton.preferredMenuElementOrder = .fixed
            self.followShaneButton.preferredMenuElementOrder = .fixed
            self.followCarolineButton.preferredMenuElementOrder = .fixed
        }
        
        if !self.prefersFullColorIcons
        {
            self.iconsHeightConstraint.constant = 35
            
            self.mastodonButton.tintColor = .secondaryLabel
            self.threadsButton.tintColor = .secondaryLabel
            self.blueskyButton.tintColor = .secondaryLabel
            self.githubButton.tintColor = .secondaryLabel
            
            if #available(iOS 15, *)
            {
                self.mastodonButton.configuration?.background.image = UIImage(named: "Mastodon")
                self.threadsButton.configuration?.background.image = UIImage(named: "Threads")
                self.blueskyButton.configuration?.background.image = UIImage(named: "Bluesky")
                self.githubButton.configuration?.background.image = UIImage(named: "GitHub")
            }
        }
        else
        {
            // Use values from nib
        }
        
        if #unavailable(iOS 15)
        {
            // Button configurations don't work on iOS 14, so just hide buttons instead.
            self.iconsStackView.isHidden = true
            self.iconsHeightConstraint.isActive = false
        }
    }
    
    @IBAction func followOnMastodon()
    {
        let url = URL(string: "https://indieapps.space/@delta")!
        UIApplication.shared.open(url, options: [:])
    }
    
    @IBAction func followOnThreads()
    {
        let url = URL(string: "https://www.threads.net/@delta_emulator")!
        UIApplication.shared.open(url, options: [:])
    }
    
    @IBAction func followOnBluesky()
    {
        let url = URL(string: "https://bsky.app/profile/delta-emulator.bsky.social")!
        UIApplication.shared.open(url, options: [:])
    }
    
    @IBAction func followOnGitHub()
    {
        let url = URL(string: "https://github.com/rileytestut/delta")!
        UIApplication.shared.open(url, options: [:])
    }
}
