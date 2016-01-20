//
//  MemoryCache.swift
//  ELCache
//
//  Created by Sam Grover on 12/9/15.
//  Copyright © 2015 WalmartLabs. All rights reserved.
//

import UIKit

public protocol MemoryCacheable {
    var sizeInBytes: Int { get }
}

extension NSData : MemoryCacheable {
    
    public var sizeInBytes: Int {
        return self.length
    }
    
}

/**
 `MemoryCache` is a simple in-memory LRU cache that manages a collection of `NSData` objects accessed by a `String` key.
 It uses an age index internally to refresh objects each time they are accessed.
 */

public final class MemoryCache {
    
    /// The actual cache in memory. Its parameters are defined by `maxSize` and `threshold`.
    internal var cache: [String: MemoryCacheable]
    /// An index that is used to determine the age of values in the cache. Lower index signifies older value.
    internal var ageIndex: [String]
    /// All cache modification operations are serialized with this queue.
    internal let processingQueue: dispatch_queue_t
    
    /// The maximum permissible size of the memory cache in bytes. When this is exceeded a cleanup is triggered which reduces the cache using the `threshold` value. Defaults to 16 MB.
    public var maxSize: Int {
        didSet {
            reduceSizeIfNeeded()
        }
    }
    
    /// A percentage value between 0.0 and 1.0 that the cache will be reduced to when it has maxed over the `maxSize`. Defaults to 0.75.
    public var threshold: Double {
        didSet {
            reduceSizeIfNeeded()
        }
    }
    
    public static let sharedMemoryCache = MemoryCache()
    
    public init() {
        cache = [String: MemoryCacheable]()
        ageIndex = [String]()
        processingQueue = dispatch_queue_create(("com.ELCache.MemoryCache" as NSString).UTF8String, DISPATCH_QUEUE_SERIAL)
        maxSize = 1024 * 1024 * 16
        threshold = 0.75
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector(flush()), name: UIApplicationDidReceiveMemoryWarningNotification, object: nil)
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    /// Returns the `NSData` associated with the key, if any.
    public func fetch(key: String) -> MemoryCacheable? {
        refreshAge(key)
        return cache[key]
    }
    
    /// Empties the cache.
    public func flush() {
        dispatch_sync(processingQueue) {
            self.cache.removeAll()
            self.ageIndex.removeAll()
        }
    }
    
    /// Returns the current size of the cache in bytes.
    public func currentSize() -> Int {
        return cache.values.reduce(0) { (totalSize, aResource) -> Int in
            return totalSize + aResource.sizeInBytes
        }
    }
    
    /// Returns the number of items in the cache.
    public func numberOfItems() -> Int {
        return cache.count
    }
    
    /// Stores the `NSData` with the specified key
    public func store(data: MemoryCacheable, key: String) {
        dispatch_sync(processingQueue) {
            // If it already exists, refresh age, else add it to the cache.
            if self.exists(key) {
                self.refreshAge(key)
            } else {
                self.cache[key] = data
                self.ageIndex.append(key)
            }
        }
        
        self.reduceSizeIfNeeded()
    }
    
    /// The key and related object are removed if found in the cache.
    public func remove(key: String) {
        dispatch_sync(processingQueue) {
            if let anIndex = self.ageIndex.indexOf(key) {
                let keyForRemoval = self.ageIndex.removeAtIndex(anIndex)
                self.cache.removeValueForKey(keyForRemoval)
            }
        }
    }
    
    /// Returns `true` if the key exists in the cache, `false` otherwise. Doesn't affect the age.
    public func exists(key: String) -> Bool {
        return (cache[key] != nil) && (self.ageIndex.indexOf(key) != nil)
    }
    
    internal func refreshAge(key: String) {
        if let anIndex = self.ageIndex.indexOf(key) {
            let aURLString = self.ageIndex.removeAtIndex(anIndex)
            self.ageIndex.append(aURLString)
        }
    }
    
    internal func reduceSizeIfNeeded() {
        dispatch_async(processingQueue) {
            if self.currentSize() > self.maxSize {
                // Reduce cache to a reasonable percentage of maximum only if it has exceeded maximum size.
                while self.currentSize() > Int(Double(self.maxSize) * self.threshold) {
                    // Sanity check
                    if self.ageIndex.isEmpty || self.cache.isEmpty {
                        break
                    }
                    
                    let first = self.ageIndex.removeFirst()
                    self.cache.removeValueForKey(first)
                }
            }
        }
    }
    
}

