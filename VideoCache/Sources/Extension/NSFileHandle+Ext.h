//
//  NSFileHandle+Ext.h
//  VideoCache
//
//  Created by SoalHunag on 2019/9/10.
//  Copyright © 2019 soso. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSFileHandle(Ext)

- (NSData *)try_readDataOfLength:(NSUInteger)length error:(NSError **)error;

- (NSError * _Nullable)try_writeData:(NSData *)data;

- (unsigned long long)try_seekToEndOfFileWithError:(NSError **)error;
- (NSError * _Nullable)try_seekToFileOffset:(unsigned long long)offset;

- (NSError * _Nullable)try_truncateFileAtOffset:(unsigned long long)offset;
- (NSError * _Nullable)try_synchronizeFile;
- (NSError * _Nullable)try_closeFile;

@end

NS_ASSUME_NONNULL_END
