//
//  Range+Ext.swift
//  VideoCache
//
//  Created by SoalHunag on 2019/2/25.
//  Copyright © 2019 soso. All rights reserved.
//

import Foundation

public extension Range {
    
    init(_ lower: Bound, _ upper: Bound) {
        self.init(uncheckedBounds: (lower, upper))
    }
}

public extension ClosedRange {
    
    init(_ lower: Bound, _ upper: Bound) {
        self.init(uncheckedBounds: (lower, upper))
    }
}

extension ClosedRange where Bound == Int64 {
    
    var range: CodingRange {
        return CodingRange(lowerBound: lowerBound, upperBound: upperBound)
    }
    
    init(range: CodingRange) {
        self.init(uncheckedBounds: (range.lowerBound, range.upperBound))
    }
}

extension ClosedRange where Bound == Int64 {
    
    var isValid: Bool {
        return lowerBound != upperBound
    }
    
    var length: Bound {
        return Bound(count) - 1
    }
}

extension ClosedRange where Bound == Int64 {
    
    func union(_ other: ClosedRange) -> ClosedRange {
        let lowerBound = Swift.min(self.lowerBound, other.lowerBound)
        let upperBound = Swift.max(self.upperBound, other.upperBound)
        return ClosedRange(lowerBound, upperBound)
    }
    
    func subtracting(range: ClosedRange) -> [ClosedRange] {
        if self ~= range.lowerBound, self ~= range.upperBound {
            let fr = ClosedRange(lowerBound, range.lowerBound)
            let lr = ClosedRange(range.upperBound, upperBound)
            return [fr, lr].filter { $0.isValid }
        } else if self ~= range.lowerBound {
            let r = ClosedRange(lowerBound, range.lowerBound)
            return [r].filter { $0.isValid }
        } else if self ~= range.upperBound {
            let r = ClosedRange(range.upperBound, upperBound)
            return [r].filter { $0.isValid }
        }
        return []
    }
    
    func subtracting(ranges: [ClosedRange]) -> [ClosedRange] {
        if ranges.count == 1 {
            return subtracting(range: ranges.first!)
        }
        let sorted = ranges.sorted { $0.lowerBound < $1.lowerBound }
        var result: [ClosedRange] = []
        
        var offset = lowerBound
        sorted.enumerated().forEach {
            let lower = $0.element.lowerBound
            let upper = $0.element.upperBound
            if $0.offset == 0 {
                if offset < lower {
                    result.append(ClosedRange(offset, lower))
                }
                offset = upper
            } else {
                result.append(ClosedRange(offset, lower))
                offset = upper
            }
            if $0.offset == sorted.count - 1 {
                if offset > upper {
                    result.append(ClosedRange(upper, offset))
                }
                offset = upper
            }
        }
        
        return result.filter { $0.isValid }
    }
    
    func split(limit: Bound) -> [ClosedRange] {
        guard limit > 0 else { return [self] }
        let num = Bound(count) / limit
        return (0...num).compactMap { ClosedRange(lowerBound + $0 * limit, Swift.min(upperBound, lowerBound + ($0 + 1) * limit)) }
    }
}
