//
//  VideoCacheManager.swift
//  VideoCache
//
//  Created by SoalHunag on 2019/2/21.
//  Copyright © 2019 soso. All rights reserved.
//

import Foundation
import UIKit

let FileM = FileManager.default

public class VideoCacheManager: NSObject {
    
    /// shared instance
    public static let `default` = VideoCacheManager()
    
    /// default NSTemporaryDirectory/VideoCache/
    public var directory: String = NSTemporaryDirectory().appending("/VideoCache") {
        didSet { createCacheDirectory() }
    }
    
    /// default 1GB
    public var capacityLimit: Int64 = Int64(1).GB
    
    /// default true
    public var isAllowWrite: Bool = true
    
    /// default none
    public var logLevel: VideoCacheLogLevel {
        get { return videoCacheLogLevel }
        set { videoCacheLogLevel = newValue }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    override init() {
        super.init()
        
        createCacheDirectory()
        
        if isAllowWrite, let availabelSize = UIDevice.diskAvailableSize {
            VLog(.info, "Device availabelSize is \(availabelSize / Int64(1).MB) MB")
            isAllowWrite = availabelSize > Int64(1).GB
            VLog(.info, "Auto \(isAllowWrite ? "enabled" : "disabled") allow write")
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    private var downloadingUrls_: [String: VURL] = [:]
    
    private let lock = NSLock()
}

extension VideoCacheManager {
    
    @objc
    private func appDidBecomeActive() {
        if isAllowWrite, let availabelSize = UIDevice.diskAvailableSize {
            isAllowWrite = availabelSize > Int64(1).GB
            VLog(.info, "Auto \(isAllowWrite ? "enabled" : "disabled") allow write")
        }
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
    
    /// if cache key is nil, it will be filled by url.absoluteString's md5 string
    public func clean(remote url: URL, cacheKey key: String? = nil) throws {
        let `key` = key ?? url.absoluteString.CMD5
        let `url` = VURL(cacheKey: key, originUrl: url)
        VLog(.info, "clean: \(url)")
        if let _ = downloadingUrls[url.cacheKey] {
            throw VideoCacheErrors.fileHandleWriting.error
        }
        try FileM.removeItem(atPath: configurationPath(for: url))
        try FileM.removeItem(atPath: videoPath(for: url))
    }
    
    /// clean all cache
    public func cleanAll() throws {
        var downloadingMD5: [String: VURL] = [:]
        downloadingUrls.forEach {
            downloadingMD5[$0.value.cacheFileName] = $0.value
            downloadingMD5[$0.value.configFileName] = $0.value
        }
        let contents = try FileM.contentsOfDirectory(atPath: directory).filter { downloadingMD5[$0] == nil }
        for content in contents {
            try FileM.removeItem(atPath: directory.appending("/\(content)"))
        }
    }
}

extension VideoCacheManager {
    
    func videoPath(for url: VURL) -> String {
        return directory.appending("/\(url.cacheFileName)")
    }
    
    func configurationPath(for url: VURL) -> String {
        return directory.appending("/\(url.configFileName)")
    }
    
    func configuration(for url: VURL) -> VideoConfiguration {
        if let config = NSKeyedUnarchiver.unarchiveObject(withFile: configurationPath(for: url)) as? VideoConfiguration {
            return config
        }
        let newConfig = VideoConfiguration(url: url)
        if let ext = url.originUrl.contentType {
            newConfig.contentInfo.type = ext
        }
        newConfig.synchronize()
        return newConfig
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
