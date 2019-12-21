//
//  VoucherStreamsController.h
//  Voucher
//
//  Created by Rizwan Sattar on 11/7/15.
//  Copyright © 2015 Rizwan Sattar. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface VoucherStreamsController : NSObject

@property (strong, nonatomic, nullable) NSInputStream *inputStream;
@property (strong, nonatomic, nullable) NSOutputStream *outputStream;
@property (assign, nonatomic) NSUInteger streamOpenCount;

- (void)openStreams;
- (void)closeStreams;

- (void)sendData:(nonnull NSData *)data;
- (void)handleReceivedData:(nonnull NSData *)data;

- (void)handleStreamEnd:(nonnull NSStream *)stream;

@end
