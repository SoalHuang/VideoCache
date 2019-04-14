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
    public convenience init(remote url: URL, cacheKey key: String? = nil) {
        
        let `key` = key ?? url.absoluteString.CMD5
        
        let loaderDelegate = VideoResourceLoaderDelegate(key: key, url: url)
        let urlAsset = AVURLAsset(url: loaderDelegate.url.url, options: nil)
        urlAsset.resourceLoader.setDelegate(loaderDelegate, queue: .main)
        
        self.init(asset: urlAsset)
        canUseNetworkResourcesForLiveStreamingWhilePaused = true
        
        resourceLoaderDelegate = loaderDelegate
    }
}
