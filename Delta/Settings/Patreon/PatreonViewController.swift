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

@available(iOS 17.5, *)
extension PatreonViewController
{
    private enum Section: Int, CaseIterable
    {
        case about
        case patrons
    }
}

@available(iOS 17.5, *)
class PatreonViewController: UICollectionViewController
{
    private lazy var dataSource = self.makeDataSource()
    private lazy var patronsDataSource = self.makePatronsDataSource()
    
    private var prototypeAboutHeader: AboutPatreonHeaderView!
    private weak var confirmEditNameAction: UIAlertAction?
        
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

@available(iOS 17.5, *)
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
        self.navigationItem.rightBarButtonItem?.isHidden = !RevenueCatManager.shared.hasBetaAccess
        
        self.collectionView.reloadData()
    }
    
    func prepare(_ headerView: AboutPatreonHeaderView)
    {
        headerView.layoutMargins = self.view.layoutMargins
        headerView.tintColor = .deltaPurple
        
        headerView.restorePurchaseButton.addTarget(self, action: #selector(PatreonViewController.restorePurchase), for: .primaryActionTriggered)
        
        if RevenueCatManager.shared.hasBetaAccess
        {
            headerView.supportButton.setTitle(String(localized: "Manage Subscription"), for: .normal)
            
            headerView.supportButton.removeTarget(self, action: #selector(PatreonViewController.becomeFriendZonePatron), for: .primaryActionTriggered)
            headerView.supportButton.addTarget(self, action: #selector(PatreonViewController.manageSubscription), for: .primaryActionTriggered)
        }
        else
        {
            var donateText = AttributedString(localized: "Become “Friend Zone Patron”")
            donateText.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
            
            var priceText = AttributedString(localized: "$12.99 per month, billed monthly")
            priceText.font = UIFont.systemFont(ofSize: 14, weight: .regular)
            
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            paragraphStyle.lineSpacing = 1.2
            
            let container = AttributeContainer([.paragraphStyle: paragraphStyle]) // Necessary to silence "NSParagraphStyle not Sendable" warning
            var attributedText = donateText + "\n" + priceText
            attributedText = attributedText.mergingAttributes(container, mergePolicy: .keepNew)
            
            headerView.supportButton.titleLabel?.numberOfLines = 0
            headerView.supportButton.setAttributedTitle(NSAttributedString(attributedText), for: .normal)
            
            headerView.supportButton.removeTarget(self, action: #selector(PatreonViewController.manageSubscription), for: .primaryActionTriggered)
            headerView.supportButton.addTarget(self, action: #selector(PatreonViewController.becomeFriendZonePatron), for: .primaryActionTriggered)
        }
    }
}

@available(iOS 17.5, *)
private extension PatreonViewController
{
    @objc func fetchPatrons()
    {
        // User explicitly navigated to this screen, so allow fetching friend zone patrons.
        UserDefaults.standard.shouldFetchFriendZonePatrons = true
        
        FriendZoneManager.shared.updatePatronsIfNeeded()
        self.update()
    }
    
    @objc func didUpdatePatrons(_ notification: Notification)
    {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Wait short delay before reloading or else footer won't properly update if it's already visible 🤷‍♂️
            self.collectionView.reloadData()
        }
    }
    
    @objc func becomeFriendZonePatron()
    {
        Task<Void, Never> {
            do
            {
                try await RevenueCatManager.shared.purchaseFriendZoneSubscription()
                
                self.update()
                
                // Ask for user's name if purchase is successful.
                self.editPatronName(nil)
            }
            catch is CancellationError
            {
                // Ignore
            }
            catch
            {
                let alertController = UIAlertController(title: NSLocalizedString("Unable to Purchase Friend Zone Subscription", comment: ""), error: error)
                self.present(alertController, animated: true)
            }
        }
    }
    
    @objc func manageSubscription()
    {
        guard let windowScene = self.view.window?.windowScene else { return }
        
        Task<Void, Never> {
            do
            {
                try await AppStore.showManageSubscriptions(in: windowScene, subscriptionGroupID: PurchaseManager.friendZoneSubscriptionGroupID)
            }
            catch
            {
                let alertController = UIAlertController(title: String(localized: "Unable to Manage Subscription"), error: error)
                self.present(alertController, animated: true)
            }
        }
    }
    
    @objc func restorePurchase()
    {
        Task<Void, Never> {
            do
            {
                try await RevenueCatManager.shared.requestRestorePurchases()
            }
            catch is CancellationError
            {
                // Ignore
            }
            catch
            {
                let alertController = UIAlertController(title: NSLocalizedString("Unable to Restore Purchase", comment: ""), error: error)
                self.present(alertController, animated: true)
            }
        }
    }
    
    @IBAction func editPatronName(_ sender: UIBarButtonItem?)
    {
        let alertTitle = (sender == nil) ? String(localized: "Thanks For Supporting Us!") : String(localized: "Edit Name")
        
        let alertController = UIAlertController(title: alertTitle, message: String(localized: "Please enter your full name so we can credit you on this page."), preferredStyle: .alert)
        alertController.addTextField { [weak self] textField in
            textField.textContentType = .name
            textField.autocapitalizationType = .words
            textField.autocorrectionType = .no
            textField.placeholder = String(localized: "Full Name")
            textField.returnKeyType = .done
            textField.enablesReturnKeyAutomatically = true
            textField.addTarget(self, action: #selector(PatreonViewController.editNameTextFieldChanged(_:)), for: .editingChanged)
            
            if let displayName = RevenueCatManager.shared.displayName
            {
                textField.text = displayName
            }
        }
        
        let cancelTitle = (RevenueCatManager.shared.displayName == nil) ? String(localized: "Maybe Later") : String(localized: "Cancel")
        let cancelAction = UIAlertAction(title: cancelTitle, style: .cancel)
        
        let editAction = UIAlertAction(title: String(localized: "Confirm"), style: .default) { [weak alertController] _ in
            guard let textField = alertController?.textFields?.first, let displayName = textField.text, !displayName.isEmpty else { return }
            
            Task<Void, Never> {
                do
                {
                    try await RevenueCatManager.shared.setDisplayName(displayName)
                }
                catch
                {
                    let alertController = UIAlertController(title: String(localized: "Unable to Update Display Name"), error: error)
                    self.present(alertController, animated: true)
                }
            }
        }
        self.confirmEditNameAction = editAction
        
        alertController.addAction(cancelAction)
        alertController.addAction(editAction)
        
        self.present(alertController, animated: true)
    }
    
    @objc func editNameTextFieldChanged(_ sender: UITextField)
    {
        let text = sender.text ?? ""
        self.confirmEditNameAction?.isEnabled = !text.isEmpty
    }
}

@available(iOS 17.5, *)
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

@available(iOS 17.5, *)
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
