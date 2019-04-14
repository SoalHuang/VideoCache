//
//  AVPlayerItem+Ext.swift
//  VideoCache
//
//  Created by SoalHunag on 2019/2/27.
//  Copyright © 2019 soso. All rights reserved.
//

import AVFoundation

extension AVPlayerItem {
    
    private static var loaderDelegateKey = arc4random()
    var resourceLoaderDelegate: VideoResourceLoaderDelegate? {
        get { return objc_getAssociatedObject(self, &AVPlayerItem.loaderDelegateKey) as? VideoResourceLoaderDelegate }
        set { objc_setAssociatedObject(self, &AVPlayerItem.loaderDelegateKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)}
    }
}
