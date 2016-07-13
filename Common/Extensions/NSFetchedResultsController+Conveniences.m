//
//  NSFetchedResultsController+Conveniences.m
//  Delta
//
//  Created by Riley Testut on 7/13/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

#import "NSFetchedResultsController+Conveniences.h"

@import Roxas;

@implementation NSFetchedResultsController (Conveniences)

// Needs to be implemented in Objective-C due to current limitation of Swift:
// Extension of a generic Objective-C class cannot access the class's generic parameters at runtime
- (void)performFetchIfNeeded
{
    if (self.fetchedObjects != nil)
    {
        return;
    }
    
    NSError *error = nil;
    if (![self performFetch:&error])
    {
        ELog(error);
    }
}

@end
