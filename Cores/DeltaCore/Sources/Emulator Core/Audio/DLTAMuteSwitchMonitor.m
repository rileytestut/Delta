//
//  DLTAMuteSwitchMonitor.m
//  DeltaCore
//
//  Created by Riley Testut on 11/19/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

#import "DLTAMuteSwitchMonitor.h"

#import <notify.h>

#if STATIC_LIBRARY
#import "DeltaCore-Swift.h"
#else
#import <DeltaCore/DeltaCore-Swift.h>
#endif

@import AudioToolbox;

@interface DLTAMuteSwitchMonitor ()

@property (nonatomic, readwrite) BOOL isMonitoring;
@property (nonatomic, readwrite) BOOL isMuted;

@property (nonatomic) int notifyToken;

@end

@implementation DLTAMuteSwitchMonitor

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _isMuted = YES;
    }
    
    return self;
}

- (void)startMonitoring:(void (^)(BOOL isMuted))muteHandler
{
    if ([self isMonitoring])
    {
        return;
    }
    
    self.isMonitoring = YES;
    
    void (^updateMutedState)(void) = ^{
        uint64_t state;
        uint32_t result = notify_get_state(_notifyToken, &state);
        if (result == NOTIFY_STATUS_OK)
        {
            self.isMuted = (state == 0);
            muteHandler(self.isMuted);
        }
        else
        {
            NSLog(@"Failed to get mute state. Error: %@", @(result));
        }
    };
    
    notify_register_dispatch("com.apple.springboard.ringerstate", &_notifyToken, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(int token) {
        updateMutedState();
    });
    
    updateMutedState();
}

- (void)stopMonitoring
{
    if (![self isMonitoring])
    {
        return;
    }
    
    self.isMonitoring = NO;
    
    notify_cancel(self.notifyToken);
}

@end
