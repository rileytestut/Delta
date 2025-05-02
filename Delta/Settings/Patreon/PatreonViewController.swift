//
//  PatreonViewController.swift
//  AltStore
//
//  Created by Riley Testut on 9/5/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import UIKit
import StoreKit

import Roxas

extension PatreonViewController
{
    private enum Section: Int, CaseIterable
    {
        case about
        case patrons
    }
}

class PatreonViewController: UICollectionViewController
{
    private lazy var dataSource = self.makeDataSource()
    private lazy var patronsDataSource = self.makePatronsDataSource()
    
    private var prototypeAboutHeader: AboutPatreonHeaderView!
    
    private var isUpdatingRevenueCatPatrons: Bool = false
        
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        let aboutHeaderNib = UINib(nibName: "AboutPatreonHeaderView", bundle: nil)
        self.prototypeAboutHeader = aboutHeaderNib.instantiate(withOwner: nil, options: nil)[0] as? AboutPatreonHeaderView
        
        self.collectionView.dataSource = self.dataSource
        
        self.collectionView.register(aboutHeaderNib, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "AboutHeader")
        self.collectionView.register(PatronsHeaderView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "PatronsHeader")
        self.collectionView.register(PatronsFooterView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: "PatronsFooter")
        
        NotificationCenter.default.addObserver(self, selector: #selector(PatreonViewController.didUpdatePatrons(_:)), name: FriendZoneManager.didUpdatePatronsNotification, object: nil)
        
        self.update()
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        
        self.fetchPatrons()
        
        self.update()
    }
    
    override func viewDidLayoutSubviews()
    {
        super.viewDidLayoutSubviews()
        
        let layout = self.collectionViewLayout as! UICollectionViewFlowLayout
        
        var itemWidth = (self.collectionView.bounds.width - (layout.sectionInset.left + layout.sectionInset.right + layout.minimumInteritemSpacing)) / 2
        itemWidth.round(.down)
        
        layout.itemSize = CGSize(width: itemWidth, height: layout.itemSize.height)
    }
}

private extension PatreonViewController
{
    func makeDataSource() -> RSTCompositeCollectionViewDataSource<ManagedPatron>
    {
        let aboutDataSource = RSTDynamicCollectionViewDataSource<ManagedPatron>()
        aboutDataSource.numberOfSectionsHandler = { 1 }
        aboutDataSource.numberOfItemsHandler = { _ in 0 }
        
        let dataSource = RSTCompositeCollectionViewDataSource<ManagedPatron>(dataSources: [aboutDataSource, self.patronsDataSource])
        dataSource.proxy = self
        return dataSource
    }
    
    func makePatronsDataSource() -> RSTFetchedResultsCollectionViewDataSource<ManagedPatron>
    {
        let fetchRequest: NSFetchRequest<ManagedPatron> = ManagedPatron.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "%K != nil", #keyPath(ManagedPatron.name)) // No use displaying patrons with nil names.
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(ManagedPatron.name), ascending: true, selector: #selector(NSString.caseInsensitiveCompare(_:)))]
        
        let patronsDataSource = RSTFetchedResultsCollectionViewDataSource<ManagedPatron>(fetchRequest: fetchRequest, managedObjectContext: DatabaseManager.shared.viewContext)
        patronsDataSource.cellConfigurationHandler = { (cell, patron, indexPath) in
            let cell = cell as! PatronCollectionViewCell
            cell.textLabel.text = patron.name
        }
        
        return patronsDataSource
    }
    
    func update()
    {
        self.collectionView.reloadData()
    }
    
    func prepare(_ headerView: AboutPatreonHeaderView)
    {
        headerView.layoutMargins = self.view.layoutMargins
        headerView.tintColor = .deltaPurple
        
        headerView.supportButton.addTarget(self, action: #selector(PatreonViewController.openPatreonURL(_:)), for: .primaryActionTriggered)
        headerView.accountButton.removeTarget(self, action: nil, for: .primaryActionTriggered)
        
        let defaultSupportButtonTitle = NSLocalizedString("Join for $3/month", comment: "")
        let isPatronSupportButtonTitle = NSLocalizedString("View Patreon", comment: "")
        
        let defaultText = NSLocalizedString("""
        Hey y'all,
        
        You can support future development of Delta by donating to us on Patreon. In return, you'll unlock Patreon-exclusive app icons and receive early access to new features.
        
        Thanks for all your support 💜
        Riley & Shane
        """, comment: "")
                
        let isPatronText = NSLocalizedString("""
        Hey ,
        
        You’re the best. Your account was linked successfully, so you now have access to Patreon-exclusive app icons and Experimental Features. You can find them all in Settings.
        
        Thanks for all of your support. Enjoy!
        Riley & Shane
        """, comment: "")
        
        if let account = DatabaseManager.shared.patreonAccount(), PatreonAPI.shared.isAuthenticated
        {
            headerView.accountButton.addTarget(self, action: #selector(PatreonViewController.signOut(_:)), for: .primaryActionTriggered)
            headerView.accountButton.setTitle(String(format: NSLocalizedString("Unlink %@", comment: ""), account.name), for: .normal)
            
            if account.hasBetaAccess
            {
                headerView.supportButton.setTitle(isPatronSupportButtonTitle, for: .normal)
                
                let font = UIFont.systemFont(ofSize: 16)
                let attributedText = NSMutableAttributedString(string: isPatronText, attributes: [.font: font,
                                                                                                  .foregroundColor: UIColor.label])
                
                let boldedName = NSAttributedString(string: account.firstName ?? account.name,
                                                    attributes: [.font: UIFont.boldSystemFont(ofSize: font.pointSize),
                                                                 .foregroundColor: UIColor.label])
                attributedText.insert(boldedName, at: 4)
                
                headerView.textView.attributedText = attributedText
            }
            else
            {
                headerView.supportButton.setTitle(defaultSupportButtonTitle, for: .normal)
                headerView.textView.text = defaultText
            }
        }
        else
        {
            headerView.accountButton.addTarget(self, action: #selector(PatreonViewController.authenticate(_:)), for: .primaryActionTriggered)
            
            headerView.supportButton.setTitle(defaultSupportButtonTitle, for: .normal)
            headerView.accountButton.setTitle(NSLocalizedString("Link Patreon account", comment: ""), for: .normal)
            
            headerView.textView.text = defaultText
        }
    }
}

private extension PatreonViewController
{
    @objc func fetchPatrons()
    {
        // User explicitly navigated to this screen, so allow fetching friend zone patrons.
        UserDefaults.standard.shouldFetchFriendZonePatrons = true
        
        if #available(iOS 17.5, *)
        {
            FriendZoneManager.shared.updatePatronsIfNeeded()
        }
        
        self.update()
    }
    
    @objc func didUpdatePatrons(_ notification: Notification)
    {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Wait short delay before reloading or else footer won't properly update if it's already visible 🤷‍♂️
            self.collectionView.reloadData()
        }
    }
    
    @objc func openPatreonURL(_ sender: UIButton)
    {
        func openPatreon()
        {
            let patreonURL: URL
            if PurchaseManager.shared.isActivePatron
            {
                patreonURL = URL(string: "https://patreon.com/rileyshane")!
            }
            else
            {
                patreonURL = UserDefaults.standard.externalPurchaseLink ?? URL(string: "https://patreon.com/join/rileyshane")!
            }
            
            UIApplication.shared.open(patreonURL, options: [:])
        }
        
        if UserDefaults.standard.isExternalPurchaseAlertDisabled
        {
            // External purchase alert is no longer required, so just open Patreon.
            openPatreon()
        }
        else
        {
            let alertController = UIAlertController(title: NSLocalizedString("Open in “Safari”?", comment: ""),
                                                    message: NSLocalizedString("You will leave the app and go to the developer's website.", comment: ""),
                                                    preferredStyle: .alert)
            alertController.addAction(.cancel)
            alertController.addAction(UIAlertAction(title: NSLocalizedString("Open", comment: ""), style: .default) { _ in
                openPatreon()
            })
            
            self.present(alertController, animated: true)
        }
    }
    
    @IBAction func authenticate(_ sender: UIButton)
    {
        PatreonAPI.shared.authenticate(presentingViewController: self) { (result) in
            do
            {
                let account = try result.get()
                let showThankYouAlert = account.hasBetaAccess
                
                try account.managedObjectContext?.save()
                                
                DispatchQueue.main.async {
                    self.update()
                    
                    if showThankYouAlert
                    {
                        let alertController = UIAlertController(title: NSLocalizedString("Thanks for Supporting Us!", comment: ""),
                                                                message: NSLocalizedString("You can now access Patreon-exclusive features like alternate app icons and Experimental Features.", comment: ""), preferredStyle: .alert)
                        alertController.addAction(.ok)
                        self.present(alertController, animated: true)
                    }
                }
            }
            catch is CancellationError
            {
                // Ignore
            }
            catch
            {
                DispatchQueue.main.async {
                    let alertController = UIAlertController(title: NSLocalizedString("Unable to Authenticate with Patreon", comment: ""), error: error)
                    self.present(alertController, animated: true)
                }
            }
        }
    }
    
    @IBAction func signOut(_ sender: UIButton)
    {
        func signOut()
        {
            PatreonAPI.shared.signOut { (result) in
                do
                {
                    try result.get()
                    
                    DispatchQueue.main.async {
                        self.update()
                    }
                }
                catch
                {
                    DispatchQueue.main.async {
                        let alertController = UIAlertController(title: NSLocalizedString("Unable to Sign Out of Patreon", comment: ""), error: error)
                        self.present(alertController, animated: true)
                    }
                }
            }
        }
        
        let alertController = UIAlertController(title: NSLocalizedString("Are you sure you want to unlink your Patreon account?", comment: ""),
                                                message: NSLocalizedString("You will no longer be able to access Patreon-exclusive features.", comment: ""),
                                                preferredStyle: .actionSheet)
        alertController.addAction(UIAlertAction(title: NSLocalizedString("Unlink Patreon Account", comment: ""), style: .destructive) { _ in signOut() })
        alertController.addAction(.cancel)
        alertController.popoverPresentationController?.sourceRect = sender.frame
        alertController.popoverPresentationController?.sourceView = sender.superview
        
        self.present(alertController, animated: true, completion: nil)
    }
}

extension PatreonViewController
{
    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView
    {
        let section = Section.allCases[indexPath.section]
        switch section
        {
        case .about:
            let headerView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "AboutHeader", for: indexPath) as! AboutPatreonHeaderView
            self.prepare(headerView)
            return headerView
            
        case .patrons:
            if kind == UICollectionView.elementKindSectionHeader
            {
                let headerView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "PatronsHeader", for: indexPath) as! PatronsHeaderView
                headerView.textLabel.text = NSLocalizedString("Special thanks to…", comment: "")
                return headerView
            }
            else
            {
                let footerView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "PatronsFooter", for: indexPath) as! PatronsFooterView
                footerView.button.isIndicatingActivity = false
                footerView.button.isHidden = false
                footerView.button.addTarget(self, action: #selector(PatreonViewController.fetchPatrons), for: .primaryActionTriggered)
                footerView.button.activityIndicatorView.color = .secondaryLabel
                footerView.button.setTitleColor(.secondaryLabel, for: .normal)
                
                switch FriendZoneManager.shared.updatePatronsResult
                {
                case _ where self.isUpdatingRevenueCatPatrons:
                    // Always show activity indicator when updating just RevenueCat patrons.
                    footerView.button.isIndicatingActivity = true
                    
                case .none: footerView.button.isIndicatingActivity = true
                case .success?: footerView.button.isHidden = true
                case .failure?:
                    #if DEBUG
                    let debug = true
                    #else
                    let debug = false
                    #endif
                    
                    if self.patronsDataSource.itemCount == 0 || debug
                    {
                        // Only show error message if there aren't any cached Patrons (or if this is a debug build).
                        
                        footerView.button.isHidden = false
                        footerView.button.setTitle(NSLocalizedString("Error Loading Patrons", comment: ""), for: .normal)
                    }
                    else
                    {
                        footerView.button.isHidden = true
                    }
                }
                
                return footerView
            }
        }
    }
}

extension PatreonViewController: UICollectionViewDelegateFlowLayout
{
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize
    {
        let section = Section.allCases[section]
        switch section
        {
        case .about:
            let widthConstraint = self.prototypeAboutHeader.widthAnchor.constraint(equalToConstant: collectionView.bounds.width)
            NSLayoutConstraint.activate([widthConstraint])
            defer { NSLayoutConstraint.deactivate([widthConstraint]) }
            
            self.prepare(self.prototypeAboutHeader)
            
            let size = self.prototypeAboutHeader.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
            return size
            
        case .patrons:
            return CGSize(width: 320, height: 20)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize
    {
        let section = Section.allCases[section]
        switch section
        {
        case .about: return .zero
        case .patrons: return CGSize(width: 320, height: 44)
        }
    }
}
