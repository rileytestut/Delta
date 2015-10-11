//
//  GamesViewController.swift
//  Delta
//
//  Created by Riley Testut on 3/8/15.
//  Copyright (c) 2015 Riley Testut. All rights reserved.
//

import UIKit
import DeltaCore

class GamesViewController: UITableViewController
{
    let directoryContentsDataSource: DirectoryContentsDataSource?
    
    override init(style: UITableViewStyle)
    {
        if let documentsDirectoryURL = NSFileManager.defaultManager().URLsForDirectory(NSSearchPathDirectory.DocumentDirectory, inDomains: NSSearchPathDomainMask.UserDomainMask).first
        {
            self.directoryContentsDataSource = DirectoryContentsDataSource(directoryURL: documentsDirectoryURL)
        }
        else
        {
            self.directoryContentsDataSource = nil
        }
        
        super.init(style: style)
    }

    required init?(coder aDecoder: NSCoder)
    {
        if let documentsDirectoryURL = NSFileManager.defaultManager().URLsForDirectory(NSSearchPathDirectory.DocumentDirectory, inDomains: NSSearchPathDomainMask.UserDomainMask).first
        {
            self.directoryContentsDataSource = DirectoryContentsDataSource(directoryURL: documentsDirectoryURL)
        }
        else
        {
            self.directoryContentsDataSource = nil
        }
        
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.tableView.dataSource = self.directoryContentsDataSource
        
        self.directoryContentsDataSource!.contentsUpdateHandler = {
            dispatch_async(dispatch_get_main_queue(), {
                self.tableView.reloadData()
            })
        }
        
        self.directoryContentsDataSource?.cellConfigurationBlock = { (cell, indexPath, URL) in
            cell.textLabel?.text = URL.lastPathComponent
        }
    }
    
    override func viewDidAppear(animated: Bool)
    {
        super.viewDidAppear(animated)
        
        if self.directoryContentsDataSource == nil
        {
            let alertController = UIAlertController(title: NSLocalizedString("Invalid Games Directory", comment: ""), message: NSLocalizedString("Please ensure the current games directory exists, then restart Delta.", comment: ""), preferredStyle: .Alert)
            alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: UIAlertActionStyle.Cancel, handler: nil))
            
            self.presentViewController(alertController, animated: true, completion: nil)
        }
    }

    override func didReceiveMemoryWarning()
    {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //MARK: - Settings -
    
    @IBAction func dismissSettingsViewController(segue: UIStoryboardSegue)
    {
        
    }
    
    // MARK: - Importing -
    
    @IBAction func importFiles()
    {
        let gamePickerController = GamePickerController()
        gamePickerController.delegate = self
        self.presentGamePickerController(gamePickerController, animated: true, completion: nil)
    }
    
    
    //MARK: UITableViewDelegate
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath)
    {
        
    }
}

extension GamesViewController: GamePickerControllerDelegate
{
    func gamePickerController(gamePickerController: GamePickerController, didImportGames games: [Game])
    {
        print(games)
    }
}

