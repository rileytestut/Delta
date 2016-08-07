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
            
            self.collectionView?.reloadData()
        }
    }
    
    override var preferredContentSize: CGSize {
        set { }
        get { return self.collectionView?.contentSize ?? CGSize.zero }
    }
    
    private var prototypeCell = GridCollectionViewCell()
    private var previousIndexPath: IndexPath? = nil
}

extension PauseMenuViewController
{
    override func viewDidLoad()
    {
        super.viewDidLoad()
                
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
    func configureCollectionViewCell(_ cell: GridCollectionViewCell, forIndexPath indexPath: IndexPath)
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
    }
    
    func toggleSelectedStateForPauseItemAtIndexPath(_ indexPath: IndexPath)
    {
        var pauseItem = self.items[(indexPath as NSIndexPath).item]
        pauseItem.selected = !pauseItem.selected
        self.items[(indexPath as NSIndexPath).item] = pauseItem
        
        let cell = self.collectionView!.cellForItem(at: indexPath) as! GridCollectionViewCell
        self.configureCollectionViewCell(cell, forIndexPath: indexPath)
    }
}

extension PauseMenuViewController
{
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int
    {
        return self.items.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell
    {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: RSTGenericCellIdentifier, for: indexPath) as! GridCollectionViewCell
        self.configureCollectionViewCell(cell, forIndexPath: indexPath)
        return cell
    }
}

extension PauseMenuViewController: UICollectionViewDelegateFlowLayout
{
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize
    {
        self.configureCollectionViewCell(self.prototypeCell, forIndexPath: indexPath)
        
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
        
        let pauseItem = self.items[(indexPath as NSIndexPath).item]
        pauseItem.action(pauseItem)
    }
}

