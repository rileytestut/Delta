//
//  VoucherServer.m
//  Voucher
//
//  Created by Rizwan Sattar on 11/7/15.
//  Copyright © 2015 Rizwan Sattar. All rights reserved.
//

#import "VoucherServer.h"
#import "VoucherCommon.h"

#import <UIKit/UIKit.h> // Just needed for deviceName

@interface VoucherServer () <NSNetServiceDelegate>

@property (copy, nonatomic) NSString *displayName;
@property (copy, nonatomic) NSString *uniqueSharedId;
@property (assign, nonatomic) BOOL isAdvertising;
@property (assign, nonatomic) BOOL shouldBeAdvertising;
@property (assign, nonatomic) BOOL isConnectedToClient;

// Advertising
@property (copy, nonatomic) VoucherServerRequestHandler requestHandler;
@property (strong, nonatomic) NSNetService *server;
@property (copy, nonatomic) NSString *registeredServerName;
@property (copy, nonatomic) NSString *serviceName;
@end

@implementation VoucherServer

- (instancetype)initWithUniqueSharedId:(NSString *)uniqueSharedId displayName:(NSString *)displayName
{
    self = [super init];
    if (self) {
        self.uniqueSharedId = uniqueSharedId;
        NSString *appString = [self.uniqueSharedId stringByReplacingOccurrencesOfString:@"." withString:@"_"];
        self.serviceName = [NSString stringWithFormat:kVoucherServiceNameFormat, appString];
        if (displayName.length == 0) {
            displayName = [UIDevice currentDevice].name;
        }
        self.displayName = displayName;
    }
    return self;
}

- (instancetype)initWithUniqueSharedId:(NSString *)uniqueSharedId
{
    return [self initWithUniqueSharedId:uniqueSharedId displayName:nil];
}

- (void)dealloc
{
    [self stop];
}

- (void)startAdvertisingWithRequestHandler:(VoucherServerRequestHandler)requestHandler
{
    if (self.server != nil) {
        [self stopAdvertising];
    }

    self.shouldBeAdvertising = YES;
    self.requestHandler = requestHandler;

    self.server = [[NSNetService alloc] initWithDomain:@"local"
                                                              type:self.serviceName
                                                              name:self.displayName];
    self.server.includesPeerToPeer = YES;
    self.server.delegate = self;
    [self.server publishWithOptions:NSNetServiceListenForConnections];

}

- (void)stop
{
    [self disconnectClient];
    [self stopAdvertising];
    self.requestHandler = nil;
}

- (void)stopAdvertising
{
    self.shouldBeAdvertising = NO;

    if (self.server != nil) {
        [self.server stop];
        self.server.delegate = nil;
        self.server = nil;
    }
    self.registeredServerName = nil;
    self.isAdvertising = NO;
}

- (void)disconnectClient
{
    [self closeStreams];
}

- (void)closeStreams
{
    [super closeStreams];
    self.isConnectedToClient = NO;
}

- (void)openStreams
{
    [super openStreams];
    self.isConnectedToClient = YES;
}


#pragma mark - Overall Events


- (void)handleReceivedData:(NSData *)data
{
    // We send/receive information as a NSDictionary written out
    // as NSData, so convert from NSData --> NSDictionary
    NSDictionary *dict = (NSDictionary *)[NSKeyedUnarchiver unarchiveObjectWithData:data];
    [self handleIncomingRequestDictionary:dict];
}


- (void)handleIncomingRequestDictionary:(NSDictionary *)requestDict
{
    NSLog(@"Received request: \n%@", requestDict);
    NSString *displayName = requestDict[@"displayName"];
    if (self.requestHandler) {
        __weak VoucherServer *_weakSelf = self;
        self.requestHandler(displayName, ^(NSData * authData, NSError * error) {

            NSAssert(error == nil, @"Error handling not yet implemented");

            NSDictionary *responseDict = nil;
            if (authData.length) {
                // App has granted us some data
                responseDict = @{@"authData" : authData, @"displayName" : _weakSelf.displayName};
            } else {
                // Don't send back any response data, except our display name
                responseDict = @{@"displayName" : _weakSelf.displayName};
            }
            NSData *responseData = [NSKeyedArchiver archivedDataWithRootObject:responseDict];
            [_weakSelf sendData:responseData];

        });
    }
}


- (void)handleStreamEnd:(NSStream *)stream
{
    [super handleStreamEnd:stream];

    NSLog(@"Encountered unexpected stream end on VoucherServer, restarting server");
    // An unexpected error occurred here, so
    // restart server (is this the right move here?)
    [self startAdvertisingWithRequestHandler:self.requestHandler];
}


#pragma mark - NSNetServiceDelegate


- (void)netServiceDidPublish:(NSNetService *)sender
{
    assert(sender == self.server);
    self.isAdvertising = YES;
    self.registeredServerName = self.server.name;
    NSLog(@"Advertising Voucher Server as: '%@'", self.registeredServerName);
}

- (void)netService:(NSNetService *)sender didAcceptConnectionWithInputStream:(NSInputStream *)inputStream outputStream:(NSOutputStream *)outputStream
{
    // Due to a bug <rdar://problem/15626440>, this method is called on some unspecified
    // queue rather than the queue associated with the net service (which in this case
    // is the main queue).  Work around this by bouncing to the main queue.
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        assert(sender == self.server);
#pragma unused(sender)
        assert(inputStream != nil);
        assert(outputStream != nil);

        assert( (self.inputStream != nil) == (self.outputStream != nil) );      // should either have both or neither

        if (self.inputStream != nil) {
            // We already have a connection, reject this one
            [inputStream open];
            [inputStream close];
            [outputStream open];
            [outputStream close];
        } else {

            // Latch the input and output sterams and kick off an open.

            self.inputStream  = inputStream;
            self.outputStream = outputStream;

            [self openStreams];
        }
    }];
}

- (void)netService:(NSNetService *)sender didNotPublish:(NSDictionary *)errorDict
// This is called when the server stops of its own accord.  The only reason
// that might happen is if the Bonjour registration fails when we reregister
// the server, and that's hard to trigger because we use auto-rename.  I've
// left an assert here so that, if this does happen, we can figure out why it
// happens and then decide how best to handle it.
{
    assert(sender == self.server);
    self.isAdvertising = NO;
    // This will also get called if, while the server is published, the app
    // (iOS) goes to the background, then comes back.
    // This fails with a NSNetServicesUnknownError (-72000). For Voucher,
    // we want to get the server back up and running, if we already thought
    // we were
#pragma unused(sender)
    NSNetServicesError errorCode = [errorDict[NSNetServicesErrorCode] integerValue];
    NSLog(@"Voucher Server stopped publishing, due to error: %ld", (long)errorCode);
    if (errorCode == NSNetServicesUnknownError) {
        if (self.shouldBeAdvertising) {
            NSLog(@"Restarting Voucher Server...");
            [self startAdvertisingWithRequestHandler:self.requestHandler];
        }
    }
}


#pragma mark - Setters

- (void)setIsAdvertising:(BOOL)isAdvertising
{
    if (_isAdvertising == isAdvertising) {
        return;
    }
    _isAdvertising = isAdvertising;
    if ([self.delegate respondsToSelector:@selector(voucherServer:didUpdateAdvertising:)]) {
        [self.delegate voucherServer:self didUpdateAdvertising:_isAdvertising];
    }
}

- (void)setIsConnectedToClient:(BOOL)isConnectedToClient
{
    if (_isConnectedToClient == isConnectedToClient) {
        return;
    }
    _isConnectedToClient = isConnectedToClient;
    if ([self.delegate respondsToSelector:@selector(voucherServer:didUpdateConnectionToClient:)]) {
        [self.delegate voucherServer:self didUpdateConnectionToClient:_isConnectedToClient];
    }
}
@end
