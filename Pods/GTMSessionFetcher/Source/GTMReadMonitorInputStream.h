/* Copyright 2014 Google Inc. All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import <Foundation/Foundation.h>

// These will be removed in the near future, folks should move off of them.
#ifndef GTM_NONNULL
#if defined(__has_attribute)
#if __has_attribute(nonnull)
#define GTM_NONNULL(x) __attribute__((nonnull x))
#else
#define GTM_NONNULL(x)
#endif
#else
#define GTM_NONNULL(x)
#endif
#endif

NS_ASSUME_NONNULL_BEGIN

@interface GTMReadMonitorInputStream : NSInputStream <NSStreamDelegate>

+ (nonnull instancetype)inputStreamWithStream:(nonnull NSInputStream *)input;

- (nonnull instancetype)initWithStream:(nonnull NSInputStream *)input;

// The read monitor selector is called when bytes have been read. It should have this signature:
//
// - (void)inputStream:(GTMReadMonitorInputStream *)stream
//      readIntoBuffer:(uint8_t *)buffer
//              length:(int64_t)length;

@property(atomic, weak) id readDelegate;
@property(atomic) SEL readSelector;

// Modes for invoking callbacks, when necessary.
@property(atomic, copy, nullable) NSArray *runLoopModes;

@end

NS_ASSUME_NONNULL_END
