//
//  CustomScreenFilter.swift
//  Delta
//
//  Created by Shane on 10/5/26.
//  Copyright © 2026 Riley Testut. All rights reserved.
//

import Foundation
import CoreImage

@objcMembers
class CustomScreenFilter: CIFilter
{
    enum Error: LocalizedError
    {
        case unreadable
        case invalidKernel

        var errorDescription: String? {
            switch self
            {
            case .unreadable: return NSLocalizedString("The file could not be read as text.", comment: "")
            case .invalidKernel: return NSLocalizedString("The file must contain a Core Image Kernel Language kernel with the signature “kernel vec4 filename(sampler source, vec2 sourceSize, vec2 outputSize)”.", comment: "")
            }
        }
    }

    var inputImage: CIImage?
    
    var inputShaderPath: String?
    
    var inputTargetWidth: Double = 0
    var inputTargetHeight: Double = 0

    var targetSize: CGSize {
        return CGSize(width: self.inputTargetWidth, height: self.inputTargetHeight)
    }

    override var outputImage: CIImage? {
        guard let inputImage = self.inputImage else { return nil }

        let extent = inputImage.extent
        guard !extent.isInfinite, !extent.isEmpty else { return inputImage }

        // Move image to origin so shaders can use game pixel coordinates directly.
        let image = inputImage.transformed(by: CGAffineTransform(translationX: -extent.minX, y: -extent.minY)).samplingNearest()

        // Don't round outputSize: GameView scales outputImage to fill its (possibly fractional) drawable size,
        // and any scaling makes Core Image render this kernel to an intermediate image, which can then be displayed again in later frames.
        let outputSize = self.targetSize
        guard outputSize.width > 0, outputSize.height > 0, let shaderPath = self.inputShaderPath, let kernel = try? CustomScreenFilter.kernel(at: URL(fileURLWithPath: shaderPath)) else { return image }

        // Shaders may sample anywhere in the game frame, so every output region depends on the entire frame.
        let outputImage = kernel.apply(extent: CGRect(origin: .zero, size: outputSize), roiCallback: { _, _ in image.extent },
                                       arguments: [image, CIVector(x: extent.width, y: extent.height), CIVector(x: outputSize.width, y: outputSize.height)])
        return outputImage ?? image
    }

    override init()
    {
        super.init()
    }

    convenience init(shaderURL: URL, targetSize: CGSize)
    {
        self.init()

        self.inputShaderPath = shaderURL.path
        self.inputTargetWidth = Double(targetSize.width)
        self.inputTargetHeight = Double(targetSize.height)
    }

    required init?(coder: NSCoder)
    {
        super.init(coder: coder)
    }
}

extension CustomScreenFilter
{
    private static let kernelsLock = NSLock()
    private static var kernels = [URL: CIKernel]()

    // Compiles (and caches) the shader at fileURL, throwing an error if it isn't a valid Custom Filter.
    static func kernel(at fileURL: URL) throws -> CIKernel
    {
        self.kernelsLock.lock()
        defer { self.kernelsLock.unlock() }

        if let kernel = self.kernels[fileURL]
        {
            return kernel
        }

        guard let source = try? String(contentsOf: fileURL, encoding: .utf8) else { throw Error.unreadable }
        let kernel = try self.kernel(source: source)

        self.kernels[fileURL] = kernel
        return kernel
    }

    static func kernel(source: String) throws -> CIKernel
    {
        // CIKernel(source:) is deprecated in favor of precompiled Metal kernels, but it's the only way to compile plain text kernels that also work with OpenGL ES (e.g. N64).
        // Call it dynamically to avoid deprecation warnings.
        let selector = NSSelectorFromString("kernelWithString:")
        guard
            let kernel = (CIKernel.self as AnyObject).perform(selector, with: source)?.takeUnretainedValue() as? CIKernel,
            type(of: kernel) == CIKernel.self // Color and warp kernels don't take a sampler.
        else { throw Error.invalidKernel }

        // Make sure kernel accepts the arguments we pass to it.
        let testImage = CIImage(color: CIColor(red: 0, green: 0, blue: 0)).cropped(to: CGRect(x: 0, y: 0, width: 1, height: 1))
        guard kernel.apply(extent: testImage.extent, roiCallback: { _, rect in rect }, arguments: [testImage, CIVector(x: 1, y: 1), CIVector(x: 1, y: 1)]) != nil else { throw Error.invalidKernel }

        return kernel
    }
}
