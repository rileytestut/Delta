//
//  VoucherClient.m
//  Voucher
//
//  Created by Rizwan Sattar on 11/7/15.
//  Copyright © 2015 Rizwan Sattar. All rights reserved.
//

#import "VoucherClient.h"
#import "VoucherCommon.h"

#import <UIKit/UIKit.h> // Just needed for deviceName

@interface VoucherClient () <NSNetServiceBrowserDelegate, NSNetServiceDelegate, NSStreamDelegate>

@property (copy, nonatomic) NSString *displayName;
@property (copy, nonatomic) NSString *uniqueSharedId;
@property (assign, nonatomic) BOOL isSearching;
@property (assign, nonatomic) BOOL isConnectedToServer;

@property (copy, nonatomic) VoucherClientCompletionHandler completionHandler;

// Browsing
@property (strong, nonatomic) NSNetServiceBrowser *browser;
@property (copy, nonatomic) NSString *serviceName;
@property (strong, nonatomic) NSMutableArray <NSNetService *> *currentlyAvailableServices;

@property (strong, nonatomic) NSNetService *server;

@end

@implementation VoucherClient

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

- (void)startSearchingWithCompletion:(VoucherClientCompletionHandler)completionHandler
{
    if (self.isSearching) {
        [self stopSearching];
    }

    self.currentlyAvailableServices = [NSMutableArray arrayWithCapacity:2];

    self.completionHandler = completionHandler;

    self.browser = [[NSNetServiceBrowser alloc] init];
    self.browser.includesPeerToPeer = YES;
    self.browser.delegate = self;
    [self.browser searchForServicesOfType:self.serviceName inDomain:@"local"];
}

- (void)stop
{
    [self disconnectFromServer];
    [self stopSearching];
    self.completionHandler = nil;
}

- (void)stopSearching
{
    [self.currentlyAvailableServices removeAllObjects];

    [self.browser stop];
    self.browser.delegate = nil;
    self.browser = nil;
}


#pragma mark - Services

- (void)connectToAvailableServer
{
    if (!self.isConnectedToServer && self.currentlyAvailableServices.count > 0) {
        NSNetService *service = self.currentlyAvailableServices[0];
        [self connectToServer:service];
    } else {
        NSLog(@"No available server to connect to, yet.");
    }
}

- (void)connectToServer:(NSNetService *)service
{
    NSAssert(self.currentlyAvailableServices.count > 0,
             @"Tried to select a service when none were available");
    if (service == nil) {
        service = self.currentlyAvailableServices[0];
    }
    NSAssert([self.currentlyAvailableServices containsObject:service],
             @"Tried to select a service which we don't know about");

    self.server = service;
    self.server.delegate = self;

    NSInputStream *inputStream;
    NSOutputStream *outputStream;

    BOOL success = [self.server getInputStream:&inputStream outputStream:&outputStream];
    if (success) {
        self.isConnectedToServer = YES;
        self.inputStream = inputStream;
        self.outputStream = outputStream;

        [self openStreams];

        [self sendAuthRequest];
    }
}

- (void)disconnectFromServer
{
    [self closeStreams];
    self.server.delegate = nil;
    self.server = nil;
    self.isConnectedToServer = NO;
}

- (void)handleStreamEnd:(NSStream *)stream
{
    // On an unexpected ending of the stream, disconnect
    // and try and find the next available server (if any)
    [super handleStreamEnd:stream];
    [self disconnectFromServer];
    [self connectToAvailableServer];
    
}

- (void)sendAuthRequest
{
    NSDictionary *requestDict = @{@"displayName" : self.displayName};
    NSData *requestData = [NSKeyedArchiver archivedDataWithRootObject:requestDict];
    [self sendData:requestData];
}


- (void)handleReceivedData:(NSData *)data
{
    [super handleReceivedData:data];
    NSDictionary *responseDict = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    NSData *authData = responseDict[@"authData"];
    NSString *responderDisplayName = responseDict[@"displayName"];
    if (self.completionHandler) {
        self.completionHandler(authData, responderDisplayName, nil);
    }
    [self stop];
}

#pragma mark - NSNetServiceBrowserDelegate

/* Sent to the NSNetServiceBrowser instance's delegate before the instance begins a search. The delegate will not receive this message if the instance is unable to begin a search. Instead, the delegate will receive the -netServiceBrowser:didNotSearch: message.
 */
- (void)netServiceBrowserWillSearch:(NSNetServiceBrowser *)browser
{
    NSLog(@"Browser will search");
    self.isSearching = YES;
}

/* Sent to the NSNetServiceBrowser instance's delegate when the instance's previous running search request has stopped.
 */
- (void)netServiceBrowserDidStopSearch:(NSNetServiceBrowser *)browser
{
    NSLog(@"Browser did stop search");
    self.isSearching = NO;
}

/* Sent to the NSNetServiceBrowser instance's delegate when an error in searching for domains or services has occurred. The error dictionary will contain two key/value pairs representing the error domain and code (see the NSNetServicesError enumeration above for error code constants). It is possible for an error to occur after a search has been started successfully.
 */
- (void)netServiceBrowser:(NSNetServiceBrowser *)browser didNotSearch:(NSDictionary<NSString *, NSNumber *> *)errorDict
{
    NSLog(@"\nBrowser did not search:");
    for (NSString *errorDomain in errorDict) {
        NSNumber *errorCode = errorDict[errorDomain];
        NSLog(@"    '%@': %@", errorDomain, errorCode);
    }
    self.isSearching = NO;
}

/* Sent to the NSNetServiceBrowser instance's delegate for each domain discovered. If there are more domains, moreComing will be YES. If for some reason handling discovered domains requires significant processing, accumulating domains until moreComing is NO and then doing the processing in bulk fashion may be desirable.
 */
- (void)netServiceBrowser:(NSNetServiceBrowser *)browser didFindDomain:(NSString *)domainString moreComing:(BOOL)moreComing
{
    NSLog(@"Browser found domain: %@, more coming: %@", domainString, (moreComing ? @"YES" : @"NO"));
}

/* Sent to the NSNetServiceBrowser instance's delegate for each service discovered. If there are more services, moreComing will be YES. If for some reason handling discovered services requires significant processing, accumulating services until moreComing is NO and then doing the processing in bulk fashion may be desirable.
 */
- (void)netServiceBrowser:(NSNetServiceBrowser *)browser didFindService:(NSNetService *)service moreComing:(BOOL)moreComing
{
    NSLog(@"Browser found service: %@, more coming: %@", service.name, (moreComing ? @"YES" : @"NO"));
    if (![self.currentlyAvailableServices containsObject:service]) {
        [self.currentlyAvailableServices addObject:service];
    }
    [self connectToAvailableServer];
}

/* Sent to the NSNetServiceBrowser instance's delegate when a previously discovered domain is no longer available.
 */
- (void)netServiceBrowser:(NSNetServiceBrowser *)browser didRemoveDomain:(NSString *)domainString moreComing:(BOOL)moreComing
{
    NSLog(@"Browser removed domain: %@, more coming: %@", domainString, (moreComing ? @"YES" : @"NO"));
}

/* Sent to the NSNetServiceBrowser instance's delegate when a previously discovered service is no longer published.
 */
- (void)netServiceBrowser:(NSNetServiceBrowser *)browser didRemoveService:(NSNetService *)service moreComing:(BOOL)moreComing
{
    NSLog(@"Browser removed service: %@, more coming: %@", service.name, (moreComing ? @"YES" : @"NO"));
    if ([self.currentlyAvailableServices containsObject:service]) {
        [self.currentlyAvailableServices removeObject:service];
    }
    if (!moreComing) {
        // No more to remove, now check if our server is one of them, and if so, disconnect, and go back to searching
        if (self.server && ![self.currentlyAvailableServices containsObject:self.server]) {
            [self disconnectFromServer];
            // Connect to next server, if one is available
            [self connectToAvailableServer];
        }
    }
}

#pragma mark - Setters

- (void)setIsSearching:(BOOL)isSearching
{
    if (_isSearching == isSearching) {
        return;
    }
    _isSearching = isSearching;
    if ([self.delegate respondsToSelector:@selector(voucherClient:didUpdateSearching:)]) {
        [self.delegate voucherClient:self didUpdateSearching:_isSearching];
    }
}

- (void)setIsConnectedToServer:(BOOL)isConnectedToServer
{
    if (_isConnectedToServer == isConnectedToServer) {
        return;
    }
    _isConnectedToServer = isConnectedToServer;
    if ([self.delegate respondsToSelector:@selector(voucherClient:didUpdateConnectionToServer:serverName:)]) {
        [self.delegate voucherClient:self didUpdateConnectionToServer:_isConnectedToServer serverName:self.server.name];
    }
}

@end
