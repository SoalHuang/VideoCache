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
        guard
            let response = self as? HTTPURLResponse,
            let contentRange = (response.allHeaderFields as NSDictionary).contentRangeValue,
            let contentLengthValue = contentRange.components(separatedBy: "/").last
            else { return nil }
        return Int64(contentLengthValue) ?? Int64((contentLengthValue as NSString).integerValue)
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
    
    var contentRangeValue: String? {
        return (self["Content-Range"] as? String) ?? self["content-range"] as? String
    }
    
    var acceptRangesValue: String? {
        return (self["Accept-Ranges"] as? String) ?? self["accept-ranges"] as? String
    }
}
