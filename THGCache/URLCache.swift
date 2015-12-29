//
//  URLCache.swift
//  THGCache
//
//  Created by Sam Grover on 12/7/15.
//  Copyright © 2015 TheHolyGrail. All rights reserved.
//

import Foundation
import THGWebService

public typealias FetchURLCompletionClosure = (NSData?, NSError?) -> Void

@objc
public class URLCache: NSObject {
    
    var activeServiceTasks: [String: ServiceTask]
    let memoryCache = MemoryCache.sharedMemoryCache
    
    static let sharedURLCache = URLCache()
    
    override init() {
        activeServiceTasks = [String: ServiceTask]()
        super.init()
    }
    
    /// Cleans out from storage the entire shared URL cache managed by `NSURLCache`
    public func flushStorageCache() {
        NSURLCache.sharedURLCache().removeAllCachedResponses()
    }
    
    /// Cleans out the memory cache
    public func flushMemoryCache() {
        memoryCache.flush()
    }
    
    /// Cleans out both memory cache and storage cache. Basically calls `flushMemoryCache` and `flushStorageCache`.
    public func flushCache() {
        memoryCache.flush()
        flushStorageCache()
    }
    
    /**
    Fetches the resource at the URL. If it has been fetched before, its validity is checked in storage cache.
    Looks at memory cache, storage cache, and goes out to network if not found in those two.
    
    - parameter URL: The URL being fetched.
    - parameter cacheOnly: If `true`, then only look in cache. Defaults to `false`.
    - parameter completion: The completion block to call with the results of the fetch.
    */
    public func fetch(URL: NSURL, cacheOnly: Bool = false, completion: FetchURLCompletionClosure) {
        var found = false
        let valid = validInCache(URL)
        
        if valid {
            found = fetchFromMemory(URL, completion: completion)
            
            if !found {
                found = fetchFromStorage(URL, completion: completion)
            }
        }
        
        if !found  && !cacheOnly {
            fetchFromNetwork(URL, completion: completion)
        }
    }
    
    /// Checks if the resource at the URL exists and is valid in cache.
    public func validInCache(URL: NSURL) -> Bool {
        return fetchFromStorage(URL) {_,_ in }
    }
    
    /// Returns `true` is the URL is being fetched from the network, `false` otherwise.
    public func isNetworkFetching(URL: NSURL) -> Bool {
        return activeServiceTasks[URL.absoluteString] != nil
    }
    
    /// Cancels the network fetch of a URL if it is currently in progress.
    public func cancelFetch(URL: NSURL) {
        if let aTask = self.activeServiceTasks.removeValueForKey(URL.absoluteString) {
            aTask.cancel()
        }
    }
    
    /// Remove the URL from memory and storage cache, cancelling any ongoing fetches if necessary.
    public func remove(URL: NSURL) {
        cancelFetch(URL)
        memoryCache.remove(URL.absoluteString)
        NSURLCache.sharedURLCache().removeCachedResponseForRequest(NSURLRequest(URL: URL))
    }
    
    func fetchFromMemory(URL: NSURL, completion: FetchURLCompletionClosure) -> Bool {
        if let resource = memoryCache.fetch(URL.absoluteString) {
            didFetch(resource, URL: URL, error: nil, completion: completion)
            return true
        }
        return false
    }
    
    func fetchFromStorage(URL: NSURL, completion: FetchURLCompletionClosure) -> Bool {
        var success = false
        let request = NSURLRequest(URL: URL)
        if let cachedResponse = NSURLCache.sharedURLCache().validCachedResponseForRequest(request, timeToLive: 60, removeIfInvalid: true) {
            didFetch(cachedResponse.data, URL: URL, error: nil, completion: completion)
            success = true
        }
        return success
    }
    
    func fetchFromNetwork(URL: NSURL, completion: FetchURLCompletionClosure) {
        let aTask = WebService(baseURLString: "").GET(URL.absoluteString)
        activeServiceTasks[URL.absoluteString] = aTask
        var error: NSError? = nil
        aTask
            .response { (data: NSData?, response: NSURLResponse?) -> ServiceTaskResult in
                self.activeServiceTasks.removeValueForKey(URL.absoluteString)
                
                if let httpResponse = response as? NSHTTPURLResponse {
                    if httpResponse.statusCode >= 400 {
                        error = NSError(domain: NSURLErrorDomain, code: NSURLErrorBadURL, userInfo: nil)
                    }
                    
                    if let data = data {
                        self.didFetch(data, URL: URL, error: error, completion: completion)
                    }
                }
                return .Empty
            }
            .responseError {_ in
                let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorBadURL, userInfo: nil)
                self.didFetch(nil, URL: URL, error: error, completion: completion)
            }
            .resume()
    }
    
    func didFetch(data: NSData?, URL: NSURL, error: NSError?, completion: FetchURLCompletionClosure) {
        if let data = data {
            memoryCache.store(data, key: URL.absoluteString)
        }
        completion(data, error)
    }
    
}

