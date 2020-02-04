///
/// Copyright (c) 2016 Dropbox, Inc. All rights reserved.
/// Copyright (c) 2011 BJ Homer. All rights reserved.
///
/// Based on example from @bjhomer https://github.com/bjhomer/HSCountingInputStream
///

#import <Foundation/Foundation.h>

///
/// Subclass of `NSInputStream` to enforce "bounds" on file stream, for
/// chunk uploading.
///
@interface DBChunkInputStream : NSInputStream <NSStreamDelegate>

///
/// DBChunkInputStream full constructor.
///
/// @param fileUrl The file to stream.
/// @param startBytes The starting position of the file stream, relative
/// to the beginning of the file.
/// @param endBytes The ending position of the file stream, relative
/// to the beginning of the file.
///
/// @return An initialized DBChunkInputStream instance.
///
- (nonnull instancetype)initWithFileUrl:(NSURL * _Nonnull)fileUrl
                             startBytes:(NSUInteger)startBytes
                               endBytes:(NSUInteger)endBytes;

@end
