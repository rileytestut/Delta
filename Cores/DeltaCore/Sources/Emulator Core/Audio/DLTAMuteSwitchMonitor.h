//
//  DLTAMuteSwitchMonitor.h
//  DeltaCore
//
//  Created by Riley Testut on 11/19/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DLTAMuteSwitchMonitor : NSObject

@property (nonatomic, readonly) BOOL isMonitoring;
@property (nonatomic, readonly) BOOL isMuted;

- (void)startMonitoring:(void (^)(BOOL isMuted))muteHandler;
- (void)stopMonitoring;

@end

NS_ASSUME_NONNULL_END
