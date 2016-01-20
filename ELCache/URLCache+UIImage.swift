//
//  URLCache+UIImage.swift
//  ELCache
//
//  Created by Sam Grover on 12/9/15.
//  Copyright © 2015 WalmartLabs. All rights reserved.
//

import UIKit
import ELFoundation

public typealias FetchImageURLCompletionClosure = (UIImage?, NSError?) -> Void

extension UIImage {
    
    public class func decompressed(image: UIImage) -> UIImage? {
        let imageRef = image.CGImage
        let deviceRGB = CGColorSpaceCreateDeviceRGB()
        let imageWidth = CGImageGetWidth(imageRef)
        let imageHeight = CGImageGetHeight(imageRef)
        let bitmapInfo = CGBitmapInfo.ByteOrder32Little.rawValue | CGImageAlphaInfo.PremultipliedFirst.rawValue
        
        guard let context = CGBitmapContextCreate(
            nil,
            imageWidth,
            imageHeight,
            8,
            // Just always return width * 4 will be enough
            imageWidth * 4,
            // System only supports RGB, set explicitly
            deviceRGB,
            // Makes system don't need to do extra conversion when displayed.
            bitmapInfo) else {
                return nil
        }
        
        let rect = CGRect(origin: CGPointZero, size: CGSize(width: imageWidth, height: imageHeight))
        CGContextDrawImage(context, rect, imageRef)
        
        guard let decompressedImageRef = CGBitmapContextCreateImage(context) else {
            return nil
        }
        
        let decompressedImage = UIImage(CGImage: decompressedImageRef, scale: image.scale, orientation: .Up)
        return decompressedImage
    }
    
}

extension UIImage : MemoryCacheable {
    
    public var sizeInBytes : Int {
        return Int(self.size.width * self.size.height * 4) // Approximation
    }
    
}

extension URLCache {
    
    /// An image optimized fetch method. Calls `fetch` and decompresses the image for display.
    public func fetchImage(URL: NSURL, cacheOnly: Bool = false, completion: FetchImageURLCompletionClosure) {
        fetch(URL, cacheOnly: cacheOnly) { (resource: MemoryCacheable?, error: NSError?) -> Void in
            if let image = resource as? UIImage {
                completion(image, error)
            } else {
                completion(nil, error)
            }
        }
    }
    
}

