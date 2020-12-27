//
//  UIImage+PDF.swift
//  DeltaCore
//
//  Created by Riley Testut on 12/21/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//
//  Based on Erica Sadun's UIImage+PDFUtility ( https://github.com/erica/useful-things/blob/master/useful%20pack/UIImage%2BPDF/UIImage%2BPDFUtility.m )
//

import UIKit
import CoreGraphics
import AVFoundation

internal extension UIImage
{
    class func image(withPDFData data: Data, targetSize: CGSize) -> UIImage?
    {
        guard targetSize.width > 0 && targetSize.height > 0 else { return nil }
        
        guard
            let dataProvider = CGDataProvider(data: data as CFData),
            let document = CGPDFDocument(dataProvider),
            let page = document.page(at: 1)
            else { return nil }
        
        let pageFrame = page.getBoxRect(.cropBox)
        
        var destinationFrame = AVMakeRect(aspectRatio: pageFrame.size, insideRect: CGRect(origin: CGPoint.zero, size: targetSize))
        destinationFrame.origin = CGPoint.zero
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale
        let imageRenderer = UIGraphicsImageRenderer(bounds: destinationFrame, format: format)
        
        let image = imageRenderer.image { (imageRendererContext) in
            
            let context = imageRendererContext.cgContext
            
            // Save state
            context.saveGState()
            
            // Flip coordinate system to match Quartz system
            let transform = CGAffineTransform.identity.scaledBy(x: 1.0, y: -1.0).translatedBy(x: 0.0, y: -targetSize.height)
            context.concatenate(transform)
            
            // Calculate rendering frames
            destinationFrame = destinationFrame.applying(transform)
            
            let aspectScale = min(destinationFrame.width / pageFrame.width, destinationFrame.height / pageFrame.height)
            
            // Ensure aspect ratio is preserved
            var drawingFrame = pageFrame.applying(CGAffineTransform(scaleX: aspectScale, y: aspectScale))
            drawingFrame.origin.x = destinationFrame.midX - (drawingFrame.width / 2.0)
            drawingFrame.origin.y = destinationFrame.midY - (drawingFrame.height / 2.0)
            
            // Scale the context
            context.translateBy(x: destinationFrame.minX, y: destinationFrame.minY)
            context.scaleBy(x: aspectScale, y: aspectScale)
            
            // Render the PDF
            context.drawPDFPage(page)
            
            // Restore state
            context.restoreGState()
        }
        
        return image
    }
}
