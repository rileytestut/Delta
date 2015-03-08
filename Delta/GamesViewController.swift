//
//  GamesViewController.swift
//  Delta
//
//  Created by Riley Testut on 3/8/15.
//  Copyright (c) 2015 Riley Testut. All rights reserved.
//

import UIKit

class GamesViewController: UITableViewController
{
    let directoryContentsDataSource: DirectoryContentsDataSource?
    
    override init(style: UITableViewStyle)
    {
        let error: NSError? = nil;
        let documentsDirectoryURL = NSFileManager.defaultManager().URLsForDirectory(NSSearchPathDirectory.DocumentDirectory, inDomains: NSSearchPathDomainMask.UserDomainMask).first as! NSURL
        
        self.directoryContentsDataSource = DirectoryContentsDataSource(directoryURL: documentsDirectoryURL)
        
        super.init(style: style)
    }

    required init(coder aDecoder: NSCoder)
    {
        let error: NSError? = nil;
        let documentsDirectoryURL = NSFileManager.defaultManager().URLsForDirectory(NSSearchPathDirectory.DocumentDirectory, inDomains: NSSearchPathDomainMask.UserDomainMask).first as! NSURL
        
        self.directoryContentsDataSource = DirectoryContentsDataSource(directoryURL: documentsDirectoryURL)
        
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
            let alertController = UIAlertController(title: "Games Directory Invalid", message: "Please ensure the current games directory exists, then restart the app.", preferredStyle: .Alert)
            alertController.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Cancel, handler: nil))
            
            self.presentViewController(alertController, animated: true, completion: nil)
        }
    }

    override func didReceiveMemoryWarning()
    {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

