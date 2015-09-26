//
//  UIDevice+Vibration.h
//  Delta
//
//  Created by Riley Testut on 7/5/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

@import UIKit;

NS_ASSUME_NONNULL_BEGIN

@interface UIDevice (Vibration)

@property (nonatomic, readonly, getter=isVibrationSupported) BOOL supportsVibration;

- (void)vibrate;

@end

NS_ASSUME_NONNULL_END
