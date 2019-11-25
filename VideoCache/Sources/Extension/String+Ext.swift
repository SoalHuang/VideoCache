//
//  String+Ext.swift
//  VideoCache
//
//  Created by SoalHunag on 2019/2/22.
//  Copyright © 2019 soso. All rights reserved.
//

import Foundation
import CommonCrypto

extension String {
    
    var videoCacheMD5: String {
        let str = cString(using: String.Encoding.utf8) ?? []
        let strLen = CUnsignedInt(lengthOfBytes(using: String.Encoding.utf8))
        let digestLen = Int(CC_MD5_DIGEST_LENGTH)
        let result = UnsafeMutablePointer<CUnsignedChar>.allocate(capacity: digestLen)
        CC_MD5(str, strLen, result)
        let hash = NSMutableString()
        for i in (0..<digestLen) {
            hash.appendFormat("%02x", result[i])
        }
        defer { result.deallocate() }
        return String(format: hash as String)
    }
}
