//
//  VideoFileHandle.swift
//  VideoCache
//
//  Created by SoalHunag on 2019/2/24.
//  Copyright © 2019 soso. All rights reserved.
//

import Foundation

import UIKit

private let PacketLimit: Int64 = Int64(1).MB

protocol VideoFileHandleType {
    
    var configuration: VideoConfigurationType { get }
    
    func actions(for range: VideoRange) -> [Action]
    
    func readData(for range: VideoRange) throws -> Data
    
    func writeData(data: Data, for range: VideoRange) throws
    
    func synchronize(notify: Bool)
}

extension VideoFileHandleType {
    
    var isNeedUpdateContentInfo: Bool { return configuration.contentInfo.totalLength < PacketLimit }
    
    var contentInfo: ContentInfo {
        get { return configuration.contentInfo }
        set {
            configuration.contentInfo = newValue
            configuration.synchronize()
        }
    }
}

class VideoFileHandle {
    
    let url: VURL
    
    let filePath: String
    
    deinit {
        synchronize(notify: false)
        readHandle.closeFile()
        writeHandle.closeFile()
        NotificationCenter.default.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
    }
    
    init(url: VURL) {
        self.url = url
        filePath = VideoCacheManager.default.videoPath(for: url)
        if !FileM.fileExists(atPath: filePath) {
            FileM.createFile(atPath: filePath, contents: nil, attributes: nil)
        }
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }
    
    lazy var configuration: VideoConfigurationType = VideoCacheManager.default.configuration(for: url)
    
    private lazy var readHandle = FileHandle(forReadingAtPath: filePath)!
    private lazy var writeHandle = FileHandle(forWritingAtPath: filePath)!
    
    private var isWriting: Bool = false
    
    private let lock = NSLock()
}

extension VideoFileHandle {
    
    static let VideoURLKey: String = "VideoURLKey"
    
    static let didSynchronizeNotification: NSNotification.Name = NSNotification.Name("VideoFileHandle.didSynchronizeNotification")
}

extension VideoFileHandle: VideoFileHandleType {
    
    func actions(for range: VideoRange) -> [Action] {
        var actions: [Action] = []
        guard range.isValid else { return actions }
        
        let localRanges = configuration.overlaps(range).compactMap { $0.clamped(to: range) }.split(limit: PacketLimit).filter { $0.isValid }
        
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
        
        readHandle.seek(toFileOffset: UInt64(range.lowerBound))
        return readHandle.readData(ofLength: Int(range.length))
    }
    
    func writeData(data: Data, for range: VideoRange) throws {
        lock.lock()
        defer { lock.unlock() }
        
        isWriting = true
        
        VLog(.data, "write data: \(data), for: \(range)")
        
        writeHandle.seek(toFileOffset: UInt64(range.lowerBound))
        writeHandle.write(data)
        configuration.add(fragment: range)
    }
    
    func synchronize(notify: Bool = true) {
        lock.lock()
        defer { lock.unlock() }
        
        writeHandle.synchronizeFile()
        configuration.synchronize()
        
        if notify {
            NotificationCenter.default.post(name: VideoFileHandle.didSynchronizeNotification,
                                            object: nil,
                                            userInfo: [VideoFileHandle.VideoURLKey: self.url])
        }
    }
}

extension VideoFileHandle {
    
    @objc func applicationDidEnterBackground() {
        if isWriting { synchronize() }
    }
}
