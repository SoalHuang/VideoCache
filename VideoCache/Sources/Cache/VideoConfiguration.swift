//
//  Configuration.swift
//  VideoCache
//
//  Created by SoalHunag on 2019/2/21.
//  Copyright © 2019 soso. All rights reserved.
//

import Foundation

protocol VideoConfigurationType: NSObjectProtocol {
    
    var url: VideoURL { get }
    
    var contentInfo: ContentInfo { get set }
    
    var reservedLength: VideoRangeBounds { get set }
    
    var fragments: [VideoRange] { get }
    
    func overlaps(_ other: VideoRange) -> [VideoRange]
    
    func reset(fragment: VideoRange)
    
    func add(fragment: VideoRange)
    
    @discardableResult
    func synchronize(to path: String) -> Bool
}

class VideoConfiguration: NSObject, NSCoding {
    
    let url: VideoURL
    
    var contentInfo: ContentInfo = ContentInfo(totalLength: 0)
    
    var reservedLength: VideoRangeBounds = 0
    
    var fragments: [VideoRange] = []
    
    var lastTimeInterval: TimeInterval = Date().timeIntervalSince1970
    
    required init?(coder aDecoder: NSCoder) {
        url = aDecoder.decodeObject(forKey: "url") as! VideoURL
        super.init()
        contentInfo = aDecoder.decodeObject(forKey: "contentInfo") as! ContentInfo
        reservedLength = aDecoder.decodeInt64(forKey: "reservedLength")
        lastTimeInterval = aDecoder.decodeDouble(forKey: "lastTimeInterval")
        
        if let frags = aDecoder.decodeObject(forKey: "fragments") as? [CodingRange] {
            fragments = frags.compactMap { VideoRange(range: $0) }
        }
    }
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(url, forKey: "url")
        aCoder.encode(contentInfo, forKey: "contentInfo")
        aCoder.encode(reservedLength, forKey: "reservedLength")
        aCoder.encode(lastTimeInterval, forKey: "lastTimeInterval")
        aCoder.encode(fragments.compactMap { $0.range }, forKey: "fragments")
    }
    
    init(url: VideoURLType) {
        self.url = VideoURL(cacheKey: url.key, originUrl: url.url)
        super.init()
    }
    
    private let lock = NSLock()
    
    override var description: String {
        return ["url": url, "contentInfo": contentInfo, "reservedLength": reservedLength, "lastTimeInterval": lastTimeInterval, "fragments": fragments].description
    }
}

extension VideoConfiguration: VideoConfigurationType {
    
    @discardableResult
    func synchronize(to path: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        lastTimeInterval = Date().timeIntervalSince1970
        return NSKeyedArchiver.archiveRootObject(self, toFile: path)
    }
    
    func overlaps(_ range: VideoRange) -> [VideoRange] {
        lock.lock()
        defer { lock.unlock() }
        return fragments.overlaps(range)
    }
    
    func reset(fragment: VideoRange) {
        VLog(.data, "reset fragment: \(fragment)")
        lock.lock()
        defer { lock.unlock() }
        fragments = [fragment]
    }
    
    func add(fragment: VideoRange) {
        VLog(.data, "add fragment: \(fragment)")
        lock.lock()
        defer { lock.unlock() }
        guard fragment.isValid else { return }
        fragments = fragments.union(fragment)
    }
}
