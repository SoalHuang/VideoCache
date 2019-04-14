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
}

extension VideoLoader: VideoLoaderType {
    
    func add(loadingRequest: AVAssetResourceLoadingRequest) {
        let loader = VideoDownloader(url: url, loadingRequest: loadingRequest, fileHandle: fileHandle)
        loader.delegate = self
        downLoaders.append(loader)
        VideoCacheManager.default.addDownloading(url: url)
        loader.execute()
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
        VideoCacheManager.default.removeDownloading(url: url)
    }
}

extension VideoLoader: VideoDownloaderDelegate {
    
    func downloaderFinish(_ downloader: VideoDownloader) {
        downLoaders.removeAll { $0.loadingRequest == downloader.loadingRequest }
    }
    
    func downloader(_ downloader: VideoDownloader, finishWith error: Error?) {
        VLog(.error, "loader download failure: \(String(describing: error))")
        cancel()
//        downLoaders.removeAll { $0.loadingRequest == downloader.loadingRequest }
    }
}

class VideoLoader: NSObject {
    
    let url: VURL
    
    deinit {
        VLog(.info, "VideoLoader deinit\n")
        cancel()
    }
    
    init(url: VURL) {
        self.url = url
        super.init()
    }
    
    private lazy var fileHandle: VideoFileHandleType = VideoFileHandle(url: url)
    
    private var downLoaders_: [VideoDownloaderType] = []
    private let lock = NSLock()
    private var downLoaders: [VideoDownloaderType] {
        get { lock.lock(); defer { lock.unlock() }; return downLoaders_ }
        set { lock.lock(); defer { lock.unlock() }; downLoaders_ = newValue }
    }
}
