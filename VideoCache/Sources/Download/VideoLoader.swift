//
//  VideoLoader.swift
//  VideoCache
//
//  Created by SoalHunag on 2019/2/24.
//  Copyright © 2019 soso. All rights reserved.
//

import Foundation
import AVFoundation

protocol VideoLoaderType: NSObjectProtocol {
    
    func add(loadingRequest: AVAssetResourceLoadingRequest)
    func remove(loadingRequest: AVAssetResourceLoadingRequest)
    func cancel()
}

extension VideoLoader: VideoLoaderType {
    
    func add(loadingRequest: AVAssetResourceLoadingRequest) {
        let downloader = VideoDownloader(manager: manager, url: url, loadingRequest: loadingRequest, fileHandle: fileHandle)
        downloader.delegate = self
        downLoaders.append(downloader)
        downloader.execute()
        manager.addDownloading(url: url)
    }
    
    func remove(loadingRequest: AVAssetResourceLoadingRequest) {
        downLoaders.removeAll {
            guard $0.loadingRequest == loadingRequest else { return false }
            $0.finish()
            return true
        }
    }
    
    func cancel() {
        downLoaders.forEach { $0.cancel() }
        downLoaders.removeAll()
        manager.removeDownloading(url: url)
    }
}

extension VideoLoader: VideoDownloaderDelegate {
    
    func downloaderFinish(_ downloader: VideoDownloader) {
        downloader.finish()
        downLoaders.removeAll { $0.loadingRequest == downloader.loadingRequest }
    }
    
    func downloader(_ downloader: VideoDownloader, finishWith error: Error?) {
        VLog(.error, "loader download failure: \(String(describing: error))")
        cancel()
    }
}

class VideoLoader: NSObject {
    
    let manager: VideoCacheManager
    let url: VURL
    let limitRange: VideoRange
    
    deinit {
        VLog(.info, "VideoLoader deinit\n")
        cancel()
    }
    
    init(manager: VideoCacheManager, url: VURL, cacheLimit range: VideoRange) {
        self.manager = manager
        self.url = url
        self.limitRange = range
        super.init()
    }
    
    private lazy var fileHandle: VideoFileHandle = VideoFileHandle(manager: manager, url: url, cacheLimit: limitRange)
    
    private var downLoaders_: [VideoDownloaderType] = []
    private let lock = NSLock()
    private var downLoaders: [VideoDownloaderType] {
        get { lock.lock(); defer { lock.unlock() }; return downLoaders_ }
        set { lock.lock(); defer { lock.unlock() }; downLoaders_ = newValue }
    }
}
