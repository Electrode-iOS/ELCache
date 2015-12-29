//
//  MemoryCache.swift
//  THGCache
//
//  Created by Sam Grover on 12/9/15.
//  Copyright © 2015 TheHolyGrail. All rights reserved.
//

import UIKit

/**
 `MemoryCache` is a simple in-memory LRU cache that manages a collection of `NSData` objects accessed by a `String` key.
 It uses an age index internally to refresh objects each time they are accessed.
 */

public final class MemoryCache {
    
    /// The actual cache in memory. Its parameters are defined by `cacheMaxSize` and `cacheThreshold`.
    internal var cache: [String: NSData]
    /// An index that is used to determine the age of values in the cache. Lower index signifies older value.
    internal var cacheIndex: [String]
    /// All cache modification operations are serialized with this queue.
    internal let cacheProcessingQueue: dispatch_queue_t
    
    /// The maximum permissible size of the memory cache in bytes. When this is exceeded a cleanup is triggered which reduces the cache using the `cacheThreshold` value. Defaults to 16 MB.
    public var cacheMaxSize: Int {
        didSet {
            reduceSizeIfNeeded()
        }
    }
    
    /// A percentage value between 0.0 and 1.0 that the cache will be reduced to when it has maxed over the `cacheMaxSize`. Defaults to 0.75.
    public var cacheThreshold: Double {
        didSet {
            reduceSizeIfNeeded()
        }
    }
    
    public static let sharedMemoryCache = MemoryCache()
    
    public init() {
        cache = [String: NSData]()
        cacheIndex = [String]()
        cacheProcessingQueue = dispatch_queue_create(("com.THGCache.MemoryCache" as NSString).UTF8String, DISPATCH_QUEUE_SERIAL)
        cacheMaxSize = 1024 * 1024 * 16
        cacheThreshold = 0.75
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector(flush()), name: UIApplicationDidReceiveMemoryWarningNotification, object: nil)
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    /// Returns the `NSData` associated with the key, if any.
    public func fetch(key: String) -> NSData? {
        return cache[key]
    }
    
    /// Empties the cache.
    public func flush() {
        dispatch_sync(cacheProcessingQueue) {
            self.cache.removeAll()
            self.cacheIndex.removeAll()
        }
    }
    
    /// Returns the current size of the cache in bytes.
    public func currentSize() -> Int {
        return cache.values.reduce(0) { (totalSize, aResource) -> Int in
            return totalSize + aResource.length
        }
    }
    
    /// Stores the `NSData` with the specified key
    public func store(data: NSData, key: String) {
        dispatch_sync(cacheProcessingQueue) {
            // If it already exists, move it to the end of the age index to refresh, else add it to the cache.
            if let anIndex = self.cacheIndex.indexOf(key) {
                let aURLString = self.cacheIndex.removeAtIndex(anIndex)
                self.cacheIndex.append(aURLString)
            } else {
                self.cache[key] = data
                self.cacheIndex.append(key)
            }
        }
        
        self.reduceSizeIfNeeded()
    }
    
    /// The key and related object are removed if found in the cache.
    public func remove(key: String) {
        dispatch_sync(cacheProcessingQueue) {
            if let anIndex = self.cacheIndex.indexOf(key) {
                let keyForRemoval = self.cacheIndex.removeAtIndex(anIndex)
                self.cache.removeValueForKey(keyForRemoval)
            }
        }
    }
    
    internal func reduceSizeIfNeeded() {
        dispatch_async(cacheProcessingQueue) {
            if self.currentSize() > self.cacheMaxSize {
                // Reduce cache to a reasonable percentage of maximum only if it has exceeded maximum size.
                while self.currentSize() > Int(Double(self.cacheMaxSize) * self.cacheThreshold) {
                    // Sanity check
                    if self.cacheIndex.isEmpty || self.cache.isEmpty {
                        break
                    }
                    
                    let first = self.cacheIndex.removeFirst()
                    self.cache.removeValueForKey(first)
                }
            }
        }
    }
    
}

