//
//  THGCache+UIImageView.swift
//  THGCache
//
//  Created by Sam Grover on 12/27/15.
//  Copyright © 2015 TheHolyGrail. All rights reserved.
//

import UIKit
import THGFoundation

public extension UIImageView {
    
    internal var urlAssociationKey: String {
        return "io.theholygrail.THGCache.UIImageView.NSURL"
    }
    
    convenience init(URL: NSURL, completion: FetchImageURLCompletionClosure) {
        self.init()
        self.setImageAt(URL, placeholder: nil, completion: completion)
    }
    
    func setImageAt(URL: NSURL) {
        setImageAt(URL, placeholder: nil, completion: {_,_ in })
    }
    
    func setImageAt(URL: NSURL, placeholder: UIImage?) {
        setImageAt(URL, placeholder: placeholder, completion: {_,_ in })
    }
    
    func setImageAt(URL: NSURL, completion: FetchImageURLCompletionClosure) {
        setImageAt(URL, placeholder: nil, completion: completion)
    }
    
    func setImageAt(URL: NSURL, placeholder: UIImage?, completion: FetchImageURLCompletionClosure) {
        // Use the placeholder only if the image is not valid in cache to avoid setting actual image momentarily after setting placeholder.
        if URLCache.sharedURLCache.validInCache(URL) != true {
            self.image = placeholder
        }
        
        URLCache.sharedURLCache.fetchImage(URL) { (image, error) -> Void in
            self.processURLFetch(image, error: error, completion: completion)
        }
        
        setAssociatedObject(self, value: URL, associativeKey: urlAssociationKey, policy: objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
    }
    
    func cancelURL(url: NSURL) {
        if let URL: NSURL = getAssociatedObject(self, associativeKey: urlAssociationKey) {
            URLCache.sharedURLCache.cancelFetch(URL)
        }
    }
    
    internal func processURLFetch(image: UIImage?, error: NSError?, completion: FetchImageURLCompletionClosure) {
        if let image = image {
            self.image = image
        }
        
        completion(image, error)
    }
}
