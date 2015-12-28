//
//  NSURLCache+THGWebService.swift
//  SwallowExample
//
//  Created by Sam Grover on 11/19/15.
//  Copyright © 2015 TheHolyGrail. All rights reserved.
//

import Foundation

// Ported from: https://github.com/walmartlabs-wmusiphone/ios-shared/blob/master/Source/WebServices/NSURLCache%2BSDExtensions.m

extension NSURLCache {
    
    static func createDateFormatter(format: String) -> NSDateFormatter {
        let dateFormatter = NSDateFormatter()
        dateFormatter.locale = NSLocale(localeIdentifier: "en_US")
        dateFormatter.timeZone = NSTimeZone(abbreviation: "GMT")
        dateFormatter.dateFormat = format
        return dateFormatter
    }
    
    // Default cache expiration delay if none defined (1 hour)
    @nonobjc static let DefaultCacheExpirationDelay: NSTimeInterval = 3600
    
    // Fraction to calculate age. 10% since Last-Modified suggested by RFC2616 section 13.2.4
    @nonobjc static let CacheLastModifiedFraction: NSTimeInterval = 0.1
    
    // Only responses with these codes are allowed to affect caching logic. Using these verbatim from older Obj-C code.
    @nonobjc static let ResponseStatusCodesUsableWithCachingLogic = [200, 203, 300, 301, 302, 307, 410]
    
    // Do not use heuristics or defaults to define an expiration date for these response codes. Using these verbatim from older Obj-C code.
    @nonobjc static let ResponseStatusCodesUnusableWithoutExplicitCache = [302, 307]
    
    // RFC 1123 date format - Sun, 06 Nov 1994 08:49:37 GMT
    @nonobjc static let RFC1123DateFormatter = NSURLCache.createDateFormatter("EEE, dd MMM yyyy HH:mm:ss z")
    
    // ANSI C date format - Sun Nov  6 08:49:37 1994
    @nonobjc static let ANSICDateFormatter = NSURLCache.createDateFormatter("EEE MMM d HH:mm:ss yyyy")
    
    // RFC 850 date format - Sunday, 06-Nov-94 08:49:37 GMT
    @nonobjc static let RFC850DateFormatter = NSURLCache.createDateFormatter("EEEE, dd-MMM-yy HH:mm:ss z")
    
    enum ExtractableHeaderDate { case Fetch, Expiration }
    
    /*
    * Parse HTTP Date: http://www.w3.org/Protocols/rfc2616/rfc2616-sec3.html#sec3.3.1
    */
    public class func dateFromHttpDateString(httpDate: String) -> NSDate? {
        if let rfc1123Date = RFC1123DateFormatter.dateFromString(httpDate) {
            return rfc1123Date
        }
        
        if let ansiCDate = ANSICDateFormatter.dateFromString(httpDate) {
            return ansiCDate
        }
        
        if let rfc850Date = RFC850DateFormatter.dateFromString(httpDate) {
            return rfc850Date
        }
        
        return nil
    }
    
    public class func fetchDateFrom(headers: [NSObject : AnyObject], status: Int) -> NSDate? {
        return NSURLCache.extractDate(.Fetch, headers: headers, status: status)
    }
    
    public class func expirationDateFrom(headers: [NSObject : AnyObject], status: Int) -> NSDate? {
        return NSURLCache.extractDate(.Expiration, headers: headers, status: status)
    }
    
    /// Returns `true` if the URL is in the cache and valid i.e. non-expired.
    public func isCachedAndValid(request: NSURLRequest) -> Bool {
        let urlCache = NSURLCache.sharedURLCache()
        
        // Make sure there's a cached response before continuing further
        guard let cachedResponse = urlCache.cachedResponseForRequest(request) else {
            return false
        }
        
        if let httpResponse = cachedResponse.response as? NSHTTPURLResponse {
            if let expirationDate = NSURLCache.expirationDateFrom(httpResponse.allHeaderFields, status: httpResponse.statusCode) {
                if expirationDate.timeIntervalSinceNow > 0 {
                    return true
                }
            }
        }
        return false
    }
    
    public func validCachedResponseForRequest(request: NSURLRequest) -> NSCachedURLResponse? {
        return self.validCachedResponseForRequest(request, timeToLive: 0, removeIfInvalid: false)
    }
    
    public func validCachedResponseForRequest(request: NSURLRequest, timeToLive: NSTimeInterval, removeIfInvalid: Bool) -> NSCachedURLResponse? {
        let urlCache = NSURLCache.sharedURLCache()
        
        // Make sure there's a cached response before continuing further
        guard let cachedResponse = urlCache.cachedResponseForRequest(request) else {
            return nil
        }
        
        if let httpResponse = cachedResponse.response as? NSHTTPURLResponse {
            if let expirationDate = NSURLCache.expirationDateFrom(httpResponse.allHeaderFields, status: httpResponse.statusCode) {
                if expirationDate.timeIntervalSinceNow > 0 {
                    return cachedResponse
                }
            } else if timeToLive > 0 {
                if let fetchDate = NSURLCache.fetchDateFrom(httpResponse.allHeaderFields, status: httpResponse.statusCode) {
                    let timePassed = NSDate().timeIntervalSinceDate(fetchDate)
                    if timePassed < timeToLive {
                        return cachedResponse
                    }
                }
            }
        }
        
        // if we get here, it didn't pass our validation checks.  forcibly remove it.
        // Only call removeCachedResponseForRequest if there is a response in order to try and work around iOS 7 removeAllCachedResponses bug
        if removeIfInvalid && request.isValid() {
            urlCache.removeCachedResponseForRequest(request)
        }
        
        return nil
    }
    
    class func extractDate(extractableHeaderDateType: ExtractableHeaderDate, headers: [NSObject : AnyObject], status: Int) -> NSDate? {
        if !ResponseStatusCodesUsableWithCachingLogic.contains(status) {
            return nil
        }
        
        if let pragma = headers["Pragma"] as? String {
            if pragma == "no-cache" {
                // Uncacheaable response
                return nil
            }
        }
        
        // Define "now" based on the request, if available
        var now: NSDate = NSDate()
        if let dateString = headers["Date"] as? String {
            if let extractedDate = NSURLCache.dateFromHttpDateString(dateString) {
                now = extractedDate
            }
        }
        
        switch(extractableHeaderDateType) {
        case .Fetch:
            return now
        case .Expiration:
            return NSURLCache.extractOrCreateExpirationDateFrom(headers, status: status, now: now)
        }
    }
    
    class func extractOrCreateExpirationDateFrom(headers: [NSObject : AnyObject], status: Int, now: NSDate) -> NSDate? {
        // Look at info from the Cache-Control: max-age=n header
        if let cacheControl = headers["Cache-Control"] as? String {
            var foundRange = cacheControl.rangeOfString("no-store")
            if foundRange?.count > 0 {
                return nil
            }
            
            foundRange = cacheControl.rangeOfString("max-age=")
            if let foundRange = foundRange {
                if foundRange.count > 0 {
                    var maxAge = 0
                    let cacheControlScanner = NSScanner(string: cacheControl)
                    cacheControlScanner.scanLocation = foundRange.startIndex.distanceTo(foundRange.endIndex)
                    if cacheControlScanner.scanInteger(&maxAge) {
                        if maxAge > 0 {
                            return NSDate(timeInterval: NSTimeInterval(maxAge), sinceDate: now)
                        } else {
                            return nil
                        }
                    }
                }
            }
        }
        
        // If no Cache-Control found, look at the Expires header
        if let expires = headers["Expires"] as? String {
            var expirationInterval: NSTimeInterval = 0
            
            if let expirationDate = NSURLCache.dateFromHttpDateString(expires) {
                expirationInterval = expirationDate.timeIntervalSinceDate(now)
            }
            
            if expirationInterval > 0 {
                // Convert remote expiration date to local expiration date
                return NSDate(timeIntervalSinceNow: expirationInterval)
            } else {
                return nil
            }
        }
        
        if ResponseStatusCodesUnusableWithoutExplicitCache.contains(status) {
            return nil
        }
        
        // If no cache control defined, try some heuristic to determine an expiration date
        if let lastModified = headers["Last-Modified"] as? String {
            var age: NSTimeInterval = 0
            if let lastModifiedDate = NSURLCache.dateFromHttpDateString(lastModified) {
                // Define the age of the document by comparing the Date header with the Last-Modified header
                age = now.timeIntervalSinceDate(lastModifiedDate)
                if age > 0 {
                    return NSDate(timeIntervalSinceNow: age * NSURLCache.CacheLastModifiedFraction)
                } else {
                    return nil
                }
            }
        }
        
        // If nothing permitted to define the cache expiration delay nor to restrict its cacheability, use a default cache expiration delay
        return NSDate(timeInterval: NSURLCache.DefaultCacheExpirationDelay, sinceDate: now)
    }
    
}

