//
//  NSFileHandle+Ext.m
//  VideoCache
//
//  Created by SoalHunag on 2019/9/10.
//  Copyright © 2019 soso. All rights reserved.
//

#import "NSFileHandle+Ext.h"

static NSString * const FileHandleErrorDomain = @"com.putao.video.cache.filehandle.error.domain";

typedef NS_ENUM(NSUInteger, FileHandleErrorCodes) {
    FileHandleErrorCodesRead        = 99920,
    FileHandleErrorCodesWrite,
    FileHandleErrorCodesSeekToEnd,
    FileHandleErrorCodesSeek,
    FileHandleErrorCodesTruncate,
    FileHandleErrorCodesSynchronize,
    FileHandleErrorCodesClose
};

@implementation NSFileHandle(Ext)

- (NSData *)try_readDataOfLength:(NSUInteger)length error:(NSError **)error {
    @try {
        return [self readDataOfLength: length];
    } @catch (NSException *exception) {
        *error = [NSError errorWithDomain:FileHandleErrorDomain code:FileHandleErrorCodesRead userInfo:exception.userInfo];
    } @finally {
        *error = nil;
    }
}

- (NSError * _Nullable)try_writeData:(NSData *)data {
    @try {
        [self writeData:data];
    } @catch (NSException *exception) {
        return [NSError errorWithDomain:FileHandleErrorDomain code:FileHandleErrorCodesWrite userInfo:exception.userInfo];
    } @finally {
        return nil;
    }
}

- (unsigned long long)try_seekToEndOfFileWithError:(NSError **)error {
    @try {
        return [self seekToEndOfFile];
    } @catch (NSException *exception) {
        *error = [NSError errorWithDomain:FileHandleErrorDomain code:FileHandleErrorCodesSeekToEnd userInfo:exception.userInfo];
    } @finally {
        *error = nil;
    }
}

- (NSError * _Nullable)try_seekToFileOffset:(unsigned long long)offset {
    @try {
        [self seekToFileOffset:offset];
    } @catch (NSException *exception) {
        return [NSError errorWithDomain:FileHandleErrorDomain code:FileHandleErrorCodesSeek userInfo:exception.userInfo];
    } @finally {
        return nil;
    }
}

- (NSError * _Nullable)try_truncateFileAtOffset:(unsigned long long)offset {
    @try {
        [self truncateFileAtOffset:offset];
    } @catch (NSException *exception) {
        return [NSError errorWithDomain:FileHandleErrorDomain code:FileHandleErrorCodesTruncate userInfo:exception.userInfo];
    } @finally {
        return nil;
    }
}

- (NSError * _Nullable)try_synchronizeFile {
    @try {
        [self synchronizeFile];
    } @catch (NSException *exception) {
        return [NSError errorWithDomain:FileHandleErrorDomain code:FileHandleErrorCodesSynchronize userInfo:exception.userInfo];
    } @finally {
        return nil;
    }
}

- (NSError * _Nullable)try_closeFile {
    @try {
        [self closeFile];
    } @catch (NSException *exception) {
        return [NSError errorWithDomain:FileHandleErrorDomain code:FileHandleErrorCodesClose userInfo:exception.userInfo];
    } @finally {
        return nil;
    }
}

@end
