//
//  PauseViewController.swift
//  Delta
//
//  Created by Riley Testut on 12/21/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import UIKit

struct PauseItem
{
    let image: UIImage
    let text: String
    let action: (PauseItem -> Void)
}

class PauseViewController: UIViewController, PauseInfoProvidable
{
    var items = [PauseItem]() {
        didSet {
            
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

        let pauseItem = PauseItem(image: UIImage(named: "Pause")!, text: "Resume", action: { _ in })
        self.items = [pauseItem, pauseItem, pauseItem, pauseItem, pauseItem, pauseItem]
    }
}

private extension PauseViewController
{
    func configureCollectionViewCell(cell: GridCollectionViewCell, forIndexPath indexPath: NSIndexPath)
    {
        let array = ["Save State", "Load State", "Cheat Codes", "Fast Forward", "Sustain Button", "Event Distribution"]
        
        cell.maximumImageSize = CGSize(width: 60, height: 60)
        
        cell.imageView.layer.borderWidth = 2
        cell.imageView.layer.borderColor = UIColor.whiteColor().CGColor
        cell.imageView.layer.cornerRadius = 10
        
        cell.textLabel.text = array[indexPath.item]
        cell.textLabel.textColor = UIColor.whiteColor()
    }
}

extension PauseViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout
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
    
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize
    {
        self.configureCollectionViewCell(self.prototypeCell, forIndexPath: indexPath)
        
        let size = self.prototypeCell.contentView.systemLayoutSizeFittingSize(UILayoutFittingCompressedSize)
        return size
    }
}

