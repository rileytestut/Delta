//
//  VoucherStreamsController.m
//  Voucher
//
//  Created by Rizwan Sattar on 11/7/15.
//  Copyright © 2015 Rizwan Sattar. All rights reserved.
//

#import <Voucher/VoucherStreamsController.h>

static NSUInteger const BUFFER_SIZE = 1024;

@interface VoucherStreamsController () <NSStreamDelegate>

@property (strong, nonatomic) NSMutableData *dataReadBuffer;
@property (assign, nonatomic) int64_t expectedReadLength;
@property (strong, nonatomic) NSMutableData *dataSendBuffer;
@property (assign, nonatomic) NSUInteger sendBufferByteIndex;

@end

@implementation VoucherStreamsController


- (void) dealloc
{
    [self closeStreams];
    self.dataSendBuffer = nil;
    self.dataReadBuffer = nil;
}


#pragma mark - Overall Events

- (void)sendData:(nonnull NSData *)data
{
    // TODO(Riz): Queue up multiple sendData: requests,
    // so they don't stomp on each other
    self.dataSendBuffer = [NSMutableData dataWithCapacity:8+data.length];
    // First, append the length of the data, as a long
    uint64_t lengthPreamble = htonll((uint64_t)data.length);
    [self.dataSendBuffer appendBytes:&lengthPreamble length:sizeof(lengthPreamble)];
    // Then append the actual data
    [self.dataSendBuffer appendData:data];
    self.sendBufferByteIndex = 0;
    if (self.outputStream.hasSpaceAvailable) {
        [self flushSendDataIfAvailable];
    }
}


- (void)handleReceivedData:(nonnull NSData *)data
{
    NSLog(@"Received data of length: %lu", (unsigned long) data.length);
}


- (void)handleStreamEnd:(NSStream *)stream
{
    [self closeStreams];
}


- (void)openStreams
{
    // streams must exist but aren't open
    assert(self.inputStream != nil);
    assert(self.outputStream != nil);
    assert(self.streamOpenCount == 0);

    self.inputStream.delegate = self;
    [self.inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [self.inputStream open];

    self.outputStream.delegate = self;
    [self.outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [self.outputStream open];
}

- (void)closeStreams
{
    // should either have both or neither
    assert( (self.inputStream != nil) == (self.outputStream != nil) );

    if (self.inputStream != nil) {
        [self.inputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [self.inputStream close];
        self.inputStream = nil;

        [self.outputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [self.outputStream close];
        self.outputStream = nil;
    }
    self.streamOpenCount = 0;
}

- (void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)eventCode
{

#pragma unused(stream)

    switch(eventCode) {

        case NSStreamEventOpenCompleted: {
            self.streamOpenCount += 1;
            assert(self.streamOpenCount <= 2);

            if (stream == self.inputStream) {
                NSLog(@"Input stream open");
            } else if (stream == self.outputStream) {
                NSLog(@"Output stream open");
            }

            if (self.streamOpenCount == 2) {
                // Both input and output streams are open,
                // Now wait for inputStream to give us the
                // client's request (as a NSData(NSDictionary))
            }
        } break;

        case NSStreamEventHasSpaceAvailable: {
            assert(stream == self.outputStream);
            NSLog(@"Output stream has space available");
            [self flushSendDataIfAvailable];
        } break;

        case NSStreamEventHasBytesAvailable: {
            if (!self.dataReadBuffer) {
                self.dataReadBuffer = [NSMutableData data];
                self.expectedReadLength = -1;
            }

            assert(stream == self.inputStream);

            while (self.inputStream.hasBytesAvailable) {
                if (self.expectedReadLength < 0) {
                    // We haven't read anything yet, so just read the length preamble
                    NSUInteger numPreambleBytes = sizeof(uint64_t);
                    uint8_t buffer[numPreambleBytes];
                    NSInteger bytesRead = [self.inputStream read:buffer maxLength:numPreambleBytes];
                    if (bytesRead == numPreambleBytes) {
                        uint64_t contentLength;
                        memcpy(&contentLength, buffer, numPreambleBytes);
                        NTOHLL(contentLength);
                        self.expectedReadLength = contentLength;
                    }
                } else {
                    // We already know our expected size, so start or continue reading

                    uint8_t buffer[BUFFER_SIZE];

                    NSInteger bytesRead = [self.inputStream read:buffer maxLength:BUFFER_SIZE];
                    if (bytesRead < 0) {
                        NSLog(@"bytesRead: %ld", (long)bytesRead);
                        // Handle read errors in NSStreamEventErrorOccurred
                    } else if (bytesRead > 0) {
                        // We received some data.
                        NSLog(@"Received %ld bytes", (long)bytesRead);
                        [self.dataReadBuffer appendBytes:buffer length:bytesRead];
                        if (self.dataReadBuffer.length >= self.expectedReadLength) {
                            NSLog(@"Finished receiving bytes");
                            // End of buffer was reached. Do something about it?
                            [self handleReceivedData:[self.dataReadBuffer copy]];
                            self.dataReadBuffer = nil;
                            self.expectedReadLength = -1;
                        }
                    } else {
                        NSLog(@"Read zero bytes from input stream. The end is nigh");
                    }
                }
            }
        } break;

        default:
            assert(NO);
            // fall through
        case NSStreamEventErrorOccurred:
            // fall through
            NSLog(@"NSStreamErrorOccurred (fallthrough)");
        case NSStreamEventEndEncountered: {
            // Start server again?
            NSLog(@"NSStreamEventEndEncountered");
            if (stream == self.inputStream) {
                NSLog(@"   => Input Stream");
            } else if (stream == self.outputStream) {
                NSLog(@"   => Output Stream");
            }
            [self handleStreamEnd:stream];
        } break;
    }
}


- (void) flushSendDataIfAvailable
{
    if (self.dataSendBuffer.length <= 0) {
        return;
    }
    // Send any data in our write buffer
    uint8_t *readBytes = (uint8_t *) [self.dataSendBuffer mutableBytes];
    // Move along the byte array up to the sent index
    readBytes += self.sendBufferByteIndex;
    NSUInteger bytesToWrite = MIN(BUFFER_SIZE, self.dataSendBuffer.length - self.sendBufferByteIndex);

    uint8_t buffer[BUFFER_SIZE];
    // Copy the data we want to send over to this buffer
    (void)memcpy(buffer, readBytes, bytesToWrite);

    NSInteger bytesWritten = [self.outputStream write:buffer maxLength:bytesToWrite];
    if (bytesWritten < 0) {
        // Some error occurred, yikes. Handle write errors in NSStreamEventErrorOccurred
        NSLog(@"Couldn't write to output stream");
    } else {
        NSLog(@"Sent %ld bytes", (long) bytesWritten);
        self.sendBufferByteIndex += bytesWritten;

        if (self.sendBufferByteIndex == self.dataSendBuffer.length) {
            NSLog(@"Finished sending whole data buffer");
            self.dataSendBuffer = nil;
            self.sendBufferByteIndex = 0;
        }
    }
}

@end
