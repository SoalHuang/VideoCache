//
//  AVPlayerItem+Cache.swift
//  VideoCache
//
//  Created by SoalHunag on 2019/2/22.
//  Copyright © 2019 soso. All rights reserved.
//

import AVFoundation
import ObjectiveC.runtime

extension AVPlayerItem {
    
    /// if cache key is nil, it will be filled by url.absoluteString's md5 string
    public convenience init(manager: VideoCacheManager = VideoCacheManager.default,
                            remote url: URL,
                            cacheKey key: String? = nil,
                            cacheLimit range: VideoRange? = nil) {
        
        let `key` = key ?? url.absoluteString.videoCacheMD5
        
        manager.use(url: VURL(cacheKey: key, originUrl: url))
        
        let limitRange = range ?? VideoRange(0, VideoRangeBounds.max)
        let loaderDelegate = VideoResourceLoaderDelegate(manager: manager, key: key, url: url, cacheLimit: limitRange)
        let urlAsset = AVURLAsset(url: loaderDelegate.url.includeVideoCacheSchemeUrl, options: nil)
        urlAsset.resourceLoader.setDelegate(loaderDelegate, queue: .main)
        
        self.init(asset: urlAsset)
        canUseNetworkResourcesForLiveStreamingWhilePaused = true
        
        resourceLoaderDelegate = loaderDelegate
    }
    
    public func cacheCancel() {
        resourceLoaderDelegate?.cancel()
        resourceLoaderDelegate = nil
    }
}
