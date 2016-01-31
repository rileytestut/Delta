//
//  SaveStatesViewController.swift
//  Delta
//
//  Created by Riley Testut on 1/23/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import UIKit

import Roxas

private let SaveStatesViewControllerContentInset: CGFloat = 20

class SaveStatesViewController: UICollectionViewController
{
    private var backgroundView: RSTBackgroundView!
    
    private var prototypeCell = GridCollectionViewCell()
    private var prototypeCellWidthConstraint: NSLayoutConstraint!
}

extension SaveStatesViewController
{
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.backgroundView = RSTBackgroundView(frame: self.view.bounds)
        self.backgroundView.hidden = true
        self.backgroundView.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        self.backgroundView.textLabel.text = NSLocalizedString("No Save States", comment: "")
        self.backgroundView.textLabel.textColor = UIColor.whiteColor()
        self.backgroundView.detailTextLabel.text = NSLocalizedString("You can create a new save state by pressing the + button in the top right.", comment: "")
        self.backgroundView.detailTextLabel.textColor = UIColor.whiteColor()
        self.view.insertSubview(self.backgroundView, atIndex: 0)
        
        // We update the layout in code because we need to use our SaveStatesViewControllerContentInset constant
        // The reason for this is we cannot query the layout for its sectionInset in viewDidLayoutSubviews, so might as well be explicit in code with a constant
        // Otherwise, we could configure this all in Interface Builder, but we'd still need to hardcode 20 in for viewDidLayoutSubviews
        let collectionViewLayout = self.collectionViewLayout as! GridCollectionViewLayout
        collectionViewLayout.sectionInset = UIEdgeInsets(top: SaveStatesViewControllerContentInset, left: SaveStatesViewControllerContentInset, bottom: SaveStatesViewControllerContentInset, right: SaveStatesViewControllerContentInset)
        collectionViewLayout.minimumInteritemSpacing = SaveStatesViewControllerContentInset
        collectionViewLayout.minimumLineSpacing = SaveStatesViewControllerContentInset
        
        let portraitScreenWidth = UIScreen.mainScreen().coordinateSpace.convertRect(UIScreen.mainScreen().bounds, toCoordinateSpace: UIScreen.mainScreen().fixedCoordinateSpace).width
        collectionViewLayout.itemWidth = (portraitScreenWidth - ((SaveStatesViewControllerContentInset) * 3)) / 2
        
        // Manually update prototype cell properties
        self.prototypeCellWidthConstraint = self.prototypeCell.contentView.widthAnchor.constraintEqualToConstant(collectionViewLayout.itemWidth)
        self.prototypeCellWidthConstraint.active = true
    }
    
    override func didReceiveMemoryWarning()
    {
        super.didReceiveMemoryWarning()
    }
}

private extension SaveStatesViewController
{
    func configureCollectionViewCell(cell: GridCollectionViewCell, forIndexPath indexPath: NSIndexPath)
    {
        cell.imageView.backgroundColor = UIColor.whiteColor()
        cell.imageView.image = UIImage(named: "DeltaPlaceholder")
        
        cell.maximumImageSize = CGSizeMake(self.prototypeCellWidthConstraint.constant, (self.prototypeCellWidthConstraint.constant / 4.0) * 3.0)
        
        cell.textLabel.textColor = UIColor.whiteColor()
        cell.textLabel.font = UIFont.preferredFontForTextStyle(UIFontTextStyleSubheadline)
        cell.textLabel.text = "Save State"
    }
}

extension SaveStatesViewController
{
    override func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int
    {
        return 12
    }
    
    override func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell
    {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(RSTGenericCellIdentifier, forIndexPath: indexPath) as! GridCollectionViewCell
        self.configureCollectionViewCell(cell, forIndexPath: indexPath)
        return cell
    }
}

extension SaveStatesViewController: UICollectionViewDelegateFlowLayout
{
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize
    {
        self.configureCollectionViewCell(self.prototypeCell, forIndexPath: indexPath)
        
        let size = self.prototypeCell.contentView.systemLayoutSizeFittingSize(UILayoutFittingCompressedSize)
        return size
    }
}