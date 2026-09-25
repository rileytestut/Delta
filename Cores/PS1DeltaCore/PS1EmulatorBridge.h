#import <Foundation/Foundation.h>
@import DeltaCore;

NS_ASSUME_NONNULL_BEGIN

@interface PS1EmulatorBridge : NSObject <DLTAEmulatorBridging>

@property (class, nonatomic, readonly) PS1EmulatorBridge *sharedBridge;
@property (nonatomic, readonly) NSArray<NSString *> *discLabels;
@property (nonatomic, readonly) NSInteger currentDiscIndex;

- (BOOL)swapToDiscAtIndex:(NSUInteger)index NS_SWIFT_NAME(swapToDisc(at:));

@end

NS_ASSUME_NONNULL_END
