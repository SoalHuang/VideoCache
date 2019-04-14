//
//  Array+Ext.swift
//  VideoCache
//
//  Created by SoalHunag on 2019/2/25.
//  Copyright © 2019 soso. All rights reserved.
//

import Foundation

extension Array where Element == VideoRange {
    
    func split(limit: VideoRange.Bound) -> [Element] {
        var ranges: [VideoRange] = []
        forEach { ranges.append(contentsOf: $0.split(limit: limit)) }
        return ranges
    }
    
    func overlaps(_ other: Element) -> [Element] {
        return filter { $0.overlaps(other) }
    }
    
    func union(_ other: Element) -> [Element] {
        
        var temp = self
        
        guard count > 0 else {
            temp.append(other)
            return temp
        }
        
        var overlapOffsets = temp.enumerated().compactMap { $1.overlaps(other) ? $0 : nil }
        
        if overlapOffsets.count == 0 {
            
            temp.append(other)
            temp.sort { $0.lowerBound < $1.lowerBound }
            
        } else if overlapOffsets.count > 1 {
            
            let lowerIndex = overlapOffsets.first!
            let upperIndex = overlapOffsets.last!
            
            let first = temp[lowerIndex]
            let last = temp[upperIndex]
            
            let lowerBound = Swift.min(first.lowerBound, other.lowerBound)
            let upperBound = Swift.max(last.upperBound, other.upperBound)
            
            let combine = VideoRange(lowerBound, upperBound)
            
            overlapOffsets.reverse()
            overlapOffsets.forEach { temp.remove(at: $0) }
            
            temp.insert(combine, at: lowerIndex)
            
        } else if overlapOffsets.count == 1 {
            
            let overlapIndex = overlapOffsets.first!
            let overlapRange = temp[overlapIndex]
            
            let lowerBound = Swift.min(overlapRange.lowerBound, other.lowerBound)
            let upperBound = Swift.max(overlapRange.upperBound, other.upperBound)
            
            let combine = VideoRange(lowerBound, upperBound)
            
            temp.remove(at: overlapIndex)
            temp.insert(combine, at: overlapIndex)
        }
        return temp
    }
}
