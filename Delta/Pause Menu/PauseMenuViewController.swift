//
//  PauseMenuViewController.swift
//  Delta
//
//  Created by Riley Testut on 12/21/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import UIKit
import Roxas

class PauseMenuViewController: UICollectionViewController
{
    var items = [PauseItem]() {
        didSet
        {
            guard oldValue != self.items else { return }
            
            if self.items.count > 8
            {
                fatalError("PauseViewController only supports up to 8 items (for my sanity when laying out on a landscape iPhone 4s")
            }
            
            self.dataSource.items = self.items
        }
    }
    
    override var preferredContentSize: CGSize {
        set { }
        get { return self.collectionView?.contentSize ?? CGSize.zero }
    }
    
    fileprivate let dataSource = RSTArrayCollectionViewDataSource<PauseItem>(items: [])
    
    fileprivate var prototypeCell = GridCollectionViewCell()
    fileprivate var previousIndexPath: IndexPath? = nil
}

extension PauseMenuViewController
{
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.dataSource.cellConfigurationHandler = { [unowned self] (cell, item, indexPath) in
            self.configure(cell as! GridCollectionViewCell, for: indexPath)
        }
        self.collectionView?.dataSource = self.dataSource
                
        let collectionViewLayout = self.collectionViewLayout as! GridCollectionViewLayout
        collectionViewLayout.itemWidth = 90
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
                self.toggleSelectedStateForPauseItemAtIndexPath(indexPath)
            }
        }
    }
}

private extension PauseMenuViewController
{
    func configure(_ cell: GridCollectionViewCell, for indexPath: IndexPath)
    {
        let pauseItem = self.items[(indexPath as NSIndexPath).item]
        
        cell.maximumImageSize = CGSize(width: 60, height: 60)
        
        cell.imageView.image = pauseItem.image
        cell.imageView.contentMode = .center
        cell.imageView.layer.borderWidth = 2
        cell.imageView.layer.borderColor = UIColor.white.cgColor
        cell.imageView.layer.cornerRadius = 10
        
        cell.textLabel.text = pauseItem.text
        cell.textLabel.textColor = UIColor.white
        
        if pauseItem.selected
        {
            cell.imageView.tintColor = UIColor.black
            cell.imageView.backgroundColor = UIColor.white
        }
        else
        {
            cell.imageView.tintColor = UIColor.white
            cell.imageView.backgroundColor = UIColor.clear
        }
        
        cell.isImageViewVibrancyEnabled = true
        cell.isTextLabelVibrancyEnabled = true
    }
    
    func toggleSelectedStateForPauseItemAtIndexPath(_ indexPath: IndexPath)
    {
        let pauseItem = self.items[indexPath.item]
        pauseItem.selected = !pauseItem.selected
        
        let cell = self.collectionView!.cellForItem(at: indexPath) as! GridCollectionViewCell
        self.configure(cell, for: indexPath)
    }
}

extension PauseMenuViewController: UICollectionViewDelegateFlowLayout
{
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize
    {
        self.configure(self.prototypeCell, for: indexPath)
        
        let size = self.prototypeCell.contentView.systemLayoutSizeFitting(UILayoutFittingCompressedSize)
        return size
    }
}

extension PauseMenuViewController
{
    override func collectionView(_ collectionView: UICollectionView, didHighlightItemAt indexPath: IndexPath)
    {
        self.toggleSelectedStateForPauseItemAtIndexPath(indexPath)
    }
    
    override func collectionView(_ collectionView: UICollectionView, didUnhighlightItemAt indexPath: IndexPath)
    {
        self.toggleSelectedStateForPauseItemAtIndexPath(indexPath)
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath)
    {
        self.previousIndexPath = indexPath
        
        self.toggleSelectedStateForPauseItemAtIndexPath(indexPath)
        
        let pauseItem = self.items[indexPath.item]
        pauseItem.action(pauseItem)
    }
}

