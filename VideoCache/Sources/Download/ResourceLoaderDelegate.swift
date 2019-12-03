//
//  VideoResourceLoaderDelegate.swift
//  VideoCache
//
//  Created by SoalHunag on 2019/2/22.
//  Copyright © 2019 soso. All rights reserved.
//

import AVFoundation

extension VideoResourceLoaderDelegate {
    
    var manager: VideoCacheManager { return mgr ?? VideoCacheManager.default }
}

class VideoResourceLoaderDelegate: NSObject {
    
    private weak var mgr: VideoCacheManager?
    
    let url: VideoURLType
    
    let cacheRanges: [VideoRange]
    
    var loaders: [String: VideoLoaderType] = [:]
    
    deinit {
        VLog(.info, "VideoResourceLoaderDelegate deinit\n")
        loaders.removeAll()
        manager.removeDownloading(url: url)
    }
    
    init(manager: VideoCacheManager, url: VideoURLType, cacheRanges: [VideoRange]) {
        self.mgr = manager
        self.url = url
        self.cacheRanges = cacheRanges
        super.init()
        checkAlreadyOverCache()
    }
    
    func cancel() {
        VLog(.info, "VideoResourceLoaderDelegate cancel\n")
        loaders.values.forEach { $0.cancel() }
        loaders.removeAll()
    }
}

extension VideoResourceLoaderDelegate {
    
    private func checkAlreadyOverCache() {
        
        VLog(.info, "Check already over cahce file")
        
        let `url` = self.url
        let paths = manager.paths
        
        let configuration = paths.configuration(for: url)
        
        guard configuration.fragments.isEmpty else { return }
        
        guard let contentInfo = paths.contentInfo(for: url) else {
            if paths.contentInfoIsExists(for: url) {
                VLog(.error, "1 content info is exists, but cannot parse, need delete its video file")
                do {
                    try FileM.removeItem(atPath: paths.videoPath(for: url))
                    VLog(.info, "1 delete video: \(url)")
                } catch {
                    VLog(.error, "1 delete video: \(url) failure: \(error)")
                }
            }
            return
        }
        
        VLog(.info, "Found already over content info: \(contentInfo.description)")
        
        configuration.contentInfo = contentInfo
        
        let configurationPath = paths.configurationPath(for: url)
        
        guard let videoAtt = try? FileM.attributesOfItem(atPath: paths.videoPath(for: url)) as NSDictionary else {
            configuration.synchronize(to: configurationPath)
            return
        }
        
        let videoFileSize = videoAtt.fileSize()
        
        VLog(.data, "Found already over cache size: \(videoFileSize)")
        
        guard videoFileSize > 0 else {
            configuration.synchronize(to: configurationPath)
            return
        }
        
        let length = VideoRangeBounds(videoFileSize)
        
        configuration.reservedLength = length
        configuration.add(fragment: VideoRange(0, length))
        
        if !configuration.synchronize(to: configurationPath) {
            VLog(.error, "2 configuration synchronize failed, need delete its video file")
            do {
                try FileM.removeItem(atPath: paths.videoPath(for: url))
                VLog(.info, "2 delete video: \(url)")
            } catch {
                VLog(.error, "2 delete video: \(url) failure: \(error)")
            }
        }
    }
}

extension VideoResourceLoaderDelegate: AVAssetResourceLoaderDelegate {
    
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        VLog(.info, "VideoResourceLoaderDelegate shouldWaitForLoadingOfRequestedResource loadingRequest: \(loadingRequest)\n")
        guard let resourceURL = loadingRequest.request.url, resourceURL.isCacheScheme else {
            return false
        }
        if let loader = loaders[resourceURL.absoluteString] {
            loader.add(loadingRequest: loadingRequest)
        } else {
            let newLoader = VideoLoader(paths: manager.paths, url: url, cacheRanges: cacheRanges, delegate: self)
            loaders[resourceURL.absoluteString] = newLoader
            newLoader.add(loadingRequest: loadingRequest)
        }
        manager.addDownloading(url: url)
        return true
    }
    
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, didCancel loadingRequest: AVAssetResourceLoadingRequest) {
        VLog(.info, "VideoResourceLoaderDelegate didCancel loadingRequest: \(loadingRequest)\n")
        guard let resourceURL = loadingRequest.request.url, resourceURL.isCacheScheme else { return }
        loaders[resourceURL.absoluteString]?.remove(loadingRequest: loadingRequest)
    }
}

extension VideoResourceLoaderDelegate: VideoLoaderDelegate {
    
    func loaderAllowWriteData(_ loader: VideoLoader) -> Bool {
        return manager.allowWrite
    }
}
