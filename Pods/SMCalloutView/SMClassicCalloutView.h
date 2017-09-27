#import <UIKit/UIKit.h>
#import "SMCalloutView.h"

/*
 
 SMClassicCalloutView
 --------------------
 Created by Nick Farina (nfarina@gmail.com)
 Version 1.1
 
 */

@protocol SMCalloutViewDelegate;
@class SMCalloutBackgroundView;

//
// Classic Callout view.
//

@interface SMClassicCalloutView : SMCalloutView

// One thing to note about the classic callout is that it will ignore the "constrainedInsets" property. That property is designed for iOS-7
// style presentation where your target view surface may be operlapped by navigation bars, tab bars, etc.

@end

//
// Classes responsible for drawing the background graphic with the pointy arrow.
//

// Draws a background composed of stretched prerendered images that you can customize. Uses the embedded iOS 6 graphics by default.
@interface SMCalloutImageBackgroundView : SMCalloutBackgroundView
@property (nonatomic, strong) UIImage *leftCapImage, *rightCapImage, *topAnchorImage, *bottomAnchorImage, *backgroundImage;
@end

// Draws a custom background matching the system background but can grow in height.
@interface SMCalloutDrawnBackgroundView : SMCalloutBackgroundView
@end

