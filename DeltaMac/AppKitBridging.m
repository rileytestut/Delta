//
//  AppKitBridging.m
//  DeltaMac
//
//  Created by Riley Testut on 8/12/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

#import "AppKitBridging.h"

#if TARGET_OS_MACCATALYST

NSNotificationName DLTAWindowDidBecomeKeyNotification = @"NSWindowDidBecomeKeyNotification";
NSNotificationName DLTAWindowWillStartLiveResizeNotification = @"NSWindowWillStartLiveResizeNotification";
NSNotificationName DLTAWindowDidEndLiveResizeNotification = @"NSWindowDidEndLiveResizeNotification";

@implementation UIWindow (AppKitBridging)

- (nullable NSObject *)nsWindow
{
    id delegate = [[NSClassFromString(@"NSApplication") sharedApplication] delegate];
    const SEL hostWinSEL = NSSelectorFromString([NSString stringWithFormat:@"_%@Window%@Window:", @"host", @"ForUI"]);
    @try {
        // There's also hostWindowForUIWindow 🤷‍♂️
        id nsWindow = [delegate performSelector:hostWinSEL withObject:self];
            
        // macOS 11.0 changed this to return an UINSWindowProxy
        SEL attachedWindow = NSSelectorFromString([NSString stringWithFormat:@"%@%@", @"attached", @"Window"]);
        if ([nsWindow respondsToSelector:attachedWindow])
        {
            nsWindow = [nsWindow valueForKey:NSStringFromSelector(attachedWindow)];
        }
        
        return nsWindow;
    } @catch (...) {
        NSLog(@"Failed to get NSWindow for %@.", self);
    }
    return nil;
}

@end

#endif
