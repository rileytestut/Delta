//
//  DirectoryContentsDataSource.swift
//  Delta
//
//  Created by Riley Testut on 3/8/15.
//  Copyright (c) 2015 Riley Testut. All rights reserved.
//

import UIKit
import Foundation

public extension DirectoryContentsDataSource
{
    func URLAtIndexPath(indexPath: NSIndexPath) -> NSURL
    {
        let URL = self.directoryContents[indexPath.row]
        return URL
    }
}

public class DirectoryContentsDataSource: NSObject
{
    public let directoryURL: NSURL
    public var tableViewCellIdentifier: String = "Cell"
    
    public var contentsUpdateHandler: (Void -> Void)?
    public var cellConfigurationBlock: ((UITableViewCell, NSIndexPath, NSURL) -> Void)?
    
    private let fileDescriptor: Int32
    private let directoryMonitorDispatchQueue: dispatch_queue_t
    private let directoryMonitorDispatchSource: dispatch_source_t!
    
    private var directoryContents: [NSURL]
    
    required public init?(directoryURL: NSURL)
    {
        self.directoryURL = directoryURL
        self.fileDescriptor = open(self.directoryURL.fileSystemRepresentation, O_EVTONLY)
        
        self.directoryMonitorDispatchQueue = dispatch_queue_create("com.rileytestut.DirectoryContentsDataSource", DISPATCH_QUEUE_SERIAL)
        self.directoryMonitorDispatchSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_VNODE, UInt(self.fileDescriptor), DISPATCH_VNODE_WRITE, self.directoryMonitorDispatchQueue)
        
        self.directoryContents = [NSURL]()
        
        super.init()        
        
        if self.fileDescriptor < 0
        {
            return nil
        }
        
        if self.directoryMonitorDispatchSource == nil
        {
            close(self.fileDescriptor);
            
            return nil
        }
        
        dispatch_source_set_event_handler(self.directoryMonitorDispatchSource, {
            self.didUpdateDirectoryContents()
        });
        
        dispatch_source_set_cancel_handler(self.directoryMonitorDispatchSource, {
            close(self.fileDescriptor);
        });
        
        dispatch_resume(self.directoryMonitorDispatchSource);
        
        self.didUpdateDirectoryContents()
    }
    
    deinit
    {
        if self.fileDescriptor >= 0
        {
            close(self.fileDescriptor);
        }
        
        if self.directoryMonitorDispatchSource != nil
        {
            dispatch_source_cancel(self.directoryMonitorDispatchSource);
        }
    }
}

private extension DirectoryContentsDataSource
{
    func didUpdateDirectoryContents()
    {
        do
        {
            self.directoryContents = try NSFileManager.defaultManager().contentsOfDirectoryAtURL(self.directoryURL, includingPropertiesForKeys: nil, options:[NSDirectoryEnumerationOptions.SkipsSubdirectoryDescendants, NSDirectoryEnumerationOptions.SkipsHiddenFiles])
        }
        catch let error as NSError
        {
            print("\(error) \(error.userInfo)")
        }
        
        self.contentsUpdateHandler?()
    }
}

extension DirectoryContentsDataSource: UITableViewDataSource
{
    public func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        return self.directoryContents.count
    }
    
    public func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell
    {
        let tableViewCell = tableView.dequeueReusableCellWithIdentifier(self.tableViewCellIdentifier, forIndexPath: indexPath) as UITableViewCell
        
        self.cellConfigurationBlock?(tableViewCell, indexPath, self.URLAtIndexPath(indexPath))
        
        return tableViewCell
    }
}