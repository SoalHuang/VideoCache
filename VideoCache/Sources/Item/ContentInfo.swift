//
//  ContentInfo.swift
//  VideoCache
//
//  Created by SoalHunag on 2019/2/24.
//  Copyright © 2019 soso. All rights reserved.
//

import Foundation

public protocol ContentInfoType: NSObjectProtocol {
    
    var type: String { get }
    var byteRangeAccessSupported: Bool { get }
    var totalLength: Int64 { get }
}

extension ContentInfo: ContentInfoType { }

class ContentInfo: NSObject, NSCoding {
    
    var type: String = "application/octet-stream"
    var byteRangeAccessSupported: Bool = true
    var totalLength: Int64 = 0
    
    required init?(coder aDecoder: NSCoder) {
        super.init()
        type = aDecoder.decodeObject(forKey: "type") as! String
        byteRangeAccessSupported = aDecoder.decodeBool(forKey: "byteRangeAccessSupported")
        totalLength = aDecoder.decodeInt64(forKey: "totalLength")
    }
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(type, forKey: "type")
        aCoder.encode(byteRangeAccessSupported, forKey: "byteRangeAccessSupported")
        aCoder.encode(totalLength, forKey: "totalLength")
    }
    
    init(type: String = "application/octet-stream", byteRangeAccessSupported: Bool = true, totalLength: Int64) {
        super.init()
        self.type = type
        self.byteRangeAccessSupported = byteRangeAccessSupported
        self.totalLength = totalLength
    }
    
    init(response: URLResponse) {
        super.init()
        if let contentType = response.contentType {
            type = contentType
        }
        byteRangeAccessSupported = response.isByteRangeAccessSupported
        totalLength = response.contentRange?.1 ?? response.contentLength ?? 0
    }
    
    override var description: String {
        return ["type": type, "byteRangeAccessSupported": byteRangeAccessSupported, "totalLength": totalLength].description
    }
}
