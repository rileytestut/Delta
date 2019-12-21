//
//  VoucherClient.h
//  Voucher
//
//  Created by Rizwan Sattar on 11/7/15.
//  Copyright © 2015 Rizwan Sattar. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "VoucherStreamsController.h"

@class VoucherClient;
@protocol VoucherClientDelegate <NSObject>

@optional
- (void)voucherClient:(nonnull VoucherClient *)client didUpdateSearching:(BOOL)isSearching;
- (void)voucherClient:(nonnull VoucherClient *)client didUpdateConnectionToServer:(BOOL)isConnectedToServer serverName:(nullable NSString *)serverName;

@end


typedef void (^VoucherClientCompletionHandler)( NSData * _Nullable authData, NSString * _Nullable responderDisplayName, NSError * _Nullable error);

@interface VoucherClient : VoucherStreamsController

@property (weak, nonatomic) NSObject <VoucherClientDelegate> *delegate;

@property (readonly, copy, nonatomic, nonnull) NSString *displayName;
@property (readonly, copy, nonatomic, nonnull) NSString *uniqueSharedId;
@property (readonly, assign, nonatomic) BOOL isSearching;

- (nullable instancetype)init NS_UNAVAILABLE;
- (nonnull instancetype)initWithUniqueSharedId:(nonnull NSString *)uniqueSharedId displayName:(nullable NSString *)displayName NS_DESIGNATED_INITIALIZER;
- (nonnull instancetype)initWithUniqueSharedId:(nonnull NSString *)uniqueSharedId;

- (void)startSearchingWithCompletion:(nonnull VoucherClientCompletionHandler)completionHandler;
- (void)stop;

@end
