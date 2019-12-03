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
    
    /// shared instance, directory default NSTemporaryDirectory/VideoCache
    public static let `default` = VideoCacheManager(directory: NSTemporaryDirectory().appending("/VideoCache"))
    
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
    public static var logLevel: VideoCacheLogLevel {
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
    
    public init(directory path: String) {
        
        directory = path
        
        super.init()
        
        createCacheDirectory()
        
        checkAllow()
        
        NotificationCenter.default.addObserver(self, selector: #selector(autoCheckUsage), name: VideoFileHandle.didSynchronizeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    private lazy var lru: VideoLRUConfiguration = {
        let filePath = paths.lruFilePath()
        if let lruConfig = VideoLRUConfiguration.read(from: filePath) {
            lruConfig.filePath = filePath
            return lruConfig
        }
        let lruConfig = VideoLRUConfiguration(path: filePath)
        lruConfig.synchronize()
        return lruConfig
    }()
    
    private var lastCheckTimeInterval: TimeInterval = Date().timeIntervalSince1970
    
    private var downloadingUrls_: [String: VideoURLType] = [:]
    
    private let lock = NSLock()
    
    private var reserveRequired = true
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
    public func clean(url: VideoURLType, reserve: Bool = true) throws {
        
        VLog(.info, "clean: \(url)")
        
        if let _ = downloadingUrls[url.key] {
            throw VideoCacheErrors.fileHandleWriting.error
        }
        
        let infoPath = paths.contenInfoPath(for: url)
        let configPath = paths.configurationPath(for: url)
        let videoPath = paths.videoPath(for: url)
        
        let cleanAllClosure = { [weak self] in
            try FileM.removeItem(atPath: infoPath)
            try FileM.removeItem(atPath: configPath)
            try FileM.removeItem(atPath: videoPath)
            self?.lru.delete(url: url)
        }
        
        guard let config = paths.configuration(for: infoPath) else {
            try cleanAllClosure()
            return
        }
        
        let reservedLength = config.reservedLength
        
        guard reservedLength > 0
            else {
            try cleanAllClosure()
            return
        }
        
        guard reserve else {
            try cleanAllClosure()
            return
        }
        
        guard let fileHandle = FileHandle(forUpdatingAtPath: videoPath) else {
            try cleanAllClosure()
            return
        }
        
        do {
            try fileHandle.throwError_truncateFile(atOffset: UInt64(reservedLength))
            try fileHandle.throwError_synchronizeFile()
            try fileHandle.throwError_closeFile()
            try FileM.removeItem(atPath: configPath)
        } catch {
            try cleanAllClosure()
        }
    }
    
    /// clean all cache
    public func cleanAll() throws {
        
        let urls = downloadingUrls
        
        guard urls.count > 0 else {
            try FileM.removeItem(atPath: directory)
            createCacheDirectory()
            return
        }
        
        lru.deleteAll(without: urls)
        
        var downloadingURLs: [String: VideoURLType] = [:]
        urls.forEach {
            downloadingURLs[paths.cacheFileName(for: $0.value)] = $0.value
            downloadingURLs[paths.configFileName(for: $0.value)] = $0.value
            downloadingURLs[paths.contenInfoPath(for: $0.value)] = $0.value
        }
        
        let contents = try FileM.contentsOfDirectory(atPath: directory).filter { downloadingURLs[$0] == nil }
        
        for content in contents {
            try FileM.removeItem(atPath: directory.appending("/\(content)"))
        }
    }
}

extension VideoCacheManager {
    
    func use(url: VideoURLType) {
        lru.use(url: url)
    }
    
    func checkUsage() {
        
        guard let size = try? calculateSize() else { return }
        
        VLog(.info, "cache total size: \(size)")
        
        guard size > capacityLimit else { return }
        
        let oldestUrls = lru.oldestURL(maxLength: 10, without: downloadingUrls)
        
        guard oldestUrls.count > 0 else { return }
        
        oldestUrls.forEach { try? clean(url: $0, reserve: reserveRequired) }
        
        reserveRequired.toggle()
    }
}

extension VideoCacheManager {
    
    var paths: VideoCachePaths {
        return VideoCachePaths(directory: directory, convertion: fileNameConvertion)
    }
}

extension VideoCacheManager {
    
    func addDownloading(url: VideoURLType) {
        downloadingUrls[url.key] = url
    }
    
    func removeDownloading(url: VideoURLType) {
        downloadingUrls.removeValue(forKey: url.key)
    }
    
    public var downloadingUrls: [String: VideoURLType] {
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
