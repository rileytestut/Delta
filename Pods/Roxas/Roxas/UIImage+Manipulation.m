//
//  UIImage+Manipulation.m
//  Hoot
//
//  Created by Riley Testut on 9/23/14.
//  Copyright (c) 2014 TMT. All rights reserved.
//

#import "UIImage+Manipulation.h"

@implementation UIImage (Manipulation)

#pragma mark - Resizing -

- (UIImage *)imageByResizingToFitSize:(CGSize)size
{
    CGSize imageSize = self.size;
    
    CGFloat horizontalScale = size.width / imageSize.width;
    CGFloat verticalScale = size.height / imageSize.height;
    
    // Resizing to minimum scale (ex: 1/20 instead of 1/2) ensures image will retain aspect ratio, and fit inside size
    CGFloat scale = MIN(horizontalScale, verticalScale);
    size = CGSizeMake(imageSize.width * scale, imageSize.height * scale);
    
    return [self imageByResizingToSize:size];
}

- (UIImage *)imageByResizingToFillSize:(CGSize)size
{
    CGSize imageSize = self.size;
    
    CGFloat horizontalScale = size.width / imageSize.width;
    CGFloat verticalScale = size.height / imageSize.height;
    
    // Resizing to maximum scale (ex: 1/2 instead of 1/20) ensures image will retain aspect ratio, and will fill size
    CGFloat scale = MAX(horizontalScale, verticalScale);
    size = CGSizeMake(imageSize.width * scale, imageSize.height * scale);
    
    return [self imageByResizingToSize:size];
}

- (UIImage *)imageByResizingToSize:(CGSize)size
{
    switch (self.imageOrientation)
    {
        case UIImageOrientationLeft:
        case UIImageOrientationLeftMirrored:
        case UIImageOrientationRight:
        case UIImageOrientationRightMirrored:
            size = CGSizeMake(size.height, size.width);
            break;
            
        default:
            break;
    }
    
    CGRect rect = CGRectIntegral(CGRectMake(0, 0, size.width * self.scale, size.height * self.scale));
    
    size_t bitsPerComponent = CGImageGetBitsPerComponent(self.CGImage);
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(self.CGImage);
    CGBitmapInfo bitmapInfo = CGImageGetBitmapInfo(self.CGImage);
    
    if (bitmapInfo & kCGImageAlphaLast)
    {
        bitmapInfo &= ~(kCGImageAlphaLast);
    }
    
    bitmapInfo |= kCGImageAlphaNoneSkipLast;
    
    CGContextRef context = CGBitmapContextCreate(NULL,
                                                 CGRectGetWidth(rect),
                                                 CGRectGetHeight(rect),
                                                 bitsPerComponent,
                                                 0, // CGImageGetBytesPerRow(self.CGImage) crashes on malformed UIImages (such as Crossy Road's). Passing 0 = automatic calculation, and is safer
                                                 colorSpace,
                                                 bitmapInfo);
    
    if (context == NULL)
    {
        return nil;
    }
    
    CGContextSetInterpolationQuality(context, kCGInterpolationHigh);
    
    CGContextDrawImage(context, rect, self.CGImage);
    
    CGImageRef imageRef = CGBitmapContextCreateImage(context);
    UIImage *image = [[UIImage imageWithCGImage:imageRef scale:self.scale orientation:self.imageOrientation] imageWithRenderingMode:self.renderingMode];
    
    CFRelease(imageRef);
    CFRelease(context);
    
    return image;
}

#pragma mark - Rounded Corners -

- (UIImage *)imageWithCornerRadius:(CGFloat)cornerRadius
{
    return [self imageWithCornerRadius:cornerRadius inset:UIEdgeInsetsZero];
}

- (UIImage *)imageWithCornerRadius:(CGFloat)cornerRadius inset:(UIEdgeInsets)inset
{
    UIEdgeInsets correctedInset = inset;
    
    switch (self.imageOrientation)
    {
        case UIImageOrientationLeft:
        case UIImageOrientationLeftMirrored:
            correctedInset.top = inset.left;
            correctedInset.bottom = inset.right;
            correctedInset.left = inset.bottom;
            correctedInset.right = inset.top;
            break;
            
        case UIImageOrientationRight:
        case UIImageOrientationRightMirrored:
            correctedInset.top = inset.right;
            correctedInset.bottom = inset.left;
            correctedInset.left = inset.top;
            correctedInset.right = inset.bottom;
            break;
            
        case UIImageOrientationDown:
        case UIImageOrientationDownMirrored:
            correctedInset.top = inset.bottom;
            correctedInset.bottom = inset.top;
            correctedInset.left = inset.left;
            correctedInset.right = inset.right;
            break;
            
        default:
            break;
    }
    
    CGFloat imageScale = self.scale;
    
    CGRect clippedRect = CGRectMake(0, 0, self.size.width - correctedInset.left - correctedInset.right, self.size.height - correctedInset.top - correctedInset.bottom);
    CGRect drawingRect = CGRectMake(-correctedInset.left, -correctedInset.top, self.size.width, self.size.height);
    
    clippedRect = CGRectApplyAffineTransform(clippedRect, CGAffineTransformMakeScale(imageScale, imageScale));
    drawingRect = CGRectApplyAffineTransform(drawingRect, CGAffineTransformMakeScale(imageScale, imageScale));
    
    size_t bitsPerComponent = CGImageGetBitsPerComponent(self.CGImage);
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(self.CGImage);
    CGBitmapInfo bitmapInfo = CGImageGetBitmapInfo(self.CGImage);
    
    if (bitmapInfo & kCGImageAlphaLast)
    {
        bitmapInfo &= ~(kCGImageAlphaLast);
        bitmapInfo |= kCGImageAlphaNoneSkipLast;
    }
    
    CGContextRef context = CGBitmapContextCreate(NULL,
                                                 CGRectGetWidth(clippedRect),
                                                 CGRectGetHeight(clippedRect),
                                                 bitsPerComponent,
                                                 0, // CGImageGetBytesPerRow(self.CGImage) crashes on malformed UIImages (such as Crossy Road's). Passing 0 = automatic calculation, and is safer
                                                 colorSpace,
                                                 bitmapInfo);
    
    if (context == NULL)
    {
        return nil;
    }
    
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:clippedRect cornerRadius:cornerRadius * imageScale];
    
    CGContextAddPath(context, path.CGPath);
    CGContextClip(context);
    
    CGContextDrawImage(context, drawingRect, self.CGImage);
    
    CGImageRef imageRef = CGBitmapContextCreateImage(context);
    UIImage *image = [[UIImage imageWithCGImage:imageRef scale:imageScale orientation:self.imageOrientation] imageWithRenderingMode:self.renderingMode];
    
    CFRelease(imageRef);
    CFRelease(context);
    
    return image;
}

@end


UIImageMetadataOrientation UIImageMetadataOrientationFromImageOrientation(UIImageOrientation imageOrientation)
{
    UIImageMetadataOrientation metadataOrientation = UIImageMetadataOrientationUp;
    
    switch (imageOrientation)
    {
        case UIImageOrientationUp:
            metadataOrientation = UIImageMetadataOrientationUp;
            break;
            
        case UIImageOrientationDown:
            metadataOrientation = UIImageMetadataOrientationDown;
            break;
            
        case UIImageOrientationLeft:
            metadataOrientation = UIImageMetadataOrientationLeft;
            break;
            
        case UIImageOrientationRight:
            metadataOrientation = UIImageMetadataOrientationRight;
            break;
            
        case UIImageOrientationUpMirrored:
            metadataOrientation = UIImageMetadataOrientationUpMirrored;
            break;
            
        case UIImageOrientationDownMirrored:
            metadataOrientation = UIImageMetadataOrientationDownMirrored;
            break;
            
        case UIImageOrientationLeftMirrored:
            metadataOrientation = UIImageMetadataOrientationLeftMirrored;
            break;
            
        case UIImageOrientationRightMirrored:
            metadataOrientation = UIImageMetadataOrientationRightMirrored;
            break;
    }
    
    return metadataOrientation;
}

UIImageOrientation UIImageOrientationFromMetadataOrientation(UIImageMetadataOrientation metadataOrientation)
{
    UIImageOrientation imageOrientation = UIImageOrientationUp;
    
    switch (metadataOrientation)
    {
        case UIImageMetadataOrientationUp:
            imageOrientation = UIImageOrientationUp;
            break;
            
        case UIImageMetadataOrientationDown:
            imageOrientation = UIImageOrientationDown;
            break;
            
        case UIImageMetadataOrientationLeft:
            imageOrientation = UIImageOrientationLeft;
            break;
            
        case UIImageMetadataOrientationRight:
            imageOrientation = UIImageOrientationRight;
            break;
            
        case UIImageMetadataOrientationUpMirrored:
            imageOrientation = UIImageOrientationUpMirrored;
            break;
            
        case UIImageMetadataOrientationDownMirrored:
            imageOrientation = UIImageOrientationDownMirrored;
            break;
            
        case UIImageMetadataOrientationLeftMirrored:
            imageOrientation = UIImageOrientationLeftMirrored;
            break;
            
        case UIImageMetadataOrientationRightMirrored:
            imageOrientation = UIImageOrientationRightMirrored;
            break;
    }
    
    return imageOrientation;
}
