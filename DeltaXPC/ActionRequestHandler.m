//
//  ActionRequestHandler.m
//  DeltaXPCExtension
//
//  Created by Riley Testut on 7/9/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

#import "ActionRequestHandler.h"
#import <MobileCoreServices/MobileCoreServices.h>

#import "DeltaXPC-Swift.h"

@import DeltaCore;
@import GBADeltaCore;

@interface ActionRequestHandler ()

@property (nonatomic, strong) NSExtensionContext *extensionContext;
@property (nonatomic, strong) NSXPCConnection *emulationConnection;

@end

@implementation ActionRequestHandler

- (void)beginRequestWithExtensionContext:(NSExtensionContext *)context {
    // Do not call super in an Action extension with no user interface
    self.extensionContext = context;
    
    BOOL found = NO;
    
    // Find the item containing the results from the JavaScript preprocessing.
    for (NSExtensionItem *item in self.extensionContext.inputItems) {
        for (NSItemProvider *itemProvider in item.attachments) {
            if ([itemProvider hasItemConformingToTypeIdentifier:(NSString *)kUTTypePropertyList])
            {
                [itemProvider loadItemForTypeIdentifier:(NSString *)kUTTypePropertyList options:nil completionHandler:^(NSDictionary *request, NSError *error) {
                    NSLog(@"Received request: %@", request);
                    
                    GameType gameType = request[@"gameType"];
                    
                    ListenerEndpoint *provider = (ListenerEndpoint *)request[@"endpoint"];
                    [self connectToEndpoint:provider.endpoint gameType:gameType];
//
//                    [self finishRequest];
//                    NSXPCListener *listener = [NSXPCListener anonymousListener];
//                    NSXPCListenerEndpoint *endpoint = listener.endpoint;
//
//                    NSItemProvider *resultsProvider = [[NSItemProvider alloc] initWithItem:@"Hello" typeIdentifier:(NSString *)kUTTypeText];
//
//                    NSExtensionItem *resultsItem = [[NSExtensionItem alloc] init];
//                    resultsItem.attachments = @[resultsProvider];
//                    [self.extensionContext completeRequestReturningItems:@[resultsItem] completionHandler:nil];
                }];

                break;
            }
        }
    }
//
////            if ([itemProvider hasItemConformingToTypeIdentifier:(NSString *)kUTTypePropertyList]) {
////                [itemProvider loadItemForTypeIdentifier:(NSString *)kUTTypePropertyList options:nil completionHandler:^(NSDictionary *dictionary, NSError *error) {
////                    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
////                        [self itemLoadCompletedWithPreprocessingResults:dictionary[NSExtensionJavaScriptPreprocessingResultsKey]];
////                    }];
////                }];
////                found = YES;
////            }
////            break;
//        }
//        if (found) {
//            break;
//        }
//    }
    
//    if (!found) {
//        // We did not find anything
//        [self doneWithResults:nil];
//    }
}

- (void)connectToEndpoint:(NSXPCListenerEndpoint *)endpoint gameType:(GameType)gameType
{
    NSXPCConnection *connection = [[NSXPCConnection alloc] initWithListenerEndpoint:endpoint];
    self.emulationConnection = connection;
    
//    let remoteInterface = NSXPCInterface(with: EmulatorBridging.self)
//    remoteInterface.setInterface(NSXPCInterface(with: AudioRendering.self), for: #selector(setter: EmulatorBridging.audioRenderer), argumentIndex: 0, ofReply: false)
    
    NSXPCInterface *exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(DLTAEmulatorBridging)];
    [exportedInterface setInterface:[NSXPCInterface interfaceWithProtocol:@protocol(DLTAAudioRendering)] forSelector:@selector(setAudioRenderer:) argumentIndex:0 ofReply:NO];
    [exportedInterface setInterface:[NSXPCInterface interfaceWithProtocol:@protocol(DLTAVideoRendering)] forSelector:@selector(setVideoRenderer:) argumentIndex:0 ofReply:NO];
    connection.exportedInterface = exportedInterface;
    
    id<DLTAEmulatorBridging> emulatorBridge = nil;
    
//    if ([gameType isEqualToString:@"])
    
    connection.exportedObject = [GBAEmulatorBridge sharedBridge];
    
    connection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(RemoteProcessProtocol)];
    
    [connection resume];
    
    id proxy = [connection remoteObjectProxyWithErrorHandler:^(NSError * _Nonnull error) {
        NSLog(@"Proxy error: %@", error);
    }];
    
    NSLog(@"Proxy: %@", proxy);
//    [proxy testMyFunction];
//    [proxy test];
}

- (void)finishRequest
{
    NSString *returnString = [NSString stringWithFormat:@"Extension: TEST"];
    
    NSXPCListener *listener = [NSXPCListener anonymousListener];
    NSXPCListenerEndpoint *endpoint = listener.endpoint;
    
    XPCContainer *container = [[XPCContainer alloc] initWithName:@"TESTCONTAINER1" endpoint:endpoint];
    
    
    NSDictionary *returnDictionary = @{@"string": returnString, @"endpoint": container};
    
    NSExtensionItem *returnItem = [[NSExtensionItem alloc] init];
    
    
    
    NSItemProvider *itemProvider = [[NSItemProvider alloc] initWithItem:returnDictionary typeIdentifier:(NSString *)kUTTypePropertyList];
    
//    NSItemProvider *itemProvider = [[NSItemProvider alloc] initWithItem:returnString typeIdentifier:kUTTypeText];
    [returnItem setAttachments:@[itemProvider]];
    
    [self.extensionContext completeRequestReturningItems:@[returnItem] completionHandler:^(BOOL expired) {
        NSLog(@"Expired: %@", @(expired));
    }];
}

- (void)itemLoadCompletedWithPreprocessingResults:(NSDictionary *)javaScriptPreprocessingResults {
    // Here, do something, potentially asynchronously, with the preprocessing
    // results.
    
    // In this very simple example, the JavaScript will have passed us the
    // current background color style, if there is one. We will construct a
    // dictionary to send back with a desired new background color style.
    if ([javaScriptPreprocessingResults[@"currentBackgroundColor"] length] == 0) {
        // No specific background color? Request setting the background to red.
        [self doneWithResults:@{ @"newBackgroundColor": @"red" }];
    } else {
        // Specific background color is set? Request replacing it with green.
        [self doneWithResults:@{ @"newBackgroundColor": @"green" }];
    }
}

- (void)doneWithResults:(NSDictionary *)resultsForJavaScriptFinalize {
    if (resultsForJavaScriptFinalize) {
        // Construct an NSExtensionItem of the appropriate type to return our
        // results dictionary in.
        
        // These will be used as the arguments to the JavaScript finalize()
        // method.
        
        NSDictionary *resultsDictionary = @{ NSExtensionJavaScriptFinalizeArgumentKey: resultsForJavaScriptFinalize };
        
        NSItemProvider *resultsProvider = [[NSItemProvider alloc] initWithItem:resultsDictionary typeIdentifier:(NSString *)kUTTypePropertyList];
        
        NSExtensionItem *resultsItem = [[NSExtensionItem alloc] init];
        resultsItem.attachments = @[resultsProvider];
        
        // Signal that we're complete, returning our results.
        [self.extensionContext completeRequestReturningItems:@[resultsItem] completionHandler:nil];
    } else {
        // We still need to signal that we're done even if we have nothing to
        // pass back.
        [self.extensionContext completeRequestReturningItems:@[] completionHandler:nil];
    }
    
    // Don't hold on to this after we finished with it.
    self.extensionContext = nil;
}

@end
