//
//  InputStreamOutputWriter.swift
//  Delta
//
//  Created by Riley Testut on 12/25/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import Foundation

private let MaximumBufferLength = 4 * 1024 // 4 KB

class InputStreamOutputWriter: NSObject
{
    let inputStream: InputStream
    let outputStream: OutputStream
    
    fileprivate var completion: ((Error?) -> Void)?
    
    fileprivate var dataBuffer = Data(capacity: MaximumBufferLength * 2)
    
    init(inputStream: InputStream, outputStream: OutputStream)
    {
        self.inputStream = inputStream
        self.outputStream = outputStream
        
        super.init()
        
        self.inputStream.delegate = self
        self.outputStream.delegate = self
    }
    
    func start(with completion: @escaping ((Error?) -> Void))
    {
        guard self.completion == nil else { return }
        
        self.completion = completion
        
        let writingQueue = DispatchQueue(label: "com.rileytestut.InputStreamOutputWriter.writingQueue", qos: .userInitiated)
        writingQueue.async {
            self.inputStream.schedule(in: .current, forMode: .defaultRunLoopMode)
            self.outputStream.schedule(in: .current, forMode: .defaultRunLoopMode)
            
            self.outputStream.open()
            self.inputStream.open()
            
            RunLoop.current.run()
        }
    }
}

private extension InputStreamOutputWriter
{
    func writeDataBuffer()
    {
        while self.outputStream.hasSpaceAvailable && self.dataBuffer.count > 0
        {
            self.dataBuffer.withUnsafeMutableBytes { (buffer: UnsafeMutablePointer<UInt8>) -> Void in
                let writtenBytesCount = self.outputStream.write(buffer, maxLength: self.dataBuffer.count)
                if writtenBytesCount >= 0
                {
                    self.dataBuffer.removeSubrange(0 ..< writtenBytesCount)
                }
            }
        }
    }
    
    func finishWriting()
    {
        self.inputStream.close()
        self.outputStream.close()
        
        self.inputStream.remove(from: .current, forMode: .commonModes)
        self.outputStream.remove(from: .current, forMode: .commonModes)
        
        self.completion?(self.inputStream.streamError ?? self.outputStream.streamError)
        
        CFRunLoopStop(CFRunLoopGetCurrent())
    }
}

extension InputStreamOutputWriter: StreamDelegate
{
    func stream(_ aStream: Stream, handle eventCode: Stream.Event)
    {
        if let inputStream = aStream as? InputStream
        {
            self.inputStream(inputStream, handle: eventCode)
        }
        else if let outputStream = aStream as? OutputStream
        {
            self.outputStream(outputStream, handle: eventCode)
        }
    }
    
    private func inputStream(_ inputStream: InputStream, handle eventCode: Stream.Event)
    {
        switch eventCode
        {
        case Stream.Event.hasBytesAvailable:
            
            guard inputStream.streamError == nil else { return }
            
            while inputStream.hasBytesAvailable
            {
                let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: MaximumBufferLength)
                
                let readBytesCount = inputStream.read(buffer, maxLength: MaximumBufferLength)
                
                guard readBytesCount >= 0 else { break }
                
                self.dataBuffer.append(buffer, count: readBytesCount)
                
                buffer.deallocate(capacity: MaximumBufferLength)
                
                self.writeDataBuffer()
            }
            
        case Stream.Event.endEncountered:
            if self.dataBuffer.count == 0
            {
                self.finishWriting()
            }
            
        case Stream.Event.errorOccurred: self.finishWriting()
            
        default: break
        }
    }
    
    private func outputStream(_ outputStream: OutputStream, handle eventCode: Stream.Event)
    {
        switch eventCode
        {
        case Stream.Event.hasSpaceAvailable:
            self.writeDataBuffer()
            
            if self.inputStream.streamStatus == .atEnd
            {
                self.finishWriting()
            }
            
        case Stream.Event.errorOccurred: self.finishWriting()
            
        default: break
        }
    }
}
