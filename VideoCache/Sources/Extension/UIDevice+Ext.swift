//
//  UIDevice+Ext.swift
//  VideoCache
//
//  Created by SoalHunag on 2019/2/27.
//  Copyright © 2019 soso. All rights reserved.
//

import UIKit

func blankof<T>(type: T.Type) -> T {
    let count = MemoryLayout<T>.size
    VLog(.info, "blank of count: \(count)")
    let pointer = UnsafeMutablePointer<T>.allocate(capacity: count)
    defer { pointer.deallocate() }
    return pointer.pointee
}

extension UIDevice {
    
    static var diskTotalSize: Int64? {
        var fs = blankof(type: statfs.self)
        guard statfs("/var", &fs) >= 0 else { return nil }
        return Int64(UInt64(fs.f_bsize) * fs.f_blocks)
    }
    
    static var diskAvailableSize: Int64? {
        var fs = blankof(type: statfs.self)
        guard statfs("/var",&fs) >= 0 else { return nil }
        return Int64(UInt64(fs.f_bsize) * fs.f_bavail)
    }
}
