//
//  GridMenuViewController.swift
//  Delta
//
//  Created by Riley Testut on 12/21/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import UIKit
import Roxas

class GridMenuViewController: UICollectionViewController
{
    var items: [MenuItem] {
        get { return self.dataSource.items }
        set { self.dataSource.items = newValue; self.updateItems() }
    }
    
    var isVibrancyEnabled = true
    
    override var preferredContentSize: CGSize {
        set { }
        get { return self.collectionView?.contentSize ?? CGSize.zero }
    }
    
    private let dataSource = RSTArrayCollectionViewDataSource<MenuItem>(items: [])
    
    private var prototypeCell = GridCollectionViewCell()
    private var previousIndexPath: IndexPath? = nil
    
    private var registeredKVOObservers = Set<NSKeyValueObservation>()
    
    init()
    {
        let collectionViewLayout = GridCollectionViewLayout()
        collectionViewLayout.itemSize = CGSize(width: 60, height: 80)
        collectionViewLayout.minimumLineSpacing = 20
        collectionViewLayout.minimumInteritemSpacing = 10
        
        super.init(collectionViewLayout: collectionViewLayout)
    }
    
    required init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
    }
    
    deinit
    {
        // Crashes on iOS 10 if not explicitly invalidated.
        self.registeredKVOObservers.forEach { $0.invalidate() }
    }
}

extension GridMenuViewController
{
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.collectionView?.register(GridCollectionViewCell.self, forCellWithReuseIdentifier: RSTCellContentGenericCellIdentifier)
        
        self.dataSource.cellConfigurationHandler = { [unowned self] (cell, item, indexPath) in
            self.configure(cell as! GridCollectionViewCell, for: indexPath)
        }
        self.collectionView?.dataSource = self.dataSource
                
        let collectionViewLayout = self.collectionViewLayout as! GridCollectionViewLayout
        collectionViewLayout.itemWidth = 80
        collectionViewLayout.usesEqualHorizontalSpacingDistributionForSingleRow = true
        
        // Manually update prototype cell properties
        self.prototypeCell.contentView.widthAnchor.constraint(equalToConstant: collectionViewLayout.itemWidth).isActive = true
    }
    
    override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)
        
        if let indexPath = self.previousIndexPath
        {
            UIView.animate(withDuration: 0.2) {
                let item = self.items[indexPath.item]
                item.isSelected = !item.isSelected
            }
        }
    }
}

private extension GridMenuViewController
{
    func configure(_ cell: GridCollectionViewCell, for indexPath: IndexPath)
    {
        let pauseItem = self.items[indexPath.item]
        
        cell.maximumImageSize = CGSize(width: 60, height: 60)
        
        cell.imageView.image = pauseItem.image
        cell.imageView.contentMode = .center
        cell.imageView.layer.borderWidth = 2
        cell.imageView.layer.borderColor = self.view.tintColor.cgColor
        cell.imageView.layer.cornerRadius = 10
        
        cell.textLabel.text = pauseItem.text
        cell.textLabel.textColor = self.view.tintColor
        
        if pauseItem.isSelected
        {
            cell.imageView.tintColor = UIColor.black
            cell.imageView.backgroundColor = self.view.tintColor
        }
        else
        {
            cell.imageView.tintColor = self.view.tintColor
            cell.imageView.backgroundColor = UIColor.clear
        }
        
        cell.isImageViewVibrancyEnabled = self.isVibrancyEnabled
        cell.isTextLabelVibrancyEnabled = self.isVibrancyEnabled
    }
    
    func updateItems()
    {
        self.registeredKVOObservers.removeAll()
        
        for (index, item) in self.items.enumerated()
        {
            let observer = item.observe(\.isSelected, changeHandler: { [unowned self] (item, change) in
                let indexPath = IndexPath(item: index, section: 0)
                
                if let cell = self.collectionView?.cellForItem(at: indexPath) as? GridCollectionViewCell
                {
                    self.configure(cell, for: indexPath)
                }
            })
            
            self.registeredKVOObservers.insert(observer)
        }
    }
}

extension GridMenuViewController: UICollectionViewDelegateFlowLayout
{
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize
    {
        self.configure(self.prototypeCell, for: indexPath)
        
        let size = self.prototypeCell.contentView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        return size
    }
}

extension GridMenuViewController
{
    override func collectionView(_ collectionView: UICollectionView, didHighlightItemAt indexPath: IndexPath)
    {
        let item = self.items[indexPath.item]
        item.isSelected = !item.isSelected
    }
    
    override func collectionView(_ collectionView: UICollectionView, didUnhighlightItemAt indexPath: IndexPath)
    {
        let item = self.items[indexPath.item]
        item.isSelected = !item.isSelected
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath)
    {
        self.previousIndexPath = indexPath
        
        let item = self.items[indexPath.item]
        item.isSelected = !item.isSelected
        item.action(item)
    }
}

