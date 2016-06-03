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
        get { return self.collectionView?.contentSize ?? CGSizeZero }
    }
    
    private var prototypeCell = GridCollectionViewCell()
    private var previousIndexPath: NSIndexPath? = nil
}

extension PauseMenuViewController
{
    override func viewDidLoad()
    {
        super.viewDidLoad()
                
        let collectionViewLayout = self.collectionViewLayout as! GridCollectionViewLayout
        collectionViewLayout.itemWidth = 95
        collectionViewLayout.usesEqualHorizontalSpacingDistributionForSingleRow = true
        
        // Manually update prototype cell properties
        self.prototypeCell.contentView.widthAnchor.constraintEqualToConstant(collectionViewLayout.itemWidth).active = true
    }
    
    override func viewDidAppear(animated: Bool)
    {
        super.viewDidAppear(animated)
        
        if let indexPath = self.previousIndexPath
        {
            UIView.animateWithDuration(0.2) {
                self.toggleSelectedStateForPauseItemAtIndexPath(indexPath)
            }
        }
    }
}

private extension PauseMenuViewController
{
    func configureCollectionViewCell(cell: GridCollectionViewCell, forIndexPath indexPath: NSIndexPath)
    {
        let pauseItem = self.items[indexPath.item]
        
        cell.maximumImageSize = CGSize(width: 60, height: 60)
        
        cell.imageView.image = pauseItem.image
        cell.imageView.contentMode = .Center
        cell.imageView.layer.borderWidth = 2
        cell.imageView.layer.borderColor = UIColor.whiteColor().CGColor
        cell.imageView.layer.cornerRadius = 10
        
        cell.textLabel.text = pauseItem.text
        cell.textLabel.textColor = UIColor.whiteColor()
        
        if pauseItem.selected
        {
            cell.imageView.tintColor = UIColor.blackColor()
            cell.imageView.backgroundColor = UIColor.whiteColor()
        }
        else
        {
            cell.imageView.tintColor = UIColor.whiteColor()
            cell.imageView.backgroundColor = UIColor.clearColor()
        }
    }
    
    func toggleSelectedStateForPauseItemAtIndexPath(indexPath: NSIndexPath)
    {
        var pauseItem = self.items[indexPath.item]
        pauseItem.selected = !pauseItem.selected
        self.items[indexPath.item] = pauseItem
        
        let cell = self.collectionView!.cellForItemAtIndexPath(indexPath) as! GridCollectionViewCell
        self.configureCollectionViewCell(cell, forIndexPath: indexPath)
    }
}

extension PauseMenuViewController
{
    override func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int
    {
        return self.items.count
    }
    
    override func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell
    {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(RSTGenericCellIdentifier, forIndexPath: indexPath) as! GridCollectionViewCell
        self.configureCollectionViewCell(cell, forIndexPath: indexPath)
        return cell
    }
}

extension PauseMenuViewController: UICollectionViewDelegateFlowLayout
{
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize
    {
        self.configureCollectionViewCell(self.prototypeCell, forIndexPath: indexPath)
        
        let size = self.prototypeCell.contentView.systemLayoutSizeFittingSize(UILayoutFittingCompressedSize)
        return size
    }
}

extension PauseMenuViewController
{
    override func collectionView(collectionView: UICollectionView, didHighlightItemAtIndexPath indexPath: NSIndexPath)
    {
        self.toggleSelectedStateForPauseItemAtIndexPath(indexPath)
    }
    
    override func collectionView(collectionView: UICollectionView, didUnhighlightItemAtIndexPath indexPath: NSIndexPath)
    {
        self.toggleSelectedStateForPauseItemAtIndexPath(indexPath)
    }
    
    override func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath)
    {
        self.previousIndexPath = indexPath
        
        self.toggleSelectedStateForPauseItemAtIndexPath(indexPath)
        
        let pauseItem = self.items[indexPath.item]
        pauseItem.action(pauseItem)
    }
}

