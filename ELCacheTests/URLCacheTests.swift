//
//  URLCacheTests.swift
//  ELCacheTests
//
//  Created by Sam Grover on 12/9/15.
//  Copyright © 2015 WalmartLabs. All rights reserved.
//

import Foundation
import XCTest

class URLCacheTests: XCTestCase {
    
    let urlCache = URLCache.sharedURLCache
    
    override func setUp() {
        super.setUp()
        urlCache.flushCache()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    // Fetch a text file
    func testFetch() {
        let successExpectation = expectationWithDescription("Expected string matched.")
        let expectedString = "User-agent: *\nDisallow: /deny\n"
        if let url = NSURL(string: "http://httpbin.org/robots.txt") {
            urlCache.fetch(url) { (data: MemoryCacheable?, error: NSError?) -> Void in
                if let data = data as? NSData {
                    if let htmlString = String(data: data, encoding: NSUTF8StringEncoding) {
                        if htmlString == expectedString {
                            successExpectation.fulfill()
                        }
                    }
                }
            }
        }
        waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testFetchImage() {
        let successExpectation = expectationWithDescription("Expected image matched.")
        if let url = NSURL(string: "http://httpbin.org/image/jpeg") {
            urlCache.fetchImage(url) { (image: UIImage?, error: NSError?) -> Void in
                if let image = image {
                    if image.size == CGSize(width: 239, height: 178) {
                        successExpectation.fulfill()
                    }
                }
            }
        }
        waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testMultipleImageFetches() {
        let successExpectation = expectationWithDescription("All images fetched.")
        let imgURLStrings = [
            "http://httpbin.org/image/jpeg",
            "http://httpbin.org/image/png",
        ]
        
        for (anIndex, anImageURLString) in imgURLStrings.enumerate() {
            if let URL = NSURL(string: anImageURLString) {
                urlCache.fetchImage(URL) {_,_ in
                    if anIndex == imgURLStrings.count - 1 {
                        successExpectation.fulfill()
                    }
                }
            }
        }
        
        waitForExpectationsWithTimeout(7, handler: nil)
        
        let allValidInCache = imgURLStrings.reduce(true) { (all: Bool, anImageURLString: String) -> Bool in
            var valid = false
            if let URL = NSURL(string: anImageURLString) {
                valid = urlCache.validInCache(URL)
            }
            return all && valid
        }
        
        XCTAssertTrue(allValidInCache)
    }
    
    func testCancel() {
        if let url = NSURL(string: "http://httpbin.org/image/jpeg") {
            urlCache.fetchImage(url) {_,_ in }
            XCTAssertTrue(urlCache.isNetworkFetching(url))
            urlCache.cancelFetch(url)
            XCTAssertFalse(urlCache.isNetworkFetching(url))
        }
    }
    
    func testStorageCache() {
        let networkSuccessExpectation = expectationWithDescription("Network fetched.")
        if let url = NSURL(string: "http://httpbin.org/image/jpeg") {
            urlCache.fetchImage(url) {_,_ in
                networkSuccessExpectation.fulfill()
            }
        }
        waitForExpectationsWithTimeout(1, handler: nil)
        
        // Remove from memory. Should still exist in storage.
        urlCache.flushMemoryCache()
        
        let storageSuccessExpectation = expectationWithDescription("Storage fetched.")
        if let url = NSURL(string: "http://httpbin.org/image/jpeg") {
            urlCache.fetchImage(url, cacheOnly: true) {_,_ in
                storageSuccessExpectation.fulfill()
            }
        }
        
        waitForExpectationsWithTimeout(0.05, handler: nil)
    }
    
    func testMemoryCache() {
        let imageURL = "http://httpbin.org/image/jpeg"
        let networkSuccessExpectation = expectationWithDescription("Network fetched.")
        if let url = NSURL(string: imageURL) {
            urlCache.fetchImage(url) {_,_ in
                networkSuccessExpectation.fulfill()
            }
        }
        waitForExpectationsWithTimeout(1, handler: nil)
        
        XCTAssert(urlCache.memoryCache.numberOfItems() == 1)
        
        // Remove from storage. Should still exist in memory.
        urlCache.flushStorageCache()
        
        XCTAssert(urlCache.memoryCache.numberOfItems() == 1)
        
        // But it shouldn't be returned when queried because that should be looking into storage cache to check validity
        let memoryFailureExpectation = expectationWithDescription("Image not found.")
        if let url = NSURL(string: imageURL) {
            urlCache.fetchImage(url, cacheOnly: true) {image,_ in
                memoryFailureExpectation.fulfill()
                XCTAssertNil(image)
            }
        }
        
        waitForExpectationsWithTimeout(0.05, handler: nil)
    }
    
    func testImageView() {
        let successExpectation = expectationWithDescription("Expected image matched.")
        if let url = NSURL(string: "http://httpbin.org/image/jpeg") {
            let _ = UIImageView(URL: url) { (image: UIImage?, error: NSError?) -> Void in
                if let image = image {
                    if image.size == CGSize(width: 239, height: 178) {
                        successExpectation.fulfill()
                    }
                }
            }
        }
        waitForExpectationsWithTimeout(2, handler: nil)
    }
}
