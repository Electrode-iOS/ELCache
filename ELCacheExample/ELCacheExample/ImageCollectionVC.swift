//
//  ImageCollectionVC.swift
//  ELCacheExample
//
//  Created by Sam Grover on 12/28/15.
//  Copyright © 2015 WalmartLabs. All rights reserved.
//

import UIKit
import ELCache

class ImageCollectionVC : UICollectionViewController {
    
    var allImages: [String]?
    let ItemCount = 100
    
    override func viewDidLoad() {
        collectionView?.registerClass(ImageCell.self, forCellWithReuseIdentifier: "ImageClass")
        buildImageURLs()
    }
    
    func buildImageURLs() {
        var images = [String]()
        for _ in 1...ItemCount {
            images.append(randomFillMurrayURL())
        }
        allImages = images
    }
    
    // All images are the same but with differing URLs
    func randomHTTPBinURL() -> String {
        let baseURL = "http://httpbin.org/image/jpeg"
        let maxDimension = 100
        let number = abs(random() % maxDimension)
        return baseURL + "?" + String(number)
    }
    
    // Gets cached properly
    func randomPlaceholdItURL() -> String {
        let baseURL = "http://placehold.it/"
        let maxDimension = 500
        let width = abs(random() % maxDimension)
        let height = abs(random() % maxDimension)
        return baseURL + String(width) + "x" + String(height) + "/000.jpg"
    }
    
    // Doesn't get cached in NSURLCache for some reason
    func randomFillMurrayURL() -> String {
        let baseURL = "http://fillmurray.com/"
        let maxDimension = 500
        let width = abs(random() % maxDimension)
        let height = abs(random() % maxDimension)
        return baseURL + String(width) + "/" + String(height)
    }
    
}

// UICollectionViewDataSource
extension ImageCollectionVC {
    
    override func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return ItemCount
    }
    
    override func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("ImageCell", forIndexPath: indexPath)
        if let imageCell = cell as? ImageCell, let anImageURLString = allImages?[indexPath.item] {
            if let URL = NSURL(string: anImageURLString) {
                imageCell.imageView.setImageAt(URL) { (_,_) in }
            }
        }
        return cell
    }
    
}

// UICollectionViewDelegate
extension ImageCollectionVC {
    
}
