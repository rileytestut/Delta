//
//  Stream+Conveniences.swift
//  Delta
//
//  Created by Riley Testut on 6/3/24.
//  Copyright © 2024 Riley Testut. All rights reserved.
//

import Foundation

extension OutputStream
{
    func send<T: Encodable>(_ payload: T) async throws
    {
        let requestData: Data
        if let data = payload as? Data
        {
            requestData = data
        }
        else
        {
            requestData = try JSONEncoder().encode(payload)
        }
        
        let requestSize = withUnsafeBytes(of: Int32(requestData.count)) { Data($0) }
        try await self.send(requestSize)
        try await self.send(requestData)
    }
    
    private func send(_ data: Data) async throws
    {
        var data = data
        
        while !data.isEmpty
        {
            let size = data.count
            data.withUnsafeBytes { bytes in
                let writtenBytes = self.write(bytes, maxLength: size)
                data.replaceSubrange(0 ..< writtenBytes, with: Data())
                
                Logger.main.debug("Wrote \(writtenBytes) bytes to stream.")
            }
        }
    }
}

extension InputStream
{
    private func receiveData(expectedSize: Int) async throws -> Data
    {
        var data = Data()
        
        while data.count < expectedSize
        {
            var chunkData = Data(count: 1024) // 1KB
            let size = chunkData.withUnsafeMutableBytes { mutableBytes in
                self.read(mutableBytes, maxLength: min(expectedSize, 1024))
            }
                        
            data += chunkData[0 ..< size]
            
            Logger.main.debug("Read \(data.count) of \(expectedSize) bytes from stream.")
        }
        
        return data
    }
    
    func receive<T: Decodable>() async throws -> T
    {
        let size = MemoryLayout<Int32>.size
        let expectedSizeData = try await self.receiveData(expectedSize: size)
        
        let expectedSize = Int(expectedSizeData.withUnsafeBytes { $0.load(as: Int32.self) })
        let data = try await self.receiveData(expectedSize: expectedSize)
        
        if let data = data as? T
        {
            return data
        }
        else
        {
            let payload = try JSONDecoder().decode(T.self, from: data)
            return payload
        }
    }
}
