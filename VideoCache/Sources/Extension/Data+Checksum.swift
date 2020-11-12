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
        
        if isEmpty {
            return false
        }
        
        let totalRange = VideoRange(0, VideoRangeBounds(count))
        
        var splitRanges = totalRange.split(limit: split).filter { $0.isValid }
        let vacuateCount: VideoRangeBounds = vacuate ?? VideoRangeBounds(sqrt(Double(splitRanges.count)))
        
        let results: [VideoRange] = (0..<vacuateCount).compactMap { _ in
            let index = Int.random(in: splitRanges.indices)
            return splitRanges.remove(at: index)
        }
        
        for range in results {
            
            let r = NSRange(location: Int(range.lowerBound), length: Int(range.length))
            
            let data = subdata(with: r)
            
            guard data.count == r.length else {
                return false
            }
            
            let sum: VideoRangeBounds = data.reduce(0) { $0 + VideoRangeBounds($1) }
            
            VLog(.data, "sub-range: \(r) checksum: \(sum) --> \(sum < r.length ? "invalid" : "valid")")
            
            if sum < r.length {
                return false
            }
        }
        
        return true
    }
}
