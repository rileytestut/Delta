//
//  OpenGLESProcessor.swift
//  DeltaCore
//
//  Created by Riley Testut on 4/8/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import CoreImage
import GLKit

class OpenGLESProcessor: VideoProcessor
{
    var videoFormat: VideoFormat {
        didSet {
            self.resizeVideoBuffers()
        }
    }
    
    private let context: EAGLContext
    
    private var framebuffer: GLuint = 0
    private var texture: GLuint = 0
    private var renderbuffer: GLuint = 0
    
    private var indexBuffer: GLuint = 0
    private var vertexBuffer: GLuint = 0
    
    init(videoFormat: VideoFormat, context: EAGLContext)
    {
        self.videoFormat = videoFormat
        self.context = EAGLContext(api: .openGLES2, sharegroup: context.sharegroup)!
    }
    
    deinit
    {
        if self.renderbuffer > 0
        {
            glDeleteRenderbuffers(1, &self.renderbuffer)
        }
        
        if self.texture > 0
        {
            glDeleteTextures(1, &self.texture)
        }
        
        if self.framebuffer > 0
        {
            glDeleteFramebuffers(1, &self.framebuffer)
        }
        
        if self.indexBuffer > 0
        {
            glDeleteBuffers(1, &self.indexBuffer)
        }
        
        if self.vertexBuffer > 0
        {
            glDeleteBuffers(1, &self.vertexBuffer)
        }
    }
}

extension OpenGLESProcessor
{
    var videoBuffer: UnsafeMutablePointer<UInt8>? {
        return nil
    }
    
    func prepare()
    {
        struct Vertex
        {
            var x: GLfloat
            var y: GLfloat
            var z: GLfloat
            
            var u: GLfloat
            var v: GLfloat
        }
        
        EAGLContext.setCurrent(self.context)
        
        // Vertex buffer
        let vertices = [Vertex(x: -1.0, y: -1.0, z: 1.0, u: 0.0, v: 0.0),
                        Vertex(x: 1.0, y: -1.0, z: 1.0, u: 1.0, v: 0.0),
                        Vertex(x: 1.0, y: 1.0, z: 1.0, u: 1.0, v: 1.0),
                        Vertex(x: -1.0, y: 1.0, z: 1.0, u: 0.0, v: 1.0)]
        glGenBuffers(1, &self.vertexBuffer)
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), self.vertexBuffer)
        glBufferData(GLenum(GL_ARRAY_BUFFER), MemoryLayout<Vertex>.size * vertices.count, vertices, GLenum(GL_DYNAMIC_DRAW))
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), 0)
        
        // Index buffer
        let indices: [GLushort] = [0, 1, 2, 0, 2, 3]
        glGenBuffers(1, &self.indexBuffer)
        glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), self.indexBuffer)
        glBufferData(GLenum(GL_ELEMENT_ARRAY_BUFFER), MemoryLayout<GLushort>.size * indices.count, indices, GLenum(GL_STATIC_DRAW))
        glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), 0)
        
        // Framebuffer
        glGenFramebuffers(1, &self.framebuffer)
        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), self.framebuffer)
        
        // Texture
        glGenTextures(1, &self.texture)
        glBindTexture(GLenum(GL_TEXTURE_2D), self.texture)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GLint(GL_LINEAR))
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GLint(GL_LINEAR))
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GLint(GL_CLAMP_TO_EDGE))
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GLint(GL_CLAMP_TO_EDGE))
        glBindTexture(GLenum(GL_TEXTURE_2D), 0)
        glFramebufferTexture2D(GLenum(GL_FRAMEBUFFER), GLenum(GL_COLOR_ATTACHMENT0), GLenum(GL_TEXTURE_2D), self.texture, 0)
        
        // Renderbuffer
        glGenRenderbuffers(1, &self.renderbuffer)
        glBindRenderbuffer(GLenum(GL_RENDERBUFFER), self.renderbuffer)
        glFramebufferRenderbuffer(GLenum(GL_FRAMEBUFFER), GLenum(GL_DEPTH_ATTACHMENT), GLenum(GL_RENDERBUFFER), self.renderbuffer)
        
        self.resizeVideoBuffers()
    }
    
    func processFrame() -> CIImage?
    {
        glFlush()
        
        let image = CIImage(texture: self.texture, size: self.videoFormat.dimensions, flipped: false, colorSpace: nil)
        return image
    }
}

private extension OpenGLESProcessor
{
    func resizeVideoBuffers()
    {
        guard self.texture > 0 && self.renderbuffer > 0 else { return }
        
        EAGLContext.setCurrent(self.context)
        
        glBindTexture(GLenum(GL_TEXTURE_2D), self.texture)
        glTexImage2D(GLenum(GL_TEXTURE_2D), 0, GL_RGBA, GLsizei(self.videoFormat.dimensions.width), GLsizei(self.videoFormat.dimensions.height), 0, GLenum(GL_RGBA), GLenum(GL_UNSIGNED_BYTE), nil)
        glBindTexture(GLenum(GL_TEXTURE_2D), 0)
        
        glBindRenderbuffer(GLenum(GL_RENDERBUFFER), self.renderbuffer)
        glRenderbufferStorage(GLenum(GL_RENDERBUFFER), GLenum(GL_DEPTH_COMPONENT16), GLsizei(self.videoFormat.dimensions.width), GLsizei(self.videoFormat.dimensions.height))
        
        glViewport(0, 0, GLsizei(self.videoFormat.dimensions.width), GLsizei(self.videoFormat.dimensions.height))
    }
}
