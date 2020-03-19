//
//  NSFetchedResultsController+Conveniences.m
//  Delta
//
//  Created by Riley Testut on 7/13/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

#import "NSFetchedResultsController+Conveniences.h"

@implementation NSFetchedResultsController (Conveniences)

// Needs to be implemented in Objective-C, because it crashes the Swift compiler :(
- (BOOL)performFetchIfNeeded
{
    if (self.sections != nil)
    {
        return NO;
    }

    NSError *error = nil;
    if (![self performFetch:&error])
    {
        NSLog(@"%@", error);
    }
    
    return YES;
}

@end
