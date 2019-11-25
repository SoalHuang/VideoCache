//
//  VideoCacheManager.swift
//  VideoCache
//
//  Created by SoalHunag on 2019/2/21.
//  Copyright © 2019 soso. All rights reserved.
//

import Foundation
import UIKit

enum BoolValues {
    
    case `default`(Bool)
    case auto(Bool)
    case manual(Bool)
    
    var value: Bool {
        switch self {
        case .default(let b):   return b
        case .auto(let b):      return b
        case .manual(let b):    return b
        }
    }
}

let FileM = FileManager.default

public class VideoCacheManager: NSObject {
    
    /// shared instance
    public static let `default` = VideoCacheManager()
    
    /// default NSTemporaryDirectory/VideoCache/
    public let directory: String
    
    /// default 1GB
    public var capacityLimit: Int64 = Int64(1).GB {
        didSet { checkAllow() }
    }
    
    /// default nil, fileName is original value
    public var fileNameConvertion: ((_ identifier: String) -> String)?
    
    /// default false
    public var isAutoCheckUsage: Bool = false
    
    /// default true
    public var allowWrite: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return allowWrite_.value
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            allowWrite_ = .manual(newValue)
        }
    }
    
    public var lruConfig: VideoLRUConfigurationType {
        return lru
    }
    
    private var allowWrite_: BoolValues = .default(true)
    
    /// default none
    public var logLevel: VideoCacheLogLevel {
        get { return videoCacheLogLevel }
        set { videoCacheLogLevel = newValue }
    }
    
    /// time default 2, use default 1
    public func setWeight(time: Int, use: Int) {
        lru.timeWeight = time
        lru.useWeight = use
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: VideoFileHandle.didSynchronizeNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    /// path default NSTemporaryDirectory/VideoCache
    public init(directory path: String = NSTemporaryDirectory().appending("/VideoCache")) {
        
        directory = path
        
        super.init()
        
        createCacheDirectory()
        
        checkAllow()
        
        NotificationCenter.default.addObserver(self, selector: #selector(autoCheckUsage), name: VideoFileHandle.didSynchronizeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    private lazy var lru: VideoLRUConfiguration = {
        let filePath = lruFilePath
        if let lruConfig = VideoLRUConfiguration.read(from: filePath) {
            lruConfig.filePath = filePath
            return lruConfig
        }
        let lruConfig = VideoLRUConfiguration(path: filePath)
        lruConfig.synchronize()
        return lruConfig
    }()
    
    private var lastCheckTimeInterval: TimeInterval = Date().timeIntervalSince1970
    
    private var downloadingUrls_: [String: VURL] = [:]
    
    private let lock = NSLock()
}

extension VideoCacheManager {
    
    private func checkAllow() {
        
        guard isAutoCheckUsage else { return }
        
        VLog(.info, "allow write: \(allowWrite_)")
        
        switch allowWrite_ {
        case .default, .auto:
            if let availableCapacity = UIDevice.current.availableCapacity {
                allowWrite_ = .auto(availableCapacity > capacityLimit)
                VLog(.info, "Auto \(allowWrite ? "enabled" : "disabled") allow write")
            }
        case .manual: break
        }
    }
    
    @objc
    private func appDidBecomeActive() {
        checkAllow()
    }
    
    @objc
    private func autoCheckUsage() {
        
        guard isAutoCheckUsage else { return }
        
        let now = Date().timeIntervalSince1970
        guard now - lastCheckTimeInterval > 10 else { return }
        lastCheckTimeInterval = now
        
        checkUsage()
        checkAllow()
    }
}

extension VideoCacheManager {
    
    private func createCacheDirectory() {
        VLog(.info, "Video Cache directory path: \(directory)")
        if !FileM.fileExists(atPath: directory) {
            do {
                try FileM.createDirectory(atPath: directory, withIntermediateDirectories: true, attributes: nil)
            } catch {
                VLog(.error, "create cache directory error: \(error)")
            }
        }
    }
    
    public func calculateSize() throws -> UInt64 {
        let contents = try FileM.contentsOfDirectory(atPath: directory)
        let calculateContent: (String) -> UInt64 = {
            guard let attributes = try? FileM.attributesOfItem(atPath: self.directory.appending("/\($0)")) else { return 0 }
            return (attributes as NSDictionary).fileSize()
        }
        return contents.reduce(0) { $0 + calculateContent($1) }
    }
    
    /// if cache key is nil, it will be filled by url.absoluteString's md5 string
    public func clean(remote url: URL, cacheKey key: String? = nil) throws {
        let `key` = key ?? url.absoluteString.videoCacheMD5
        let `url` = VURL(cacheKey: key, originUrl: url)
        VLog(.info, "clean: \(url)")
        if let _ = downloadingUrls[url.cacheKey] {
            throw VideoCacheErrors.fileHandleWriting.error
        }
        try FileM.removeItem(atPath: configurationPath(for: url))
        try FileM.removeItem(atPath: videoPath(for: url))
        lru.delete(url: url)
    }
    
    /// clean all cache
    public func cleanAll() throws {
        lru.deleteAll(without: downloadingUrls)
        var downloadingURLs: [String: VURL] = [:]
        downloadingUrls.forEach {
            downloadingURLs[cacheFileName(for: $0.value)] = $0.value
            downloadingURLs[configFileName(for: $0.value)] = $0.value
        }
        let contents = try FileM.contentsOfDirectory(atPath: directory).filter { downloadingURLs[$0] == nil }
        for content in contents {
            try FileM.removeItem(atPath: directory.appending("/\(content)"))
        }
    }
}

extension VideoCacheManager {
    
    func cacheFileNamePrefix(for url: VURL) -> String {
        return fileNameConvertion?(url.cacheKey) ?? url.cacheKey.videoCacheMD5
    }
    
    func cacheFileNamePrefix(for cacheKey: String) -> String {
        return fileNameConvertion?(cacheKey) ?? cacheKey.videoCacheMD5
    }
    
    func cacheFileName(for url: VURL) -> String {
        return cacheFileNamePrefix(for: url).appending(".\(url.originUrl.pathExtension)")
    }
    
    func configFileName(for url: VURL) -> String {
        return cacheFileName(for: url).appending(".\(VideoCacheConfigFileExt)")
    }
    
    func contentFileName(for url: VURL) -> String {
        return url.cacheKey.appending(".data")
    }
    
    func contentFileName(for cacheKey: String) -> String {
        return cacheKey.appending(".data")
    }
}

extension VideoCacheManager {
    
    func use(url: VURL) {
        lru.use(url: url)
    }
    
    var lruFilePath: String {
        return directory.appending("/\(lruFileName).\(VideoCacheConfigFileExt)")
    }
    
    func videoPath(for url: VURL) -> String {
        return directory.appending("/\(cacheFileName(for: url))")
    }
    
    func configurationPath(for url: VURL) -> String {
        return directory.appending("/\(configFileName(for: url))")
    }
    
    func contenInfoPath(for url: VURL) -> String {
        return directory.appending("/\(contentFileName(for: url))")
    }
    
    public func cachedUrl(for cacheKey: String) -> URL? {
        return configuration(for: cacheKey)?.url.includeVideoCacheSchemeUrl
    }
    
    func configuration(for url: VURL) -> VideoConfiguration {
        if let config = NSKeyedUnarchiver.unarchiveObject(withFile: configurationPath(for: url)) as? VideoConfiguration {
            return config
        }
        let newConfig = VideoConfiguration(url: url)
        if let ext = url.originUrl.contentType {
            newConfig.contentInfo.type = ext
        }
        newConfig.synchronize(by: self)
        return newConfig
    }
    
    func contentInfo(for url: VURL) -> ContentInfo? {
        return NSKeyedUnarchiver.unarchiveObject(withFile: contenInfoPath(for: url)) as? ContentInfo
    }
    
    func checkUsage() {
        while let size = try? calculateSize(), size > capacityLimit {
            VLog(.info, "cache total size: \(size)")
            if let oldestUrl = lru.oldestURL(without: downloadingUrls) {
                try? clean(remote: oldestUrl.includeVideoCacheSchemeUrl, cacheKey: oldestUrl.key)
            }
        }
    }
}

extension VideoCacheManager {
    
    func configurationPath(for cacheKey: String) -> String? {
        guard let subpaths = FileM.subpaths(atPath: directory) else { return nil }
        let filePrefix = cacheFileNamePrefix(for: cacheKey)
        guard let configFileName = subpaths.first(where: { $0.contains(filePrefix) && $0.hasSuffix("." + VideoCacheConfigFileExt) }) else { return nil }
        return directory.appending("/\(configFileName)")
    }
    
    func configuration(for cacheKey: String) -> VideoConfiguration? {
        guard let path = configurationPath(for: cacheKey) else { return nil }
        return NSKeyedUnarchiver.unarchiveObject(withFile: path) as? VideoConfiguration
    }
}

extension VideoCacheManager {
    
    func addDownloading(url: VURL) {
        downloadingUrls[url.cacheKey] = url
    }
    
    func removeDownloading(url: VURL) {
        downloadingUrls.removeValue(forKey: url.cacheKey)
    }
    
    private var downloadingUrls: [String: VURL] {
        get {
            lock.lock()
            defer { lock.unlock() }
            return downloadingUrls_
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            downloadingUrls_ = newValue
        }
    }
}
