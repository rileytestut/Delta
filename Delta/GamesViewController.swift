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
            let alertController = UIAlertController(title: "Invalid Games Directory", message: "Please ensure the current games directory exists, then restart Delta.", preferredStyle: .Alert)
            alertController.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Cancel, handler: nil))
            
            self.presentViewController(alertController, animated: true, completion: nil)
        }
    }

    override func didReceiveMemoryWarning()
    {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    //MARK: UITableViewDelegate
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath)
    {
        if let URL = self.directoryContentsDataSource?.URLAtIndexPath(indexPath), game = Game(URL: URL) where game.UTI != kUTTypeDeltaGame as String
        {
            println(game.name)
            let emulatorCore = EmulatorCore(game: game)
        }
        else
        {
            let alertController = UIAlertController(title: "Unsupported Game", message: "This game is not supported by Delta. Please select another game.", preferredStyle: .Alert)
            alertController.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Cancel, handler: nil))
            
            self.presentViewController(alertController, animated: true, completion: nil)
            
            self.tableView.deselectRowAtIndexPath(indexPath, animated: true)
        }
    }
}

