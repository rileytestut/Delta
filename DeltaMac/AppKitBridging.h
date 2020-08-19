//
//  AppKitBridging.h
//  DeltaMac
//
//  Created by Riley Testut on 8/12/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

#import <UIKit/UIKit.h>

#if TARGET_OS_MACCATALYST

NS_ASSUME_NONNULL_BEGIN

extern NSNotificationName DLTAWindowDidBecomeKeyNotification;
extern NSNotificationName DLTAWindowWillStartLiveResizeNotification;
extern NSNotificationName DLTAWindowDidEndLiveResizeNotification;

typedef NS_OPTIONS(NSUInteger, NSWindowProxyStyleMask) {
    NSWindowStyleMaskBorderless = 0,
    NSWindowProxyStyleMaskTitled = 1 << 0,
    NSWindowProxyStyleMaskClosable = 1 << 1,
    NSWindowProxyStyleMaskMiniaturizable = 1 << 2,
    NSWindowProxyStyleMaskResizable    = 1 << 3,
    
    /* Specifies a window with textured background. Textured windows generally don't draw a top border line under the titlebar/toolbar. To get that line, use the NSUnifiedTitleAndToolbarWindowMask mask.
     */
    NSWindowProxyStyleMaskTexturedBackground API_DEPRECATED("Textured window style should no longer be used", macos(10.2, 11.0)) = 1 << 8,
    
    /* Specifies a window whose titlebar and toolbar have a unified look - that is, a continuous background. Under the titlebar and toolbar a horizontal separator line will appear.
     */
    NSWindowProxyStyleMaskUnifiedTitleAndToolbar = 1 << 12,
    
    /* When set, the window will appear full screen. This mask is automatically toggled when toggleFullScreen: is called.
     */
    NSWindowProxyStyleMaskFullScreen API_AVAILABLE(macos(10.7)) = 1 << 14,
    
    /* If set, the contentView will consume the full size of the window; it can be combined with other window style masks, but is only respected for windows with a titlebar.
     Utilizing this mask opts-in to layer-backing. Utilize the contentLayoutRect or auto-layout contentLayoutGuide to layout views underneath the titlebar/toolbar area.
     */
    NSWindowProxyStyleMaskFullSizeContentView API_AVAILABLE(macos(10.10)) = 1 << 15,
    
    /* The following are only applicable for NSPanel (or a subclass thereof)
     */
    NSWindowProxyStyleMaskUtilityWindow            = 1 << 4,
    NSWindowProxyStyleMaskDocModalWindow         = 1 << 6,
    NSWindowProxyStyleMaskNonactivatingPanel        = 1 << 7, // Specifies that a panel that does not activate the owning application
    NSWindowProxyStyleMaskHUDWindow API_AVAILABLE(macos(10.6)) = 1 << 13 // Specifies a heads up display panel
};

@protocol NSWindowProxy <NSObject>

@property CGSize aspectRatio;
@property CGSize contentAspectRatio;
- (void)setContentSize:(CGSize)size;

@property CGRect frame;
- (void)setFrame:(CGRect)frameRect
         display:(BOOL)flag;

- (CGRect)contentRectForFrameRect:(CGRect)frameRect;
- (CGRect)frameRectForContentRect:(CGRect)contentRect;

@property NSWindowProxyStyleMask styleMask;

@end

@interface UIWindow (AppKitBridging)

- (NSToolbar *)windowScene;

@property (nonatomic, readonly, nullable) id<NSWindowProxy> nsWindow;

@end

NS_ASSUME_NONNULL_END

#endif
