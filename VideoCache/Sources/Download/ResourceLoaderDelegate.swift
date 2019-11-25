//
//  VideoResourceLoaderDelegate.swift
//  VideoCache
//
//  Created by SoalHunag on 2019/2/22.
//  Copyright © 2019 soso. All rights reserved.
//

import AVFoundation

class VideoResourceLoaderDelegate: NSObject {
    
    let manager: VideoCacheManager
    
    let url: VURL
    
    let limitRange: VideoRange
    
    var loaders: [String: VideoLoaderType] = [:]
    
    deinit {
        loaders.removeAll()
    }
    
    init(manager: VideoCacheManager, key: String, url: URL, cacheLimit range: VideoRange) {
        self.manager = manager
        self.url = VURL(cacheKey: key, originUrl: url)
        self.limitRange = range
        super.init()
    }
    
    func cancel() {
        loaders.values.forEach { $0.cancel() }
        loaders.removeAll()
    }
}

extension VideoResourceLoaderDelegate: AVAssetResourceLoaderDelegate {
    
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        guard let resourceURL = loadingRequest.request.url, resourceURL.isCacheScheme else {
            return false
        }
        if let loader = loaders[resourceURL.absoluteString] {
            loader.add(loadingRequest: loadingRequest)
        } else {
            let newLoader = VideoLoader(manager: manager, url: url, cacheLimit: limitRange)
            loaders[resourceURL.absoluteString] = newLoader
            newLoader.add(loadingRequest: loadingRequest)
        }
        return true
    }
    
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, didCancel loadingRequest: AVAssetResourceLoadingRequest) {
        guard let resourceURL = loadingRequest.request.url, resourceURL.isCacheScheme else { return }
        loaders[resourceURL.absoluteString]?.remove(loadingRequest: loadingRequest)
    }
}
