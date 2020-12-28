//
//  GameView.swift
//  DeltaCore
//
//  Created by Riley Testut on 3/16/15.
//  Copyright (c) 2015 Riley Testut. All rights reserved.
//

import UIKit
import CoreImage
import GLKit
import AVFoundation

// Create wrapper class to prevent exposing GLKView (and its annoying deprecation warnings) to clients.
private class GameViewGLKViewDelegate: NSObject, GLKViewDelegate
{
    weak var gameView: GameView?
    
    init(gameView: GameView)
    {
        self.gameView = gameView
    }
    
    func glkView(_ view: GLKView, drawIn rect: CGRect)
    {
        self.gameView?.glkView(view, drawIn: rect)
    }
}

public enum SamplerMode
{
    case linear
    case nearestNeighbor
}

public class GameView: UIView
{
    @NSCopying public var inputImage: CIImage? {
        didSet {
            if self.inputImage?.extent != oldValue?.extent
            {
                DispatchQueue.main.async {
                    self.setNeedsLayout()
                }
            }
            
            self.update()
        }
    }
    
    @NSCopying public var filter: CIFilter? {
        didSet {
            self.update()
        }
    }
    
    public var samplerMode: SamplerMode = .nearestNeighbor {
        didSet {
            self.update()
        }
    }
    
    public var outputImage: CIImage? {
        guard let inputImage = self.inputImage else { return nil }
        
        var image: CIImage?
        
        switch self.samplerMode
        {
        case .linear: image = inputImage.samplingLinear()
        case .nearestNeighbor: image = inputImage.samplingNearest()
        }
                
        if let filter = self.filter
        {
            filter.setValue(image, forKey: kCIInputImageKey)
            image = filter.outputImage
        }
        
        return image
    }
    
    internal var eaglContext: EAGLContext {
        get { return self.glkView.context }
        set {
            self.renderQueue.sync {
                // For some reason, if we don't explicitly set current EAGLContext to nil, assigning
                // to self.glkView may crash if we've already rendered to a game view.
                EAGLContext.setCurrent(nil)
                
                self.glkView.context = EAGLContext(api: .openGLES2, sharegroup: newValue.sharegroup)!
                self.context = self.makeContext()
            }
        }
    }
    private lazy var context: CIContext = self.makeContext()
        
    private let glkView: GLKView
    private lazy var glkViewDelegate = GameViewGLKViewDelegate(gameView: self)
    
    private let renderQueue = DispatchQueue(label: "DeltaCore.GameView.renderQueue")
    
    public override init(frame: CGRect)
    {
        let eaglContext = EAGLContext(api: .openGLES2)!
        self.glkView = GLKView(frame: CGRect.zero, context: eaglContext)
        
        super.init(frame: frame)
        
        self.initialize()
    }
    
    public required init?(coder aDecoder: NSCoder)
    {
        let eaglContext = EAGLContext(api: .openGLES2)!
        self.glkView = GLKView(frame: CGRect.zero, context: eaglContext)
        
        super.init(coder: aDecoder)
        
        self.initialize()
    }
    
    private func initialize()
    {        
        self.glkView.frame = self.bounds
        self.glkView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.glkView.delegate = self.glkViewDelegate
        self.glkView.enableSetNeedsDisplay = false
        self.addSubview(self.glkView)
    }
    
    public override func didMoveToWindow()
    {
        if let window = self.window
        {
            self.glkView.contentScaleFactor = window.screen.scale
            self.update()
        }
    }
    
    public override func layoutSubviews()
    {
        super.layoutSubviews()
        
        self.glkView.isHidden = (self.outputImage == nil)
    }
}

public extension GameView
{
    func snapshot() -> UIImage?
    {
        // Unfortunately, rendering CIImages doesn't always work when backed by an OpenGLES texture.
        // As a workaround, we simply render the view itself into a graphics context the same size
        // as our output image.
        //
        // let cgImage = self.context.createCGImage(outputImage, from: outputImage.extent)
        
        guard let outputImage = self.outputImage else { return nil }

        let rect = CGRect(origin: .zero, size: outputImage.extent.size)
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = true
        
        let renderer = UIGraphicsImageRenderer(size: rect.size, format: format)
        
        let snapshot = renderer.image { (context) in
            self.glkView.drawHierarchy(in: rect, afterScreenUpdates: false)
        }
        
        return snapshot
    }
}

private extension GameView
{
    func makeContext() -> CIContext
    {
        let context = CIContext(eaglContext: self.glkView.context, options: [.workingColorSpace: NSNull()])
        return context
    }
    
    func update()
    {
        // Calling display when outputImage is nil may crash for OpenGLES-based rendering.
        guard self.outputImage != nil else { return }
              
        self.renderQueue.sync {
            self.glkView.display()
        }
    }
}

private extension GameView
{
    func glkView(_ view: GLKView, drawIn rect: CGRect)
    {
        glClearColor(0.0, 0.0, 0.0, 1.0)
        glClear(UInt32(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT))
        
        if let outputImage = self.outputImage
        {
            let bounds = CGRect(x: 0, y: 0, width: self.glkView.drawableWidth, height: self.glkView.drawableHeight)
            self.context.draw(outputImage, in: bounds, from: outputImage.extent)
        }
    }
}
