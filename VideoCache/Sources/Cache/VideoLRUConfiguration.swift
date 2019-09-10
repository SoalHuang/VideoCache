//
//  VideoLRUConfiguration.swift
//  VideoCache
//
//  Created by SoalHunag on 2019/2/27.
//  Copyright © 2019 soso. All rights reserved.
//

import Foundation

let lruFileName = "lru"

extension VideoLRUConfiguration {
    
    func use(url: VURL) {
        VLog(.info, "use url: \(url)")
        lock.lock()
        defer { lock.unlock() }
        if  let content = contentMap[url.cacheKey] {
            content.use()
        } else {
            let content = LRUContent(url: url)
            contentMap[url.cacheKey] = content
        }
        synchronize()
    }
    
    func delete(url: VURL) {
        VLog(.info, "delete url: \(url)")
        lock.lock()
        defer { lock.unlock() }
        contentMap.removeValue(forKey: url.cacheKey)
        synchronize()
    }
    
    func deleteAll(without downloading: [String: VURL]) {
        lock.lock()
        defer { lock.unlock() }
        contentMap = contentMap.filter { downloading[$0.key] != nil }
        synchronize()
    }
    
    func synchronize() {
        NSKeyedArchiver.archiveRootObject(self, toFile: filePath)
    }
}

extension VideoLRUConfiguration {
    /*
     time weight is 2, use weight is 1,
     time sort:     [A, B, C, D, E, F]
     time weight:   [A(1), B(2), C(3), D(4), E(5), F(6)]
     use sort:      [C, E, D, F, A, B]
     use weight:    [C(2), E(4), D(6), F(8), A(10), B(12)]
     combine:       [A(1 + 10), B(2 + 12), C(3 + 2), D(4 + 6), E(5 + 4), F(6 + 8)]
     result:        [A(11), B(14), C(5), D(10), E(9), F(14)]
     result sort:   [C(5), E(9), D(10), A(11), B(14), F(14)]
     oldest:        C(5)
     */
    func oldestURL(without downloading: [String: VURL]) -> VURL? {
        lock.lock()
        defer { lock.unlock() }
        let urls = contentMap.filter { downloading[$0.key] == nil }.values
        VLog(.info, "urls: \(urls)")
        guard urls.count > 1 else { return urls.first?.url }
        urls.sorted { $0.time < $1.time }.enumerated().forEach { $0.element.weight += ($0.offset + 1) * timeWeight }
        urls.sorted { $0.count < $1.count }.enumerated().forEach { $0.element.weight += ($0.offset + 1) * useWeight }
        return urls.sorted(by: { $0.weight < $1.weight }).first?.url
    }
}

class VideoLRUConfiguration: NSObject, NSCoding {
    
    var timeWeight: Int = 2
    var useWeight: Int = 1
    
    private let filePath = VideoCacheManager.default.lruFilePath
    
    private var contentMap: [String: LRUContent] = [:]
    
    required init?(coder aDecoder: NSCoder) {
        super.init()
        timeWeight = aDecoder.decodeInteger(forKey: "timeWeight")
        useWeight = aDecoder.decodeInteger(forKey: "useWeight")
        contentMap = (aDecoder.decodeObject(forKey: "map") as? [String: LRUContent]) ?? [:]
    }
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(timeWeight, forKey: "timeWeight")
        aCoder.encode(useWeight, forKey: "useWeight")
        aCoder.encode(contentMap, forKey: "map")
    }
    
    override init() {
        super.init()
    }
    
    private let lock = NSLock()
}

extension LRUContent {
    
    func use() {
        time = Date().timeIntervalSince1970
        count += 1
    }
}

class LRUContent: NSObject, NSCoding {
    
    var time: TimeInterval = Date().timeIntervalSince1970
    
    var count: Int = 1
    
    var weight: Int = 0
    
    let url: VURL
    
    init(url: VURL) {
        self.url = url
        super.init()
    }
    
    override var description: String {
        return ["time": time, "count": count, "weight": weight, "url": url].description
    }
    
    required init?(coder aDecoder: NSCoder) {
        url = aDecoder.decodeObject(forKey: "url") as! VURL
        super.init()
        time = aDecoder.decodeDouble(forKey: "time")
        count = aDecoder.decodeInteger(forKey: "count")
    }
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(url, forKey: "url")
        aCoder.encode(time, forKey: "time")
        aCoder.encode(count, forKey: "count")
    }
}
