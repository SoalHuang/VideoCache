//
//  VideoDownloader.swift
//  VideoCache
//
//  Created by SoalHunag on 2019/2/24.
//  Copyright © 2019 soso. All rights reserved.
//

import Foundation
import AVFoundation

protocol VideoDownloaderType: NSObjectProtocol {
    
    var delegate: VideoDownloaderDelegate? { get set }
    
    var url: VideoURLType { get }
    
    var loadingRequest: AVAssetResourceLoadingRequest { get }
    
    var id: Int { get }
    
    var task: URLSessionDataTask? { get }
    var dataReceiver: URLSessionDataDelegate? { get }
    
    func finish()
    func cancel()
    func execute()
}

protocol VideoDownloaderDelegate: NSObjectProtocol {
    
    func downloaderAllowWriteData(_ downloader: VideoDownloader) -> Bool
    func downloaderFinish(_ downloader: VideoDownloader)
    func downloader(_ downloader: VideoDownloader, finishWith error: Error?)
}

extension VideoDownloader: VideoDownloaderType {
    
    var dataReceiver: URLSessionDataDelegate? {
        return dataDelegate
    }
    
    func finish() {
        VLog(.info, "downloader id: \(id), finish")
        NSObject.cancelPreviousPerformRequests(withTarget: self)
        delegate = nil
        if !loadingRequest.isFinished {
            loadingRequest.finishLoading(with: VideoCacheErrors.cancelled.error)
        }
        dataDelegate?.delegate = nil
        if task?.state ~= .running || task?.state ~= .suspended {
            task?.cancel()
        }
        isCancelled = true
    }
    
    func cancel() {
        VLog(.info, "downloader id: \(id), cancelled")
        NSObject.cancelPreviousPerformRequests(withTarget: self)
        if task?.state ~= .running || task?.state ~= .suspended {
            task?.cancel()
        }
        dataDelegate?.delegate = nil
        isCancelled = true
    }
    
    func execute() {
        
        guard let dataRequest = loadingRequest.dataRequest else {
            finishLoading(error: VideoCacheErrors.dataRequestNull.error)
            return
        }
        
        loadingRequest.contentInformationRequest?.update(contentInfo: fileHandle.contentInfo)
        
        if fileHandle.configuration.contentInfo.totalLength > 0 {
            fileHandle.configuration.synchronize(to: paths.configurationPath(for: url))
        }
        //        else if dataRequest.requestsAllDataToEndOfResource {
        //            toEnd = true
        //        }
        
        if toEnd {
            let offset: Int64 = 0
            let length: Int64 = 2
            let range = VideoRange(offset, length)
            VLog(.info, "downloader id: \(id), wants: \(offset) to end")
            actions = fileHandle.actions(for: range)
            VLog(.request, "downloader id: \(id), actions: \(actions)")
        } else {
            let offset = Int64(dataRequest.requestedOffset)
            let length = Int64(dataRequest.requestedLength)
            let range = VideoRange(offset, offset + length)
            VLog(.info, "downloader id: \(id), wants: \(range)")
            actions = fileHandle.actions(for: range)
            VLog(.data, "downloader id: \(id), actions: \(actions)")
        }
        actionLoop()
    }
}

private var private_id: Int = 0
private var accId: Int { private_id += 1; return private_id }

class VideoDownloader: NSObject {
    
    weak var delegate: VideoDownloaderDelegate?
    
    let paths: VideoCachePaths
    
    let url: VideoURLType
    
    let loadingRequest: AVAssetResourceLoadingRequest
    
    let fileHandle: VideoFileHandle
    
    deinit {
        VLog(.info, "downloader id: \(id), VideoDownloader deinit\n")
        NSObject.cancelPreviousPerformRequests(withTarget: self)
    }
    
    init(paths: VideoCachePaths,
         session: URLSession?,
         url: VideoURLType,
         loadingRequest: AVAssetResourceLoadingRequest,
         fileHandle: VideoFileHandle) {
        self.paths = paths
        self.session = session
        self.url = url
        self.loadingRequest = loadingRequest
        self.fileHandle = fileHandle
        super.init()
        dataDelegate = DownloaderSessionDelegate(delegate: self)
    }
    
    let id: Int = accId
    
    private var actions: [Action] = []
    
    private var failedRetryCount: Int = 0
    private var currentAction: Action? {
        didSet { failedRetryCount = 0 }
    }
    
    internal private(set) var dataDelegate: DownloaderSessionDelegateType?
    
    internal private(set) weak var session: URLSession?
    
    internal private(set) var task: URLSessionDataTask?
    
    private var toEnd: Bool = false
    
    private var isCancelled: Bool = false
    
    private var writeOffset: Int64 = 0
}

extension VideoDownloader {
    
    func update(contentInfo: ContentInfo) {
        loadingRequest.contentInformationRequest?.update(contentInfo: contentInfo)
        fileHandle.contentInfo = contentInfo
    }
    
    @objc
    func actionLoop() {
        if isCancelled {
            VLog(.info, "this downloader is cancelled, callback cancelled message and return")
            finishLoading(error: VideoCacheErrors.cancelled.error)
            return
        }
        guard actions.count > 0 else {
            loopFinished()
            return
        }
        let action = actions.removeFirst()
        currentAction = action
        switch action {
        case .local(let range): read(from: range)
        case .remote(let range): download(for: range)
        }
    }
}

extension VideoDownloader {
    
    func read(from range: VideoRange) {
        
        VLog(.data, "downloader id: \(id), read data range: (\(range)) length: \(range.length)")
        
        do {
            
            let data = try fileHandle.readData(for: range)
            
            guard range.lowerBound > 0 else {
                receivedLocal(data: data)
                return
            }
            
            guard data.count == range.length else {
                VLog(.error, "read local data length is error, re-download range: \(range)")
                download(for: range)
                return
            }
            
            guard data.checksum() else {
                VLog(.error, "check sum is failure, re-download range: \(range)")
                download(for: range)
                return
            }
            
            receivedLocal(data: data)
            
        } catch {
            
            VLog(.error, "downloader id: \(id), read local data failure: \(error)")
            finishLoading(error: error)
        }
    }
    
    func download(for range: VideoRange) {
        
        VLog(.info, "downloader id: \(id), download range: (\(range)) length: \(range.length)")
        guard let originUrl = loadingRequest.request.url?.originUrl else {
            finishLoading(error: VideoCacheErrors.badUrl.error)
            return
        }
        
        writeOffset = range.lowerBound
        
        let fromOffset = range.lowerBound
        let toOffset = range.upperBound - 1
        
        VLog(.request, "downloader id: \(id), download offsets: \(fromOffset) - \(toOffset)")
        
        let cachePolicy = URLRequest.CachePolicy.reloadIgnoringLocalAndRemoteCacheData
        let timeoutInterval = loadingRequest.request.timeoutInterval
        
        var request = URLRequest(url: originUrl, cachePolicy: cachePolicy, timeoutInterval: timeoutInterval)
        request.setValue("bytes=\(fromOffset)-\(toOffset)", forHTTPHeaderField: "Range")
        task = session?.dataTask(with: request)
        task?.resume()
    }
    
    func write(data: Data) {
        
        guard let allow = delegate?.downloaderAllowWriteData(self), allow else { return }
        
        let range = VideoRange(writeOffset, writeOffset + Int64(data.count))
        VLog(.data, "downloader id: \(id), write data range: (\(range)) length: \(range.length)")
        do {
            try fileHandle.writeData(data: data, for: range)
        } catch {
            VLog(.error, "downloader id: \(id), write data failure: \(error)")
        }
        writeOffset += range.length
    }
}

extension VideoDownloader {
    
    func receivedLocal(data: Data) {
        loadingRequest.dataRequest?.respond(with: data)
        if data.count < PacketLimit {
            actionLoop()
        } else {
            perform(#selector(actionLoop), with: nil, afterDelay: 0.1)
        }
    }
    
    func finishLoading(error: Error?) {
        VLog(.error, "finish loading error: \(String(describing: error))")
        do {
            try fileHandle.synchronize(notify: true)
        } catch {
            VLog(.error, "finish loading error, fileHandle synchronize failure: \(error)")
        }
        loadingRequest.finishLoading(with: error)
        delegate?.downloader(self, finishWith: error)
    }
    
    func downloadFinishLoading() {
        if toEnd {
            toEnd.toggle()
            actions = fileHandle.actions(for: VideoRange(0, fileHandle.contentInfo.totalLength))
        }
        do {
            try fileHandle.synchronize(notify: true)
        } catch {
            VLog(.error, "finish loading, fileHandle synchronize failure: \(error)")
        }
        actionLoop()
    }
    
    func loopFinished() {
        VLog(.info, "actions is empty, finished")
        do {
            try fileHandle.synchronize(notify: true)
        } catch {
            VLog(.error, "actions is empty, finish loading, fileHandle synchronize failure: \(error)")
        }
        loadingRequest.finishLoading()
        delegate?.downloaderFinish(self)
    }
}

extension VideoDownloader: DownloaderSessionDelegateDelegate {
    
    func downloaderSession(_ delegate: DownloaderSessionDelegateType,
                           didReceive response: URLResponse) {
        if response.isMediaSource, fileHandle.isNeedUpdateContentInfo {
            update(contentInfo: ContentInfo(response: response))
        }
    }
    
    func downloaderSession(_ delegate: DownloaderSessionDelegateType,
                           didReceive data: Data) {
        if isCancelled { return }
        write(data: data)
        loadingRequest.dataRequest?.respond(with: data)
    }
    
    func downloaderSession(_ delegate: DownloaderSessionDelegateType,
                           didCompleteWithError error: Error?) {
        guard let `error` = error else {
            downloadFinishLoading()
            return
        }
        if (error as NSError).code == NSURLErrorCancelled { return }
        if case .remote(let range) = currentAction, failedRetryCount < 3 {
            failedRetryCount += 1
            download(for: range)
        } else {
            finishLoading(error: error)
        }
    }
}


protocol DownloaderSessionDelegateType: URLSessionDataDelegate {
    
    var delegate: DownloaderSessionDelegateDelegate? { get set }
}

protocol DownloaderSessionDelegateDelegate: NSObjectProtocol {
    
    func downloaderSession(_ delegate: DownloaderSessionDelegateType, didReceive response: URLResponse)
    func downloaderSession(_ delegate: DownloaderSessionDelegateType, didReceive data: Data)
    func downloaderSession(_ delegate: DownloaderSessionDelegateType, didCompleteWithError error: Error?)
}

private let DownloadBufferLimit: Int = 32.KB

private class DownloaderSessionDelegate: NSObject, DownloaderSessionDelegateType {
    
    weak var delegate: DownloaderSessionDelegateDelegate?
    
    private var bufferData = NSMutableData()
    
    deinit {
        VLog(.info, "DownloaderSessionDelegate deinit\n")
    }
    
    init(delegate: DownloaderSessionDelegateDelegate?) {
        super.init()
        self.delegate = delegate
    }
    
    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        VLog(.data, "task: \(dataTask) did receive response: \(response)")
        guard response.isMediaSource else {
            delegate?.downloaderSession(self, didCompleteWithError: VideoCacheErrors.notMedia.error)
            completionHandler(.cancel)
            return
        }
        delegate?.downloaderSession(self, didReceive: response)
        completionHandler(.allow)
    }
    
    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive data: Data) {
        
        VLog(.data, "task: \(dataTask) did receive data: \(data.count)")
        
        bufferData.append(data)
        
        let multiple = bufferData.count / DownloadBufferLimit
        
        guard multiple >= 1 else { return }
        
        let length = DownloadBufferLimit * multiple
        
        let chunkRange = NSRange(location: bufferData.startIndex, length: length)
        
        VLog(.data, "task: buffer data count: \(bufferData.count), subdata: \(chunkRange)")
        
        let chunkData = bufferData.subdata(with: chunkRange)
        
        let dataRange = NSRange(location: bufferData.startIndex, length: bufferData.count)
        
        if let intersectionRange = dataRange.intersection(chunkRange), intersectionRange.length > 0 {
            
            VLog(.data, "task: buffer data remove subrange: \(intersectionRange)")
            
            bufferData.replaceBytes(in: intersectionRange, withBytes: nil, length: 0)
        }
        
        delegate?.downloaderSession(self, didReceive: chunkData)
    }
    
    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        
        VLog(.request, "task: \(task) did complete with error: \(String(describing: error))")
        
        let bufferCount = bufferData.count
        
        guard error == nil, bufferCount > 0 else {
            bufferData.setData(Data())
            delegate?.downloaderSession(self, didCompleteWithError: error)
            return
        }
        
        let chunkRange = NSRange(location: bufferData.startIndex, length: bufferCount)
        let chunkData = bufferData.subdata(with: chunkRange)
        
        bufferData.setData(Data())
        
        delegate?.downloaderSession(self, didReceive: chunkData)
        delegate?.downloaderSession(self, didCompleteWithError: error)
    }
}
