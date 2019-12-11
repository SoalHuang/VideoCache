//
//  Data+CheckSum.swift
//  VideoCache
//
//  Created by SoalHunag on 2019/12/10.
//  Copyright © 2019 soso. All rights reserved.
//

import Foundation

extension Data {
    
    func checksum(split: VideoRangeBounds = Int64(1).KB, vacuate: VideoRangeBounds? = nil) -> Bool {
        return (self as NSData).checksum(split: split)
    }
}

extension NSData {
    
    func checksum(split: VideoRangeBounds, vacuate: VideoRangeBounds? = nil) -> Bool {
        
        let totalRange = VideoRange(0, VideoRangeBounds(count))
        
        let ranges = totalRange.split(limit: split)
        let vac: VideoRangeBounds = vacuate ?? VideoRangeBounds(sqrt(Double(ranges.count)))
        let results = ranges.enumerated().compactMap { VideoRangeBounds($0.offset) % vac == 0 ? $0.element : nil }
        
        for range in results {
            
            let r = NSRange(location: Int(range.lowerBound), length: Int(range.length))
            
            let data = subdata(with: r)
            
            guard data.count == r.length else {
                return false
            }
            
            let sum: VideoRangeBounds = data.reduce(0) { $0 + VideoRangeBounds($1) }
            
            if sum < r.length {
                return false
            }
        }
        
        return true
    }
}
