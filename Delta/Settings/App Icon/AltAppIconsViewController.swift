//
//  AltAppIconsViewController.swift
//  AltStore
//
//  Created by Riley Testut on 2/14/24.
//  Copyright © 2024 Riley Testut. All rights reserved.
//

import UIKit
import SwiftUI
import Roxas

extension UIApplication
{
    static let didChangeAppIconNotification = Notification.Name("io.altstore.AppManager.didChangeAppIcon")
}

private final class AltIcon: Decodable
{
    static let defaultIconName: String = "AppIcon"
    
    var name: String
    var imageName: String
    
    private enum CodingKeys: String, CodingKey
    {
        case name
        case imageName
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.imageName = try container.decode(String.self, forKey: .imageName)
    }
}

extension AltAppIconsViewController
{
    private enum Section: String, CaseIterable, Decodable, CodingKeyRepresentable
    {
        case modern
        case classic
        case patrons
        
        var localizedName: String {
            switch self
            {
            case .modern: return NSLocalizedString("Modern", comment: "")
            case .classic: return NSLocalizedString("Classic", comment: "")
            case .patrons: return NSLocalizedString("Patrons", comment: "")
            }
        }
    }
}

class AltAppIconsViewController: UICollectionViewController
{
    private lazy var dataSource = self.makeDataSource()
    
    private var iconsBySection = [Section: [AltIcon]]()
    
    private var headerRegistration: UICollectionView.SupplementaryRegistration<UICollectionViewListCell>!
    private var footerRegistration: UICollectionView.SupplementaryRegistration<UICollectionViewListCell>!
    
    private var isPatronIconsUnlocked: Bool {
        #if BETA
        return true
        #else
        if let patreonAccount = DatabaseManager.shared.patreonAccount(), patreonAccount.hasPastBetaAccess
        {
            return true
        }
        else
        {
            return false
        }
        #endif
    }
        
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.title = NSLocalizedString("Change App Icon", comment: "")
        
        let collectionViewLayout = self.makeLayout()
        self.collectionView.collectionViewLayout = collectionViewLayout
        
        self.collectionView.backgroundColor = .systemGroupedBackground
        
        do
        {
            let fileURL = Bundle(for: AltAppIconsViewController.self).url(forResource: "AltIcons", withExtension: "plist")!
            let data = try Data(contentsOf: fileURL)
            
            let icons = try PropertyListDecoder().decode([Section: [AltIcon]].self, from: data)
            self.iconsBySection = icons
        }
        catch
        {
            Logger.main.error("Failed to load alternate icons. \(error.localizedDescription, privacy: .public)")
        }
        
        self.dataSource.proxy = self
        self.collectionView.dataSource = self.dataSource
        
        self.collectionView.register(UICollectionViewListCell.self, forCellWithReuseIdentifier: RSTCellContentGenericCellIdentifier)
        self.collectionView.register(UICollectionViewListCell.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: UICollectionView.elementKindSectionHeader)
                
        self.headerRegistration = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(elementKind: UICollectionView.elementKindSectionHeader) { (headerView, elementKind, indexPath) in
            let section = Section.allCases[indexPath.section]
                        
            var configuration = UIListContentConfiguration.groupedHeader()
            configuration.text = section.localizedName
            headerView.contentConfiguration = configuration
        }
        
        self.footerRegistration = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(elementKind: UICollectionView.elementKindSectionFooter) { (footerView, elementKind, indexPath) in
            var configuration = UIListContentConfiguration.groupedFooter()
            
            let section = Section.allCases[indexPath.section]
            switch section
            {
            case .patrons:
                #if BETA
                configuration.text = NSLocalizedString("Thank you for joining our Patreon!", comment: "")
                #else
                if self.isPatronIconsUnlocked
                {
                    configuration.text = NSLocalizedString("Thank you for joining our Patreon! These icons will remain available even after your subscription ends.", comment: "")
                }
                else
                {
                    configuration.text = NSLocalizedString("These icons are available as a thank you to anyone who has ever joined one of our Patreon tiers.\n\nThey will remain available even after your subscription ends.", comment: "")
                }
                #endif
                
            case .classic, .modern: break
            }
                        
            footerView.contentConfiguration = configuration
        }
    }
}

private extension AltAppIconsViewController
{
    func makeLayout() -> UICollectionViewCompositionalLayout
    {
        let layout = UICollectionViewCompositionalLayout { (sectionIndex, layoutEnvironment) -> NSCollectionLayoutSection? in
            var configuration = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
            configuration.showsSeparators = true
            configuration.backgroundColor = .clear
            configuration.headerMode = .supplementary
            
            let section = Section.allCases[sectionIndex]
            switch section
            {
            case .patrons: configuration.footerMode = .supplementary
            case .modern, .classic: break
            }
            
            let layoutSection = NSCollectionLayoutSection.list(using: configuration, layoutEnvironment: layoutEnvironment)
            return layoutSection
        }
        
        return layout
    }
    
    func makeDataSource() -> RSTCompositeCollectionViewDataSource<AltIcon>
    {
        let dataSources = Section.allCases.compactMap { self.iconsBySection[$0] }.filter { !$0.isEmpty }.map { icons in
            let dataSource = RSTArrayCollectionViewDataSource(items: icons)
            return dataSource
        }
        
        let dataSource = RSTCompositeCollectionViewDataSource(dataSources: dataSources)
        dataSource.cellConfigurationHandler = { [weak self] cell, icon, indexPath in
            let cell = cell as! UICollectionViewListCell
            let section = Section.allCases[indexPath.section]
            
            let imageWidth = 44.0
            let font = UIFont(descriptor: UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body), size: 0.0)
            
            var config = cell.defaultContentConfiguration()
            config.text = icon.name
            config.textProperties.font = font
            config.textProperties.color = .label
            
            let image = UIImage(named: icon.imageName, in: Bundle(for: AltAppIconsViewController.self), with: nil)
            config.image = image
            config.imageProperties.maximumSize = CGSize(width: imageWidth, height: imageWidth)
            config.imageProperties.cornerRadius = imageWidth / 5.0 // Copied from AppIconImageView
            
            if section == .patrons
            {
                if self?.isPatronIconsUnlocked == true
                {
                    config.textProperties.color = .label
                }
                else
                {
                    config.textProperties.color = .secondaryLabel
                }
            }
            
            cell.contentConfiguration = config

            if UIApplication.shared.alternateIconName == icon.imageName || (UIApplication.shared.alternateIconName == nil && icon.imageName == AltIcon.defaultIconName)
            {
                cell.accessories = [.checkmark()]
            }
            else
            {
                cell.accessories = []
            }
            
            cell.backgroundConfiguration = .listGroupedCell()
        }
        
        return dataSource
    }
}

extension AltAppIconsViewController
{
    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView
    {
        switch kind
        {
        case UICollectionView.elementKindSectionHeader:
            let headerView = self.collectionView.dequeueConfiguredReusableSupplementary(using: self.headerRegistration, for: indexPath)
            return headerView
            
        case UICollectionView.elementKindSectionFooter:
            let footerView = self.collectionView.dequeueConfiguredReusableSupplementary(using: self.footerRegistration, for: indexPath)
            return footerView
            
        default: return UICollectionReusableView()
        }        
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath)
    {
        let section = Section.allCases[indexPath.section]
        if section == .patrons
        {
            guard self.isPatronIconsUnlocked else { return }
        }
        
        let icon = self.dataSource.item(at: indexPath)
        guard UIApplication.shared.alternateIconName != icon.imageName else { return }
        
        // Deselect previous icon + select new icon
        collectionView.reloadData()
        
        // If assigning primary icon, pass "nil" as alternate icon name.
        let imageName = (icon.imageName == "AppIcon") ? nil : icon.imageName
        UIApplication.shared.setAlternateIconName(imageName) { error in
            if let error
            {
                let alertController = UIAlertController(title: NSLocalizedString("Unable to Change App Icon", comment: ""),
                                                        message: error.localizedDescription,
                                                        preferredStyle: .alert)
                alertController.addAction(.ok)
                self.present(alertController, animated: true)
                
                collectionView.reloadData()
            }
            else
            {
                NotificationCenter.default.post(name: UIApplication.didChangeAppIconNotification, object: icon)
            }
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool 
    {
        let section = Section.allCases[indexPath.section]
        switch section
        {
        case .modern, .classic: return true
        case .patrons where self.isPatronIconsUnlocked: return true
        case .patrons: return false
        }
    }
}

@available(iOS 17, *)
#Preview(traits: .portrait) {
    let altAppIconsViewController = AltAppIconsViewController(collectionViewLayout: UICollectionViewFlowLayout())
    
    let navigationController = UINavigationController(rootViewController: altAppIconsViewController)
    return navigationController
}
