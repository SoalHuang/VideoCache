//
//  VURL.swift
//  VideoCache
//
//  Created by SoalHunag on 2019/2/24.
//  Copyright © 2019 soso. All rights reserved.
//

import UIKit

let VideoCacheConfigFileExt = "cfg"

class VURL: NSObject, NSCoding {
    
    var cacheKey: String
    
    var originUrl: URL
    
    required init?(coder aDecoder: NSCoder) {
        cacheKey = aDecoder.decodeObject(forKey: "key") as! String
        originUrl = URL(string: aDecoder.decodeObject(forKey: "url") as! String)!
        super.init()
    }
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(cacheKey, forKey: "key")
        aCoder.encode(originUrl.absoluteString, forKey: "url")
    }
    
    init(cacheKey: String, originUrl: URL) {
        self.cacheKey = cacheKey
        self.originUrl = originUrl
        super.init()
    }
    
    override var description: String {
        return ["cacheKey": cacheKey, "originUrl": originUrl].description
    }
}

extension VURL {
    
    var url: URL {
        return URL(string: URL.VideoCacheScheme + originUrl.absoluteString)!
    }
    
    var cacheFileName: String {
        return cacheKey.CMD5.appending(".\(originUrl.pathExtension)")
    }
    
    var configFileName: String {
        return cacheFileName.appending(".\(VideoCacheConfigFileExt)")
    }
}
