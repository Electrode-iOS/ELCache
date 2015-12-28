//
//  URLCache+UIImage.swift
//  SwallowExample
//
//  Created by Sam Grover on 12/9/15.
//  Copyright © 2015 TheHolyGrail. All rights reserved.
//

import UIKit
import THGFoundation

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

extension URLCache {
    
    /// An image optimized fetch method. Calls `fetch` and decompresses the image for display.
    public func fetchImage(URL: NSURL, cacheOnly: Bool = false, completion: FetchImageURLCompletionClosure) {
        fetch(URL, cacheOnly: cacheOnly) { (data: NSData?, error: NSError?) -> Void in
            var image: UIImage? = nil
            if let imageData = data {
                if let imageFromData = UIImage(data: imageData) {
                    image = UIImage.decompressed(imageFromData)
                }
            }
            completion(image, error)
        }
    }
    
}

