//
//  VideoCacheFragment.swift
//  VideoCache
//
//  Created by SoalHunag on 2019/12/13.
//  Copyright © 2019 soso. All rights reserved.
//

import Foundation

public enum VideoCacheFragment {
    
    case prefix(VideoRangeBounds)
    case suffix(VideoRangeBounds)
    case range(VideoRange)
}

extension VideoCacheFragment {
    
    func ranges(for totalLength: VideoRangeBounds) -> VideoRange {
        switch self {
        case .prefix(let bounds):   return 0...bounds
        case .suffix(let bounds):   return max(0, totalLength - bounds)...totalLength
        case .range(let range):     return range
        }
    }
}
