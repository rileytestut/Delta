//
//  NSOperationQueue+KeyValue.swift
//  Delta
//
//  Created by Riley Testut on 2/26/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import Foundation
import ObjectiveC.runtime


extension NSOperationQueue
{
    private struct AssociatedKeys
    {
        static var OperationsDictionary = "delta_operationsDictionary"
    }

    private var operationsDictionary: NSMapTable {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.OperationsDictionary) as? NSMapTable ?? NSMapTable.strongToWeakObjectsMapTable()
        }

        set {
            objc_setAssociatedObject(self, &AssociatedKeys.OperationsDictionary, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    func addOperation(operation: NSOperation, forKey key: AnyObject)
    {
        self.operationsDictionary.objectForKey(key)
        self.addOperation(operation)
    }
    
    func operationForKey(key: AnyObject) -> NSOperation?
    {
        let operation = self.operationsDictionary.objectForKey(key) as? NSOperation
        return operation
    }
}