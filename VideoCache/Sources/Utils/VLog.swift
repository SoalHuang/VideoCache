//
//  VLog.swift
//  VideoCache
//
//  Created by SoalHunag on 2019/2/27.
//  Copyright © 2019 soso. All rights reserved.
//

import Foundation

public enum VideoCacheLogLevel: UInt {
    
    case none, error, info, request, data
    
    var description: String {
        switch self {
        case .none:     return "NONE"
        case .error:    return "ERROR"
        case .info:     return "INFO"
        case .request:  return "REQUEST"
        case .data:     return "DATA"
        }
    }
}

var videoCacheLogLevel: VideoCacheLogLevel = .none

private let logQueue = DispatchQueue(label: "com.video.cache.log.queue")

func VLog(file: String = #file, line: Int = #line, fun: String = #function, _ level: VideoCacheLogLevel, _ message: Any) {
    guard level.rawValue <= videoCacheLogLevel.rawValue else { return }
    logQueue.async {
        Swift.print("[Video Cache] [\(level.description)] file: \(file.components(separatedBy: "/").last ?? "none"), line: \(line), func: \(fun): \(message)")
    }
}
