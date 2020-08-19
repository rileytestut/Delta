//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//

#import "ControllerSkinConfigurations.h"

#import "AppKitBridging.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSExtension : NSObject

+ (instancetype)extensionWithIdentifier:(NSString *)identifier error:(NSError *_Nullable *)error;
+ (void)extensionWithURL:(NSURL *)url completion:(void (^)(NSExtension *_Nullable extension, NSError *_Nullable error))completionBlock;

- (void)beginExtensionRequestWithInputItems:(NSArray *)inputItems completion:(void (^)(NSUUID *requestIdentifier))completion;

- (int)pidForRequestIdentifier:(NSUUID *)requestIdentifier;
- (void)cancelExtensionRequestWithIdentifier:(NSUUID *)requestIdentifier;

- (void)setRequestCancellationBlock:(void (^)(NSUUID *uuid, NSError *error))cancellationBlock;
- (void)setRequestCompletionBlock:(void (^)(NSUUID *uuid, NSArray *extensionItems))completionBlock;
- (void)setRequestInterruptionBlock:(void (^)(NSUUID *uuid))interruptionBlock;

@property (nonatomic,retain) NSMutableDictionary<NSUUID *, NSXPCConnection *> * _extensionServiceConnections;
@property (nonatomic,copy) NSSet * _allowedErrorClasses;
@property (nonatomic,retain) NSMutableDictionary * _extensionContexts;

@end

NS_ASSUME_NONNULL_END
