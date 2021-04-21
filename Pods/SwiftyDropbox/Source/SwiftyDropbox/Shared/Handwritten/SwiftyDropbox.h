//
//  SwiftyDropbox.h
//  SwiftyDropbox
//
//  Copyright © 2016 Dropbox. All rights reserved.
//

#import "TargetConditionals.h"

#if TARGET_OS_IPHONE
  #import <UIKit/UIKit.h>
#else
  #import <Cocoa/Cocoa.h>
#endif

//! Project version number for SwiftyDropbox.
FOUNDATION_EXPORT double SwiftyDropboxVersionNumber;

//! Project version string for SwiftyDropbox.
FOUNDATION_EXPORT const unsigned char SwiftyDropboxVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <SwiftyDropbox/PublicHeader.h

#import "DBChunkInputStream.h"
