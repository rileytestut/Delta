//
//  BitmapProcessor.swift
//  DeltaCore
//
//  Created by Riley Testut on 4/8/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import CoreImage
import Accelerate

fileprivate extension VideoFormat.PixelFormat
{
    var nativeCIFormat: CIFormat? {
        switch self
        {
        case .rgb565: return nil
        case .bgra8: return .BGRA8
        case .rgba8: return .RGBA8
        }
    }
}

fileprivate extension VideoFormat
{
    var pixelFormat: PixelFormat {
        switch self.format
        {
        case .bitmap(let format): return format
        case .openGLES: fatalError("Should not be using VideoFormat.Format.openGLES with BitmapProcessor.")
        }
    }
    
    var bufferSize: Int {
        let bufferSize = Int(self.dimensions.width * self.dimensions.height) * self.pixelFormat.bytesPerPixel
        return bufferSize
    }
}

class BitmapProcessor: VideoProcessor
{
    let videoFormat: VideoFormat
    let videoBuffer: UnsafeMutablePointer<UInt8>?
    
    private let outputVideoFormat: VideoFormat
    private let outputVideoBuffer: UnsafeMutablePointer<UInt8>
    
    init(videoFormat: VideoFormat)
    {
        self.videoFormat = videoFormat
        
        switch self.videoFormat.pixelFormat
        {
        case .rgb565: self.outputVideoFormat = VideoFormat(format: .bitmap(.bgra8), dimensions: self.videoFormat.dimensions)
        case .bgra8, .rgba8: self.outputVideoFormat = self.videoFormat
        }
        
        self.videoBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: self.videoFormat.bufferSize)
        self.outputVideoBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: self.outputVideoFormat.bufferSize)
    }
    
    deinit
    {
        self.videoBuffer?.deallocate()
        self.outputVideoBuffer.deallocate()
    }
}

extension BitmapProcessor
{
    func prepare()
    {
    }
    
    func processFrame() -> CIImage?
    {
        guard let ciFormat = self.outputVideoFormat.pixelFormat.nativeCIFormat else {
            print("VideoManager output format is not supported.")
            return nil
        }
        
        return autoreleasepool {
            var inputVImageBuffer = vImage_Buffer(data: self.videoBuffer, height: vImagePixelCount(self.videoFormat.dimensions.height), width: vImagePixelCount(self.videoFormat.dimensions.width), rowBytes: self.videoFormat.pixelFormat.bytesPerPixel * Int(self.videoFormat.dimensions.width))
            var outputVImageBuffer = vImage_Buffer(data: self.outputVideoBuffer, height: vImagePixelCount(self.outputVideoFormat.dimensions.height), width: vImagePixelCount(self.outputVideoFormat.dimensions.width), rowBytes: self.outputVideoFormat.pixelFormat.bytesPerPixel * Int(self.outputVideoFormat.dimensions.width))
            
            switch self.videoFormat.pixelFormat
            {
            case .rgb565: vImageConvert_RGB565toBGRA8888(255, &inputVImageBuffer, &outputVImageBuffer, 0)
            case .bgra8, .rgba8:
                // Ensure alpha value is 255, not 0.
                // 0x1 refers to the Blue channel in ARGB, which corresponds to the Alpha channel in BGRA and RGBA.
                vImageOverwriteChannelsWithScalar_ARGB8888(255, &inputVImageBuffer, &outputVImageBuffer, 0x1, vImage_Flags(kvImageNoFlags))
            }
            
            let bitmapData = Data(bytes: self.outputVideoBuffer, count: self.outputVideoFormat.bufferSize)
            
            let image = CIImage(bitmapData: bitmapData, bytesPerRow: self.outputVideoFormat.pixelFormat.bytesPerPixel * Int(self.outputVideoFormat.dimensions.width), size: self.outputVideoFormat.dimensions, format: ciFormat, colorSpace: nil)
            return image
        }
    }
}
