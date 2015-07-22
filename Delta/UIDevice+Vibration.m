//
//  UIDevice+Vibration.m
//  Delta
//
//  Created by Riley Testut on 7/5/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

#import "UIDevice+Vibration.h"

#include <sys/sysctl.h>

@import AudioToolbox;

// Private vibration API declarations
#if !APP_STORE_BUILD
void AudioServicesStopSystemSound(int);
void AudioServicesPlaySystemSoundWithVibration(int, id, NSDictionary *);
#endif

@implementation UIDevice (Vibration)

#pragma mark - Vibration -

- (void)vibrate
{
#if !APP_STORE_BUILD
    AudioServicesStopSystemSound(kSystemSoundID_Vibrate);
    
    int64_t vibrationLength = 30;
    
    if ([[self modelGeneration] hasPrefix:@"iPhone6"])
    {
        // iPhone 5S has a weaker vibration motor, so we vibrate for 10ms longer to compensate
        vibrationLength = 40;
    }
    
    NSArray *pattern = @[@NO, @0, @YES, @(vibrationLength)];
    
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    dictionary[@"VibePattern"] = pattern;
    dictionary[@"Intensity"] = @1;
    
    AudioServicesPlaySystemSoundWithVibration(kSystemSoundID_Vibrate, nil, dictionary);
#endif
}

#pragma mark - Device Info -

- (NSString *)modelGeneration
{
    char *type = "hw.machine";
    
    size_t size;
    sysctlbyname(type, NULL, &size, NULL, 0);
    
    char *name = malloc(size);
    sysctlbyname(type, name, &size, NULL, 0);
    
    NSString *modelName = [NSString stringWithCString:name encoding:NSUTF8StringEncoding];
    free(name);
    
    return modelName;
}

#pragma mark - Getters/Setters -

- (BOOL)isVibrationSupported
{
#if APP_STORE_BUILD || TARGET_IPHONE_SIMULATOR
    return NO;
#else
    // No way to detect if hardware supports vibration, so we assume if it's not an iPhone, it doesn't have a vibration motor
    return [self.model hasPrefix:@"iPhone"];
#endif
}

@end
