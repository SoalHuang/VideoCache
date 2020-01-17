//
//  VideoCachePaths.swift
//  VideoCache
//
//  Created by SoalHunag on 2019/11/26.
//  Copyright © 2019 soso. All rights reserved.
//

import Foundation

struct VideoCachePaths {
    
    var directory: String
    var convertion: ((_ identifier: String) -> String)?
    
    init(directory: String, convertion: ((_ identifier: String) -> String)? = nil) {
        self.directory = directory
        self.convertion = convertion
    }
}

extension VideoCachePaths {
    
    func cacheFileNamePrefix(for url: VideoURLType) -> String {
        return convertion?(url.key) ?? url.key
    }
    
    func cacheFileNamePrefix(for cacheKey: VideoCacheKeyType) -> String {
        return convertion?(cacheKey) ?? cacheKey
    }
    
    func cacheFileName(for url: VideoURLType) -> String {
        return cacheFileNamePrefix(for: url).appending(".\(url.url.pathExtension)")
    }
    
    func configFileName(for url: VideoURLType) -> String {
        return cacheFileName(for: url).appending(".\(VideoCacheConfigFileExt)")
    }
    
    func contentFileName(for url: VideoURLType) -> String {
        return url.key.appending(".data")
    }
    
    func contentFileName(for cacheKey: VideoCacheKeyType) -> String {
        return cacheKey.appending(".data")
    }
}

extension VideoCachePaths {
    
    func lruFilePath() -> String {
        return directory.appending("/\(lruFileName).\(VideoCacheConfigFileExt)")
    }
    
    func videoPath(for url: VideoURLType) -> String {
        return directory.appending("/\(cacheFileName(for: url))")
    }
    
    func configurationPath(for url: VideoURLType) -> String {
        return directory.appending("/\(configFileName(for: url))")
    }
    
    func contenInfoPath(for url: VideoURLType) -> String {
        return directory.appending("/\(contentFileName(for: url))")
    }
    
    public func cachedUrl(for cacheKey: VideoCacheKeyType) -> URL? {
        return configuration(for: cacheKey)?.url.includeVideoCacheSchemeUrl
    }
    
    func configuration(for url: VideoURLType) -> VideoConfiguration {
        if let config = NSKeyedUnarchiver.unarchiveObject(withFile: configurationPath(for: url)) as? VideoConfiguration {
            return config
        }
        let newConfig = VideoConfiguration(url: url)
        if let ext = url.url.contentType {
            newConfig.contentInfo.type = ext
        }
        newConfig.synchronize(to: configurationPath(for: url))
        return newConfig
    }
    
    func contentInfoIsExists(for url: VideoURLType) -> Bool {
        let path = contenInfoPath(for: url)
        return FileM.fileExists(atPath: path)
    }
    
    func contentInfo(for url: VideoURLType) -> ContentInfo? {
        
        let path = contenInfoPath(for: url)
        
        guard
            let jsonData = try? Data(contentsOf: URL(fileURLWithPath: path)),
            let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: [.fragmentsAllowed, .mutableContainers, .mutableLeaves]),
            let jsonKeyValues = jsonObject as? Dictionary<String, Any>
            else { return nil }
        
        guard
            let type = jsonKeyValues["type"] as? String,
            let totalLength = jsonKeyValues["totalLength"] as? Int64
            else { return nil }
        
        let info = ContentInfo(type: type, byteRangeAccessSupported: true, totalLength: totalLength)
        
        return info
    }
}

extension VideoCachePaths {
    
    func configurationPath(for cacheKey: VideoCacheKeyType) -> String? {
        guard let subpaths = FileM.subpaths(atPath: directory) else { return nil }
        let filePrefix = cacheFileNamePrefix(for: cacheKey)
        guard let configFileName = subpaths.first(where: { $0.contains(filePrefix) && $0.hasSuffix("." + VideoCacheConfigFileExt) }) else { return nil }
        return directory.appending("/\(configFileName)")
    }
    
    func configuration(for cacheKey: VideoCacheKeyType) -> VideoConfigurationType? {
        guard let path = configurationPath(for: cacheKey) else { return nil }
        return NSKeyedUnarchiver.unarchiveObject(withFile: path) as? VideoConfigurationType
    }
}
