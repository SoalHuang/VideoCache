//
//  Error+Ext.swift
//  VideoCache
//
//  Created by SoalHunag on 2019/2/26.
//  Copyright © 2019 soso. All rights reserved.
//

import Foundation

internal let error_domain = "com.video.cache.domain"

enum VideoCacheErrors {
    
    case badUrl
    case dataRequestNull
    case notMedia
    
    case fileHandleWriting
    case cancelled
}

extension VideoCacheErrors {
    
    var code: Int {
        switch self {
        case .badUrl:               return NSURLErrorBadURL
        case .dataRequestNull:      return NSURLErrorUnknown
        case .notMedia:             return NSURLErrorResourceUnavailable
        case .fileHandleWriting:    return NSURLErrorCannotWriteToFile
        case .cancelled:            return NSURLErrorCancelled
        }
    }
    
    var message: String {
        switch self {
        case .badUrl:               return "bad url"
        case .dataRequestNull:      return "data request is null"
        case .notMedia:             return "resource is not media"
        case .fileHandleWriting:    return "file handle writing"
        case .cancelled:            return "cancelled"
        }
    }
}

extension VideoCacheErrors {
    
    var error: Error {
        return NSError(domain: error_domain, code: code, userInfo: [NSURLErrorFailingURLErrorKey : message])
    }
    
    func error(_ msg: String? = nil) -> Error {
        guard let `msg` = msg else { return error }
        return NSError(domain: error_domain, code: code, userInfo: [NSURLErrorFailingURLErrorKey : message,
                                                                    NSLocalizedDescriptionKey: msg])
    }
}
