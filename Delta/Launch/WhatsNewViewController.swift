//
//  WhatsNewViewController.swift
//  Delta
//
//  Created by Riley Testut on 2/18/25.
//  Copyright © 2025 Riley Testut. All rights reserved.
//

import UIKit

import Roxas

extension WhatsNewViewController
{
    private enum Section: Int
    {
        case general
        case patrons
    }
    
    private enum ElementKind: String
    {
        case sectionHeader
        case sectionFooter
    }
    
    struct NewFeature: Decodable
    {
        var name: String
        var caption: String
        var icon: String
        var fallbackIcon: String?
        
        var isPatronExclusive: Bool
        
        var image: UIImage? {
            if let image = UIImage(systemName: self.icon)
            {
                return image
            }
            
            if let fallbackIcon, let image = UIImage(systemName: fallbackIcon)
            {
                return image
            }
            
            return nil
        }
    }
}

class WhatsNewViewController: UICollectionViewController
{
    private lazy var dataSource = self.makeDataSource()
    
    private var footerView: FollowUsFooterView!
    private var backgroundBlurView: UIView!
    
    @IBOutlet private var headerView: UIView!
    
    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var titleStackView: UIStackView!
    
    @IBOutlet private var headerViewTopSpacingLayoutConstraint: NSLayoutConstraint!
    @IBOutlet private var headerViewBottomSpacingLayoutConstraint: NSLayoutConstraint!
    
    private var _previousInsets: UIEdgeInsets?
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        let layout = self.makeLayout()
        self.collectionView.collectionViewLayout = layout
        
        self.collectionView.register(UICollectionViewListCell.self, forSupplementaryViewOfKind: ElementKind.sectionHeader.rawValue, withReuseIdentifier: ElementKind.sectionHeader.rawValue)
        self.collectionView.register(UICollectionViewListCell.self, forSupplementaryViewOfKind: ElementKind.sectionFooter.rawValue, withReuseIdentifier: ElementKind.sectionFooter.rawValue)
        
        self.dataSource.proxy = self
        self.collectionView.dataSource = self.dataSource
        
        let fontDescriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .largeTitle).withSymbolicTraits(.traitBold)!
        self.titleLabel.font = UIFont(descriptor: fontDescriptor, size: 0.0)
        
        self.headerView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(self.headerView)
        
        self.backgroundBlurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
        self.backgroundBlurView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(self.backgroundBlurView)
        
        self.footerView = FollowUsFooterView(prefersFullColorIcons: true)
        self.footerView.translatesAutoresizingMaskIntoConstraints = false
        self.footerView.textLabel.isHidden = true
        self.view.addSubview(self.footerView)
        
        NSLayoutConstraint.activate([
            self.headerView.topAnchor.constraint(equalTo: self.view.topAnchor),
            self.headerView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            self.headerView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            
            self.footerView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            self.footerView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            self.footerView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            
            self.backgroundBlurView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            self.backgroundBlurView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            self.backgroundBlurView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            self.backgroundBlurView.heightAnchor.constraint(equalTo: self.footerView.heightAnchor)
        ])
        
        self.update()
    }
    
    override func viewDidLayoutSubviews()
    {
        super.viewDidLayoutSubviews()
        
        if self.traitCollection.verticalSizeClass == .compact || self.traitCollection.userInterfaceIdiom == .pad
        {
            self.headerViewTopSpacingLayoutConstraint.constant = 15
            self.headerViewBottomSpacingLayoutConstraint.constant = 15
        }
        else
        {
            self.headerViewTopSpacingLayoutConstraint.constant = 44
            self.headerViewBottomSpacingLayoutConstraint.constant = 30
        }
        
        var contentInset = self.collectionView.contentInset
        contentInset.top = self.headerView.bounds.height
        contentInset.bottom = (self.footerView.bounds.height - self.view.safeAreaInsets.bottom)
        
        let maximumContentHeight = self.view.bounds.height - (self.headerView.bounds.height + self.footerView.bounds.height)
        if self.collectionView.contentSize.height <= maximumContentHeight
        {
            self.collectionView.bounces = false
            
            // Adjust insets to vertically center content in view
            let difference = maximumContentHeight - self.collectionView.contentSize.height
            let inset = difference / 2.0
            contentInset.top += inset
            
            // Don't need to adjust bottom insets, just top to offset it into center.
            // self.collectionView.contentInset.bottom += inset
        }
        else
        {
            self.collectionView.bounces = true
        }
                
        if contentInset != _previousInsets
        {
            let isAtTop = self.collectionView.contentOffset.y.rounded() == -self.collectionView.contentInset.top.rounded()
            self.collectionView.contentInset = contentInset
            self.collectionView.verticalScrollIndicatorInsets.top = contentInset.top
            self.collectionView.verticalScrollIndicatorInsets.bottom = contentInset.bottom
            
            if isAtTop
            {
                self.collectionView.contentOffset.y = -self.collectionView.contentInset.top
            }
            
            _previousInsets = contentInset
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?)
    {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if previousTraitCollection?.verticalSizeClass != self.traitCollection.verticalSizeClass
        {
            self.update()
        }
    }
}

private extension WhatsNewViewController
{
    func makeLayout() -> UICollectionViewCompositionalLayout
    {
        let layoutConfig = UICollectionViewCompositionalLayoutConfiguration()
        layoutConfig.contentInsetsReference = .layoutMargins
        
        let layout = UICollectionViewCompositionalLayout(sectionProvider: { (sectionIndex, layoutEnvironment) -> NSCollectionLayoutSection? in
            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(50))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            
            let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(50))
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
            
            switch Section(rawValue: sectionIndex)!
            {
            case .general:
                let layoutSection = NSCollectionLayoutSection(group: group)
                layoutSection.interGroupSpacing = 8
                layoutSection.contentInsets.top = 0
                layoutSection.contentInsets.leading += 8
                layoutSection.contentInsets.trailing += 8
                return layoutSection
                
            case .patrons:
                let headerSize = NSCollectionLayoutSize(widthDimension: .estimated(100), heightDimension: .estimated(30))
                
                let layoutSection = NSCollectionLayoutSection(group: group)
                layoutSection.interGroupSpacing = 15
                layoutSection.contentInsets.top += 4
                layoutSection.contentInsets.bottom = 0
                layoutSection.contentInsets.leading += 8
                layoutSection.contentInsets.trailing += 8
                layoutSection.boundarySupplementaryItems = [
                    NSCollectionLayoutBoundarySupplementaryItem(layoutSize: headerSize, elementKind: ElementKind.sectionHeader.rawValue, alignment: .top),
                ]
                return layoutSection
            }
        }, configuration: layoutConfig)
        
        return layout
    }
    
    func makeDataSource() -> RSTCompositeCollectionViewDataSource<Box<NewFeature>>
    {
        do
        {
            let fileURL = Bundle.main.url(forResource: "WhatsNew", withExtension: "plist")!
            
            let data = try Data(contentsOf: fileURL)
            let features = try PropertyListDecoder().decode([NewFeature].self, from: data)
            
            let generalDataSource = RSTArrayCollectionViewDataSource<Box<NewFeature>>(items: features.filter { !$0.isPatronExclusive }.map(Box.init))
            let patronsDataSource = RSTArrayCollectionViewDataSource<Box<NewFeature>>(items: features.filter { $0.isPatronExclusive }.map(Box.init))
            
            let dataSource = RSTCompositeCollectionViewDataSource(dataSources: [generalDataSource, patronsDataSource])
            dataSource.cellConfigurationHandler = { (cell, feature, indexPath) in
                let cell = cell as! WhatsNewCollectionViewCell
                cell.configure(with: feature.value)
            }
            
            return dataSource
        }
        catch let error as NSError
        {
            fatalError("Failed to load WhatsNew.plist. \(error.debugDescription)")
        }
    }
    
    func update()
    {
        if self.traitCollection.verticalSizeClass == .compact
        {
            self.titleStackView.axis = .horizontal
            self.titleStackView.alignment = .firstBaseline
            self.titleStackView.spacing = 15
            
            self.footerView.stackView.axis = .horizontal
        }
        else
        {
            self.titleStackView.axis = .vertical
            self.titleStackView.alignment = .center
            self.titleStackView.spacing = 4
            
            self.footerView.stackView.axis = .vertical
        }
    }
}

private extension WhatsNewViewController
{
    @IBAction func dismissWhatsNew()
    {
        self.presentingViewController?.dismiss(animated: true)
    }
}

extension WhatsNewViewController
{
    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView
    {
        let headerView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: kind, for: indexPath) as! UICollectionViewListCell
        
        switch ElementKind(rawValue: kind)!
        {
        case .sectionHeader:
            var content: UIListContentConfiguration = .groupedHeader()
            content.text = NSLocalizedString("Experimental Features", comment: "")
            content.textProperties.color = .secondaryLabel
            headerView.contentConfiguration = content
            
        case .sectionFooter:
            var content: UIListContentConfiguration = .groupedFooter()
            content.text = NSLocalizedString("Experimental Features are still in development and will be available for everyone when finished.", comment: "")
            content.textProperties.color = .secondaryLabel
            
            let fontDescriptor = content.textProperties.font.fontDescriptor.withSymbolicTraits(.traitItalic)!
            content.textProperties.font = UIFont(descriptor: fontDescriptor, size: content.textProperties.font.pointSize)
            
            headerView.contentConfiguration = content
        }
        
        return headerView
    }
}

extension WhatsNewViewController
{
    override func scrollViewDidScroll(_ scrollView: UIScrollView)
    {
        let viewport = scrollView.bounds.height - scrollView.contentInset.top - (scrollView.contentInset.bottom + self.view.safeAreaInsets.bottom)
        
        if scrollView.contentOffset.y.rounded() >= ((scrollView.contentSize.height - viewport) - scrollView.contentInset.top).rounded()
        {
            // At bottom of screen, so hide footer view background.
            self.backgroundBlurView.isHidden = true
            self.footerView.backgroundColor = .systemBackground
        }
        else
        {
            self.backgroundBlurView.isHidden = false
            self.footerView.backgroundColor = nil
        }
    }
}
