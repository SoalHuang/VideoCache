//
//  FileHandle+Exception.swift
//  VideoCache
//
//  Created by SoalHunag on 2019/9/10.
//  Copyright © 2019 soso. All rights reserved.
//

import Foundation

extension FileHandle {
    
    func throwError_readData(ofLength length: UInt) throws -> Data {
        var error: NSError?
        let data = try_readData(ofLength: length, error: &error)
        if let `error` = error { throw error }
        return data
    }
    
    func throwError_write(_ data: Data) throws {
        if let error = try_write(data) {
            throw error
        }
    }
    
    func throwError_seekToEndOfFile() throws -> UInt64 {
        var error: NSError?
        let offset = try_seekToEndOfFileWithError(&error)
        if let `error` = error { throw error }
        return offset
    }
    
    func throwError_seek(toFileOffset offset: UInt64) throws {
        if let error = try_seek(toFileOffset: offset) {
            throw error
        }
    }
    
    func throwError_truncateFile(atOffset offset: UInt64) throws {
        if let error = try_truncateFile(atOffset: offset) {
            throw error
        }
    }
    
    func throwError_synchronizeFile() throws {
        if let error = try_synchronizeFile() {
            throw error
        }
    }
    
    func throwError_closeFile() throws {
        if let error = try_closeFile() {
            throw error
        }
    }
}
