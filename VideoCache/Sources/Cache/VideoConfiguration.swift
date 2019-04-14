//
//  Configuration.swift
//  VideoCache
//
//  Created by SoalHunag on 2019/2/21.
//  Copyright © 2019 soso. All rights reserved.
//

import Foundation

protocol VideoConfigurationType: NSObjectProtocol {
    
    var filePath: String { get }
    
    var contentInfo: ContentInfo { get set }
    
    func overlaps(_ other: VideoRange) -> [VideoRange]
    
    func add(fragment: VideoRange)
    func synchronize()
}

extension VideoConfigurationType {
    
    var fileName: String {
        return (filePath as NSString).lastPathComponent
    }
}

class VideoConfiguration: NSObject, NSCoding {
    
    let url: VURL
    
    var contentInfo: ContentInfo = ContentInfo(totalLength: 0)
    
    var fragments: [VideoRange] = []
    
    var lastTimeInterval: TimeInterval = Date().timeIntervalSince1970
    
    required init?(coder aDecoder: NSCoder) {
        url = aDecoder.decodeObject(forKey: "url") as! VURL
        super.init()
        contentInfo = aDecoder.decodeObject(forKey: "contentInfo") as! ContentInfo
        lastTimeInterval = aDecoder.decodeDouble(forKey: "lastTimeInterval")
        
        if let frags = aDecoder.decodeObject(forKey: "fragments") as? [CodingRange] {
            fragments = frags.compactMap { VideoRange(range: $0) }
        }
    }
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(url, forKey: "url")
        aCoder.encode(contentInfo, forKey: "contentInfo")
        aCoder.encode(lastTimeInterval, forKey: "lastTimeInterval")
        aCoder.encode(fragments.compactMap { $0.range }, forKey: "fragments")
    }
    
    init(url: VURL) {
        self.url = url
        super.init()
    }
    
    private let lock = NSLock()
    
    override var description: String {
        return ["url": url, "contentInfo": contentInfo, "lastTimeInterval": lastTimeInterval, "fragments": fragments].description
    }
}

extension VideoConfiguration: VideoConfigurationType {
    
    var filePath: String {
        return VideoCacheManager.default.configurationPath(for: url)
    }
    
    func synchronize() {
        lock.lock()
        defer { lock.unlock() }
        lastTimeInterval = Date().timeIntervalSince1970
        NSKeyedArchiver.archiveRootObject(self, toFile: filePath)
    }
    
    func overlaps(_ range: VideoRange) -> [VideoRange] {
        lock.lock()
        defer { lock.unlock() }
        return fragments.overlaps(range)
    }
    
    func add(fragment: VideoRange) {
        VLog(.data, "add fragment: \(fragment)")
        lock.lock()
        defer { lock.unlock() }
        guard fragment.isValid else { return }
        fragments = fragments.union(fragment)
    }
}
