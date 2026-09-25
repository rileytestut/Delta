#import <Foundation/Foundation.h>
@import DeltaCore;

NS_ASSUME_NONNULL_BEGIN

@interface PS1EmulatorBridge : NSObject <DLTAEmulatorBridging>

@property (class, nonatomic, readonly) PS1EmulatorBridge *sharedBridge;

@end

NS_ASSUME_NONNULL_END
