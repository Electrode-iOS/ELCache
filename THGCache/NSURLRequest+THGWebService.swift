//
//  NSURLRequest+THGWebService.swift
//  SwallowExample
//
//  Created by Sam Grover on 11/30/15.
//  Copyright © 2015 TheHolyGrail. All rights reserved.
//

import Foundation

// Ported from: https://github.com/walmartlabs-wmusiphone/ios-shared/blob/master/Source/WebServices/NSURLRequest%2BSDExtensions.m

extension NSURLRequest {
    
    /// Returns `true` if the request contains a valid URL that is non-empty and RFC1738-compliant.
    public func isValid() -> Bool {
        let urlValidationExpression = "http(s)?://([\\w-]+\\.)+[\\w-(:)]+(/[\\w-\\+ ./?%&amp;=]*)?"
        let urlValidator = NSPredicate(format: "SELF MATCHES %@", urlValidationExpression)
        
        if let absoluteURLString = URL?.absoluteString {
            if absoluteURLString.characters.count > 0 && urlValidator.evaluateWithObject(absoluteURLString) {
                return true
            }
        }
        return false
    }
    
}

