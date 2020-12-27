//
//  URL+ExtendedAttributes.swift
//  Delta
//
//  Created by Riley Testut on 3/26/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import Foundation

extension URL
{
    func setExtendedAttribute(name: String, value: String) throws
    {
        try self.withUnsafeFileSystemRepresentation { (path) in
            let data = value.data(using: .utf8)
            let result = data?.withUnsafeBytes { (buffer) in
                setxattr(path, name, buffer.baseAddress, buffer.count, 0, 0)
            }
            
            if let result = result, result < 0
            {
                throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .ENOENT)
            }
        }
    }
    
    func extendedAttribute(name: String) -> String?
    {
        let value = self.withUnsafeFileSystemRepresentation { (path) -> String? in
            let size = getxattr(path, name, nil, 0, 0, 0)
            guard size >= 0 else { return nil }
            
            var data = Data(count: size)
            let result = data.withUnsafeMutableBytes { getxattr(path, name, $0.baseAddress, $0.count, 0, 0) }
            
            guard result >= 0 else { return nil }
            
            let value = String(data: data, encoding: .utf8)!
            return value
        }
        
        return value
    }
}
