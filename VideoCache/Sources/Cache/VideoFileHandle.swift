//
//  VideoFileHandle.swift
//  VideoCache
//
//  Created by SoalHunag on 2019/2/24.
//  Copyright © 2019 soso. All rights reserved.
//

import Foundation
import UIKit

internal let PacketLimit: Int64 = Int64(1).MB

protocol VideoFileHandleType {
    
    var configuration: VideoConfiguration { get }
    
    func actions(for range: VideoRange) -> [Action]
    
    func readData(for range: VideoRange) throws -> Data
    
    func writeData(data: Data, for range: VideoRange) throws
    
    @discardableResult
    func synchronize(notify: Bool) throws -> Bool
    
    func close() throws
}

extension VideoFileHandleType {
    
    var isNeedUpdateContentInfo: Bool { return configuration.contentInfo.totalLength <= 0 }
}

class VideoFileHandle {
    
    let url: VideoURLType
    
    let paths: VideoCachePaths
    
    let cacheFragments: [VideoCacheFragment]
    
    let filePath: String
    
    let configuration: VideoConfiguration
    
    deinit {
        do {
            try synchronize(notify: false)
            try close()
        } catch {
            VLog(.error, "fileHandle synchronize and close failure: \(error)")
        }
        NotificationCenter.default.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
    }
    
    init(paths: VideoCachePaths, url: VideoURLType, cacheFragments: [VideoCacheFragment]) {
        
        self.paths = paths
        self.url = url
        self.cacheFragments = cacheFragments
        
        filePath = paths.videoPath(for: url)
        
        VLog(.info, "Video path: \(filePath)")
        
        if !FileM.fileExists(atPath: filePath) {
            FileM.createFile(atPath: filePath, contents: nil, attributes: nil)
        }
        
        configuration = paths.configuration(for: url)
        
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }
    
    private lazy var readHandle = FileHandle(forReadingAtPath: filePath)
    private lazy var writeHandle = FileHandle(forWritingAtPath: filePath)
    
    private var isWriting: Bool = false
    
    private let lock = NSLock()
}

extension VideoFileHandle {
    
    static let VideoURLKey: String = "VideoURLKey"
    
    static let didSynchronizeNotification: NSNotification.Name = NSNotification.Name("VideoFileHandle.didSynchronizeNotification")
}

extension VideoFileHandle: VideoFileHandleType {
    
    var contentInfo: ContentInfo {
        get { return configuration.contentInfo }
        set {
            configuration.contentInfo = newValue
            configuration.synchronize(to: paths.configurationPath(for: url))
        }
    }
    
    func actions(for range: VideoRange) -> [Action] {
        
        guard range.isValid else { return [] }
        
        let localRanges = configuration.overlaps(range).compactMap { $0.clamped(to: range) }.split(limit: PacketLimit).filter { $0.isValid }
        
        var actions: [Action] = []
        
        let localActions: [Action] = localRanges.compactMap { .local($0) }
        actions.append(contentsOf: localActions)
        
        guard actions.count > 0 else {
            actions.append(.remote(range))
            return actions
        }
        
        let remoteActions: [Action] = range.subtracting(ranges: localRanges).compactMap { .remote($0) }
        actions.append(contentsOf: remoteActions)
        
        return actions.sorted(by: { $0 < $1 })
    }
    
    func readData(for range: VideoRange) throws -> Data {
        
        lock.lock()
        defer { lock.unlock() }
        
        try readHandle?.throwError_seek(toFileOffset: UInt64(range.lowerBound))
        let data = try readHandle?.throwError_readData(ofLength: UInt(range.length)) ?? Data()
        return data
    }
    
    func writeData(data: Data, for range: VideoRange) throws {
        
        lock.lock()
        defer { lock.unlock() }
        
        guard let handle = writeHandle else { return }
        
        let containsRanges = cacheFragments.compactMap { $0.ranges(for: contentInfo.totalLength) }
        
        guard containsRanges.overlaps(range) else { return }
        
        isWriting = true
        
        VLog(.data, "write data: \(data), for: \(range)")
        
        try handle.throwError_seek(toFileOffset: UInt64(range.lowerBound))
        try handle.throwError_write(data)
        
        configuration.add(fragment: range)
    }
    
    @discardableResult
    func synchronize(notify: Bool = true) throws -> Bool {
        
        lock.lock()
        defer { lock.unlock() }
        
        guard let handle = writeHandle else { return false }
        
        try handle.throwError_synchronizeFile()
        
        let configSyncResult = configuration.synchronize(to: paths.configurationPath(for: url))
        
        if notify {
            NotificationCenter.default.post(name: VideoFileHandle.didSynchronizeNotification,
                                            object: nil,
                                            userInfo: [VideoFileHandle.VideoURLKey: self.url])
        }
        
        return configSyncResult
    }
    
    func close() throws {
        try readHandle?.throwError_closeFile()
        try writeHandle?.throwError_closeFile()
    }
}

extension VideoFileHandle {
    
    @objc
    func applicationDidEnterBackground() {
        guard isWriting else { return }
        do {
            try synchronize()
        } catch {
            VLog(.error, "fileHandel did enter background synchronize failure: \(error)")
        }
    }
}
