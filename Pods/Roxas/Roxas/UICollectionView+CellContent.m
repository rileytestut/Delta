//
//  UICollectionView+CellContent.m
//  Roxas
//
//  Created by Riley Testut on 8/2/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

#import "UICollectionView+CellContent.h"
#import "RSTCellContentChange.h"

#import "RSTCellContentChangeOperation.h"

@import ObjectiveC.runtime;

@interface UICollectionView ()

@property (nonatomic) NSInteger rst_nestedUpdatesCounter;
@property (nullable, nonatomic) NSMutableArray<RSTCellContentChangeOperation *> *rst_operations;

@end

@implementation UICollectionView (CellContent)

- (void)beginUpdates
{
    if (self.rst_nestedUpdatesCounter == 0)
    {
        self.rst_operations = [NSMutableArray array];
    }
    
    self.rst_nestedUpdatesCounter++;
}

- (void)endUpdates
{
    if (self.rst_nestedUpdatesCounter <= 0)
    {
        return;
    }
    
    self.rst_nestedUpdatesCounter--;
    
    if (self.rst_nestedUpdatesCounter > 0)
    {
        return;
    }
    
    NSArray<RSTCellContentChangeOperation *> *operations = [self.rst_operations copy];
    self.rst_operations = nil;
    
    // According to documentation:
    // Move is reported when an object changes in a manner that affects its position in the results.  An update of the object is assumed in this case, no separate update message is sent to the delegate.
    
    // Therefore, we need to manually send another update message to items that moved after move is complete
    // (because it may crash if you try to update an item that is moving in the same batch updates block...)
    __block NSMutableArray<RSTCellContentChangeOperation *> *postMoveUpdateOperations = [NSMutableArray array];
    for (RSTCellContentChangeOperation *operation in operations)
    {
        if (operation.change.type != RSTCellContentChangeMove)
        {
            continue;
        }
        
        RSTCellContentChange *change = [[RSTCellContentChange alloc] initWithType:RSTCellContentChangeUpdate currentIndexPath:operation.change.destinationIndexPath destinationIndexPath:nil];
        
        RSTCollectionViewChangeOperation *updateOperation = [[RSTCollectionViewChangeOperation alloc] initWithChange:change collectionView:self];
        [postMoveUpdateOperations addObject:updateOperation];
    }
    
    [CATransaction begin];
    [CATransaction setCompletionBlock:^{
        
        // Perform additional updates after any moved items have been moved.
        // These additional updates must be performed after the first batch of operations have finished animating, or else the animation looks weird.
        // However, the completion block for performBatchUpdates: is only called if the updates result in an animation.
        // Since there is no way to know if an animation will actually occur (dependent on multiple factors), we explicitly create our own CATransaction.
        // If there are no animations, the CATransaction's completion block will be called immediately. If there *are* animations, the completion block will be called after the animations finish.
                
        [self performBatchUpdates:^{
            for (RSTCellContentChangeOperation *operation in postMoveUpdateOperations)
            {
                [operation start];
            }
        } completion:nil];
    }];
    
    [self performBatchUpdates:^{
        for (RSTCellContentChangeOperation *operation in operations)
        {
            [operation start];
        }
    } completion:nil];
    
    [CATransaction commit];
}

- (void)addChange:(RSTCellContentChange *)change
{
    RSTCollectionViewChangeOperation *operation = [[RSTCollectionViewChangeOperation alloc] initWithChange:change collectionView:self];
    [self.rst_operations addObject:operation];
}

#pragma mark - Getters/Setters -

- (Protocol *)dataSourceProtocol
{
    return @protocol(UICollectionViewDataSource);
}

- (NSInteger)rst_nestedUpdatesCounter
{
    return [objc_getAssociatedObject(self, @selector(rst_nestedUpdatesCounter)) integerValue];
}

- (void)setRst_nestedUpdatesCounter:(NSInteger)rst_nestedUpdatesCounter
{
    NSNumber *value = (rst_nestedUpdatesCounter != 0) ? @(rst_nestedUpdatesCounter) : nil;
    objc_setAssociatedObject(self, @selector(rst_nestedUpdatesCounter), value, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (NSMutableArray<RSTCellContentChangeOperation *> *)rst_operations
{
    return objc_getAssociatedObject(self, @selector(rst_operations));
}

- (void)setRst_operations:(NSMutableArray<RSTCellContentChangeOperation *> *)rst_operations
{
    objc_setAssociatedObject(self, @selector(rst_operations), rst_operations, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
