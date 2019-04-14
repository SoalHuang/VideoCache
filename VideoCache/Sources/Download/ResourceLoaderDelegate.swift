//
//  VideoResourceLoaderDelegate.swift
//  VideoCache
//
//  Created by SoalHunag on 2019/2/22.
//  Copyright © 2019 soso. All rights reserved.
//

import AVFoundation

class VideoResourceLoaderDelegate: NSObject {
    
    let url: VURL
    
    var loaders: [String: VideoLoaderType] = [:]
    
    deinit {
        loaders.removeAll()
    }
    
    init(key: String, url: URL) {
        self.url = VURL(cacheKey: key, originUrl: url)
        super.init()
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
            let newLoader = VideoLoader(url: url)
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
