//
//  PauseViewController.swift
//  Delta
//
//  Created by Riley Testut on 12/21/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import UIKit

struct PauseItem: Equatable
{
    let image: UIImage
    let text: String
    let action: (PauseItem -> Void)
    
    var selected = false
    
    init(image: UIImage, text: String, action: (PauseItem -> Void))
    {
        self.image = image
        self.text = text
        self.action = action
    }
}

func ==(lhs: PauseItem, rhs: PauseItem) -> Bool
{
    return (lhs.image == rhs.image) && (lhs.text == rhs.text)
}

class PauseViewController: UIViewController, PauseInfoProvidable
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
    
    var pauseText: String? = nil
    
    override var preferredContentSize: CGSize {
        set { }
        get { return self.collectionView.contentSize }
    }
    
    @IBOutlet private(set) var collectionView: UICollectionView!
    private var collectionViewLayout: GridCollectionViewLayout {
        return self.collectionView.collectionViewLayout as! GridCollectionViewLayout
    }
    
    private var prototypeCell = GridCollectionViewCell()
    
    override func preferredStatusBarStyle() -> UIStatusBarStyle
    {
        return .LightContent
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.collectionView.registerClass(GridCollectionViewCell.self, forCellWithReuseIdentifier: "Cell")
        
        self.collectionViewLayout.itemWidth = 90
        self.collectionViewLayout.usesEqualHorizontalSpacingDistributionForSingleRow = true
        
        self.navigationItem.rightBarButtonItem?.tintColor = UIColor.deltaLightPurpleColor()
        
        // Manually update prototype cell properties
        self.prototypeCell.contentView.widthAnchor.constraintEqualToConstant(self.collectionViewLayout.itemWidth).active = true
    }
}

internal extension PauseViewController
{
    func dismiss()
    {
        self.performSegueWithIdentifier("unwindPauseSegue", sender: self)
    }
}

private extension PauseViewController
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
        
        let cell = self.collectionView.cellForItemAtIndexPath(indexPath) as! GridCollectionViewCell
        self.configureCollectionViewCell(cell, forIndexPath: indexPath)
    }
}

extension PauseViewController: UICollectionViewDataSource
{
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int
    {
        return self.items.count
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell
    {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("Cell", forIndexPath: indexPath) as! GridCollectionViewCell
        self.configureCollectionViewCell(cell, forIndexPath: indexPath)
        return cell
    }
}

extension PauseViewController: UICollectionViewDelegateFlowLayout
{
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize
    {
        self.configureCollectionViewCell(self.prototypeCell, forIndexPath: indexPath)
        
        let size = self.prototypeCell.contentView.systemLayoutSizeFittingSize(UILayoutFittingCompressedSize)
        return size
    }
}

extension PauseViewController: UICollectionViewDelegate
{
    func collectionView(collectionView: UICollectionView, didHighlightItemAtIndexPath indexPath: NSIndexPath)
    {
        self.toggleSelectedStateForPauseItemAtIndexPath(indexPath)
    }
    
    func collectionView(collectionView: UICollectionView, didUnhighlightItemAtIndexPath indexPath: NSIndexPath)
    {
        self.toggleSelectedStateForPauseItemAtIndexPath(indexPath)
    }
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath)
    {
        self.toggleSelectedStateForPauseItemAtIndexPath(indexPath)
        
        let pauseItem = self.items[indexPath.item]
        pauseItem.action(pauseItem)
    }
}

