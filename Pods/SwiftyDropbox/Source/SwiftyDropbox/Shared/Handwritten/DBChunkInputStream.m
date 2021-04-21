///
/// Copyright (c) 2016 Dropbox, Inc. All rights reserved.
/// Copyright (c) 2011 BJ Homer. All rights reserved.
///
/// Based on example from @bjhomer https://github.com/bjhomer/HSCountingInputStream
///

#import "DBChunkInputStream.h"

@interface DBChunkInputStream ()

@property (nonatomic, readonly) NSInputStream * _Nonnull parentStream;
@property (nonatomic) NSStreamStatus parentStreamStatus;
@property (nonatomic, readonly) id<NSStreamDelegate> streamDelegate;

@property (nonatomic) CFReadStreamClientCallBack copiedCallback;
@property (nonatomic) CFStreamClientContext copiedContext;
@property (nonatomic) CFOptionFlags requestedEvents;

@property (nonatomic, readonly) NSUInteger startBytes;
@property (nonatomic, readonly) NSUInteger endBytes;
@property (nonatomic, readonly) NSUInteger totalBytesToRead;
@property (nonatomic) NSUInteger totalBytesRead;

@end

@implementation DBChunkInputStream

#pragma mark Object lifecycle

- (instancetype)initWithFileUrl:(NSURL *)fileUrl startBytes:(NSUInteger)startBytes endBytes:(NSUInteger)endBytes {
  self = [super init];
  if (self) {
    _parentStream = [[NSInputStream alloc] initWithURL:fileUrl];
    [_parentStream setDelegate:self];

    NSAssert(endBytes > startBytes, @"End location (%lu) needs to be greater than start location (%lu)",
             (unsigned long)endBytes, (unsigned long)startBytes);
    _startBytes = startBytes;
    _endBytes = endBytes;
    _totalBytesToRead = endBytes - startBytes;
    _totalBytesRead = 0;

    [self setDelegate:self];
  }

  return self;
}

#pragma mark NSStream subclass methods

- (void)open {
  [_parentStream open];
  [_parentStream setProperty:@(_startBytes) forKey:NSStreamFileCurrentOffsetKey];
  _parentStreamStatus = NSStreamStatusOpen;
}

- (void)close {
  [_parentStream close];
  _parentStreamStatus = NSStreamStatusClosed;
}

- (id<NSStreamDelegate>)delegate {
  return _streamDelegate;
}

- (void)setDelegate:(id<NSStreamDelegate>)aDelegate {
  if (!aDelegate) {
    _streamDelegate = self;
  } else {
    _streamDelegate = aDelegate;
  }
}

- (void)scheduleInRunLoop:(NSRunLoop *)aRunLoop forMode:(NSString *)mode {
  [_parentStream scheduleInRunLoop:aRunLoop forMode:mode];
}

- (void)removeFromRunLoop:(NSRunLoop *)aRunLoop forMode:(NSString *)mode {
  [_parentStream removeFromRunLoop:aRunLoop forMode:mode];
}

- (id)propertyForKey:(NSString *)key {
  return [_parentStream propertyForKey:key];
}

- (BOOL)setProperty:(id)property forKey:(NSString *)key {
  return [_parentStream setProperty:property forKey:key];
}

- (NSStreamStatus)streamStatus {
  return _parentStreamStatus;
}

- (NSError *)streamError {
  return [_parentStream streamError];
}

#pragma mark NSInputStream subclass methods

- (NSInteger)read:(uint8_t *)buffer maxLength:(NSUInteger)len {
  NSUInteger bytesToRead = len;

  NSUInteger bytesRemaining = _totalBytesToRead - _totalBytesRead;
  if (len > bytesRemaining) {
    bytesToRead = bytesRemaining;
  }

  NSInteger bytesRead = [_parentStream read:buffer maxLength:bytesToRead];

  _totalBytesRead += bytesRead;

  return bytesRead;
}

- (BOOL)getBuffer:(uint8_t **)buffer length:(NSUInteger *)len {
#pragma unused(buffer)
#pragma unused(len)
  return NO;
}

- (BOOL)hasBytesAvailable {
  NSUInteger bytesRemaining = _totalBytesToRead - _totalBytesRead;

  if (bytesRemaining == 0) {
    _parentStreamStatus = NSStreamStatusAtEnd;
    return NO;
  }

  return [_parentStream hasBytesAvailable];
}

#pragma mark Undocumented CFReadStream bridged methods

- (void)_scheduleInCFRunLoop:(CFRunLoopRef)aRunLoop forMode:(CFStringRef)aMode {
  CFReadStreamScheduleWithRunLoop((CFReadStreamRef)_parentStream, aRunLoop, aMode);
}

- (BOOL)_setCFClientFlags:(CFOptionFlags)inFlags
                 callback:(CFReadStreamClientCallBack)inCallback
                  context:(CFStreamClientContext *)inContext {

  if (inCallback) {
    _requestedEvents = inFlags;
    _copiedCallback = inCallback;
    memcpy(&_copiedContext, inContext, sizeof(CFStreamClientContext));

    if (_copiedContext.info && _copiedContext.retain) {
      _copiedContext.retain(_copiedContext.info);
    }
  } else {
    _requestedEvents = kCFStreamEventNone;
    _copiedCallback = nil;
    if (_copiedContext.info && _copiedContext.release) {
      _copiedContext.release(_copiedContext.info);
    }

    memset(&_copiedContext, 0, sizeof(CFStreamClientContext));
  }

  return YES;
}

- (void)_unscheduleFromCFRunLoop:(CFRunLoopRef)aRunLoop forMode:(CFStringRef)aMode {
  CFReadStreamUnscheduleFromRunLoop((CFReadStreamRef)_parentStream, aRunLoop, aMode);
}

#pragma mark NSStreamDelegate methods

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode {
#pragma unused(aStream)
  assert(aStream == _parentStream);

  switch (eventCode) {
  case NSStreamEventOpenCompleted:
    if (_requestedEvents & kCFStreamEventOpenCompleted) {
      _copiedCallback((__bridge CFReadStreamRef)self, kCFStreamEventOpenCompleted, _copiedContext.info);
    }
    break;

  case NSStreamEventHasBytesAvailable:
    if (_requestedEvents & kCFStreamEventHasBytesAvailable) {
      _copiedCallback((__bridge CFReadStreamRef)self, kCFStreamEventHasBytesAvailable, _copiedContext.info);
    }
    break;

  case NSStreamEventErrorOccurred:
    if (_requestedEvents & kCFStreamEventErrorOccurred) {
      _copiedCallback((__bridge CFReadStreamRef)self, kCFStreamEventErrorOccurred, _copiedContext.info);
    }
    break;

  case NSStreamEventEndEncountered:
    if (_requestedEvents & kCFStreamEventEndEncountered) {
      _copiedCallback((__bridge CFReadStreamRef)self, kCFStreamEventEndEncountered, _copiedContext.info);
    }
    break;

  case NSStreamEventHasSpaceAvailable:
    break;

  default:
    break;
  }
}

@end
