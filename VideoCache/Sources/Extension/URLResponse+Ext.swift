//
//  URLResponse+Ext.swift
//  VideoCache
//
//  Created by SoalHunag on 2019/2/22.
//  Copyright © 2019 soso. All rights reserved.
//

import Foundation
import MobileCoreServices

extension URLResponse {
    
    var isMediaSource: Bool {
        guard let mime = mimeType else { return false }
        return mime.contains("video/") || mime.contains("audio/") || mime.contains("application")
    }
    
    var contentType: String? {
        guard let type = mimeType else { return nil }
        return UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, type as CFString, nil)?.takeRetainedValue() as String?
    }
    
    var contentLength: Int64? {
        guard let response = self as? HTTPURLResponse else { return nil }
        let allHeaderFields = response.allHeaderFields as NSDictionary
        guard let lengthValue = allHeaderFields.contentLengthValue else { return nil }
        return Int64(lengthValue) ?? Int64((lengthValue as NSString).integerValue)
    }
    
    var contentRange: (VideoRange, VideoRangeBounds)? {
        
        guard let response = self as? HTTPURLResponse else { return nil }
        
        let allHeaderFields = response.allHeaderFields as NSDictionary
        
        guard let contentRange = allHeaderFields.contentRangeValue else { return nil }
        
        let components = contentRange.components(separatedBy: "/")
        guard components.count == 2 else { return nil }
        
        let firstComponent = components.first!
        let lastComponent = components.last!
        
        let typeComponents = firstComponent.components(separatedBy: .whitespaces)
        guard typeComponents.count == 2 else { return nil }
        
//        let rangeType = typeComponents.first!
        
        let rangeComponents = typeComponents.last!.components(separatedBy: "-")
        guard rangeComponents.count == 2 else { return nil }
        
        let rangeFirst = rangeComponents.first!
        let rangeLast = rangeComponents.last!
        
        let rangeStart = Int64(rangeFirst) ?? Int64((rangeFirst as NSString).integerValue)
        let rangeEnd = Int64(rangeLast) ?? Int64((rangeLast as NSString).integerValue)
        let totalLength = Int64(lastComponent) ?? Int64((lastComponent as NSString).integerValue)
        
        return (VideoRange(rangeStart, rangeEnd), totalLength)
    }
    
    var isByteRangeAccessSupported: Bool {
        guard
            let response = self as? HTTPURLResponse,
            let acceptRanges = (response.allHeaderFields as NSDictionary).acceptRangesValue
            else { return false }
        return acceptRanges.lowercased().contains("bytes".lowercased())
    }
}

extension NSDictionary {
    
    func findKey(for key: String) -> Any? {
        return allKeys.first(where: { "\($0)".lowercased() == key.lowercased() })
    }
    
    var contentLengthValue: String? {
        guard let key = findKey(for: "content-length") else { return nil }
        return self[key] as? String
    }
    
    var contentRangeValue: String? {
        guard let key = findKey(for: "content-range") else { return nil }
        return self[key] as? String
    }
    
    var acceptRangesValue: String? {
        guard let key = findKey(for: "accept-ranges") else { return nil }
        return self[key] as? String
    }
}
