//
//  CodingRange.swift
//  VideoCache
//
//  Created by SoalHunag on 2019/3/15.
//  Copyright © 2019 soso. All rights reserved.
//

import Foundation

typealias VideoRangeBounds = Int64
typealias VideoRange = ClosedRange<VideoRangeBounds>

class CodingRange: NSObject, NSCoding {
    
    var lowerBound: VideoRangeBounds
    var upperBound: VideoRangeBounds
    
    init(lowerBound: VideoRangeBounds, upperBound: VideoRangeBounds) {
        self.lowerBound = lowerBound
        self.upperBound = upperBound
    }
    
    required init?(coder aDecoder: NSCoder) {
        lowerBound = aDecoder.decodeInt64(forKey: "lowerBound")
        upperBound = aDecoder.decodeInt64(forKey: "upperBound")
    }
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(lowerBound, forKey: "lowerBound")
        aCoder.encode(upperBound, forKey: "upperBound")
    }
    
    override var description: String {
        return "(\(lowerBound)...\(upperBound))"
    }
}
