//
//  VideoBufferInfo.swift
//  DeltaCore
//
//  Created by Riley Testut on 4/18/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import CoreGraphics
import CoreImage

extension VideoFormat
{
    public enum Format: Equatable
    {
        case bitmap(PixelFormat)
        case openGLES
    }
    
    public enum PixelFormat: Equatable
    {
        case rgb565
        case bgra8
        case rgba8
        
        public var bytesPerPixel: Int {
            switch self
            {
            case .rgb565: return 2
            case .bgra8: return 4
            case .rgba8: return 4
            }
        }
    }
}

public struct VideoFormat: Equatable
{
    public var format: Format
    public var dimensions: CGSize
    
    public init(format: Format, dimensions: CGSize)
    {
        self.format = format
        self.dimensions = dimensions
    }
}
