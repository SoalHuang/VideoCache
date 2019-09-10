//
//  VideoDownloader.swift
//  VideoCache
//
//  Created by SoalHunag on 2019/2/24.
//  Copyright © 2019 soso. All rights reserved.
//

import Foundation
import AVFoundation

fileprivate struct DownloadQueue {
    
    static let shared = DownloadQueue()
    
    let queue: OperationQueue = OperationQueue()
    
    init() {
        queue.name = "com.video.cache.download.queue"
    }
}

protocol VideoDownloaderType: NSObjectProtocol {
    
    var delegate: VideoDownloaderDelegate? { get set }
    
    var url: VURL { get }
    
    var loadingRequest: AVAssetResourceLoadingRequest { get }
    
    func finish()
    func cancel()
    func execute()
}

protocol VideoDownloaderDelegate: NSObjectProtocol {
    
    func downloaderFinish(_ downloader: VideoDownloader)
    func downloader(_ downloader: VideoDownloader, finishWith error: Error?)
}

extension VideoDownloader: VideoDownloaderType {
    
    func finish() {
        VLog(.info, "downloader id: \(id), finish")
        NSObject.cancelPreviousPerformRequests(withTarget: self)
        delegate = nil
        if !loadingRequest.isFinished {
            loadingRequest.finishLoading(with: VideoCacheErrors.canceled.error)
        }
        dataDelegate?.delegate = nil
        session?.invalidateAndCancel()
        dataDelegate = nil
        session = nil
        isCanceled = true
    }
    
    func cancel() {
        VLog(.info, "downloader id: \(id), canceled")
        NSObject.cancelPreviousPerformRequests(withTarget: self)
        dataDelegate?.delegate = nil
        session?.invalidateAndCancel()
        dataDelegate = nil
        session = nil
        isCanceled = true
    }
    
    func execute() {
        guard let dataRequest = loadingRequest.dataRequest else {
            finishLoading(error: VideoCacheErrors.dataRequestNull.error)
            return
        }
        
        loadingRequest.contentInformationRequest?.update(contentInfo: fileHandle.contentInfo)
        
        if fileHandle.configuration.contentInfo.totalLength > 0 {
            fileHandle.configuration.synchronize()
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
            VLog(.request, "downloader id: \(id), actions: \(actions)")
        }
        actionLoop()
    }
}

private var private_id: Int = 0
private var accId: Int { private_id += 1; return private_id }

class VideoDownloader: NSObject {
    
    weak var delegate: VideoDownloaderDelegate?
    
    let url: VURL
    
    let loadingRequest: AVAssetResourceLoadingRequest
    
    var fileHandle: VideoFileHandleType
    
    deinit {
        VLog(.info, "downloader id: \(id), VideoDownloader deinit\n")
        NSObject.cancelPreviousPerformRequests(withTarget: self)
        session?.invalidateAndCancel()
        dataDelegate?.delegate = nil
        isCanceled = true
        delegate = nil
    }
    
    init(url: VURL, loadingRequest: AVAssetResourceLoadingRequest, fileHandle: VideoFileHandleType) {
        self.url = url
        self.loadingRequest = loadingRequest
        self.fileHandle = fileHandle
        super.init()
        dataDelegate = DownloaderSessionDelegate(delegate: self)
        session = URLSession(configuration: .default, delegate: dataDelegate, delegateQueue: DownloadQueue.shared.queue)
    }
    
    private let id: Int = accId
    
    private var actions: [Action] = []
    
    private var dataDelegate: DownloaderSessionDelegate?
    
    private var session: URLSession?
    
    private var task: URLSessionDataTask?
    
    private var toEnd: Bool = false
    
    private var isCanceled: Bool = false
    
    private var writeOffset: Int64 = 0
}

extension VideoDownloader {
    
    func update(contentInfo: ContentInfo) {
        loadingRequest.contentInformationRequest?.update(contentInfo: contentInfo)
        fileHandle.contentInfo = contentInfo
    }
    
    @objc
    func actionLoop() {
        if isCanceled {
            finishLoading(error: VideoCacheErrors.canceled.error)
            return
        }
        guard actions.count > 0 else {
            loadingRequest.finishLoading()
            delegate?.downloaderFinish(self)
            return
        }
        let action = actions.removeFirst()
        switch action {
        case .local(let range): read(from: range)
        case .remote(let range): download(for: range)
        }
    }
}

extension VideoDownloader: DownloaderSessionDelegateDelegate {
    
    func downloaderSession(_ delegate: DownloaderSessionDelegateType, didReceive response: URLResponse) {
        if fileHandle.isNeedUpdateContentInfo {
            update(contentInfo: ContentInfo(response: response))
        }
    }
    
    func downloaderSession(_ delegate: DownloaderSessionDelegateType, didReceive data: Data) {
        if isCanceled { return }
        write(data: data)
        loadingRequest.dataRequest?.respond(with: data)
    }
    
    func downloaderSession(_ delegate: DownloaderSessionDelegateType, didCompleteWithError error: Error?) {
        guard let `error` = error else {
            finishLoading()
            return
        }
        if (error as NSError).code == NSURLErrorCancelled { return }
        finishLoading(error: error)
    }
}

extension VideoDownloader {
    
    func receivedLocal(data: Data) {
        loadingRequest.dataRequest?.respond(with: data)
        perform(#selector(actionLoop), with: nil, afterDelay: 0.2)
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
    
    func finishLoading() {
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
}

extension VideoDownloader {
    
    func read(from range: VideoRange) {
        VLog(.data, "downloader id: \(id), read data range: (\(range)) length: \(range.length)")
        do {
            let data = try fileHandle.readData(for: range)
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
        guard VideoCacheManager.default.allowWrite else { return }
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


protocol DownloaderSessionDelegateType: URLSessionDataDelegate {
    
    var delegate: DownloaderSessionDelegateDelegate? { get set }
}

protocol DownloaderSessionDelegateDelegate: NSObjectProtocol {
    
    func downloaderSession(_ delegate: DownloaderSessionDelegateType, didReceive response: URLResponse)
    func downloaderSession(_ delegate: DownloaderSessionDelegateType, didReceive data: Data)
    func downloaderSession(_ delegate: DownloaderSessionDelegateType, didCompleteWithError error: Error?)
}

private let DownloadBufferLimit: Int = 64.KB

private class DownloaderSessionDelegate: NSObject, DownloaderSessionDelegateType {
    
    weak var delegate: DownloaderSessionDelegateDelegate?
    
    private var bufferData = NSMutableData()
    private let lock = NSLock()
    
    deinit {
        delegate = nil
    }
    
    init(delegate: DownloaderSessionDelegateDelegate?) {
        super.init()
        self.delegate = delegate
    }
    
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if let serverTrust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(.useCredential, nil)
        }
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        VLog(.request, "task: \(dataTask) did receive response: \(response)")
        guard response.isMediaSource else {
            delegate?.downloaderSession(self, didCompleteWithError: VideoCacheErrors.notMedia.error)
            completionHandler(.cancel)
            return
        }
        delegate?.downloaderSession(self, didReceive: response)
        completionHandler(.allow)
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        
        VLog(.request, "task: \(dataTask) did receive data: \(data.count)")
        
        lock.lock()
        defer { lock.unlock() }
        
        bufferData.append(data)
        
        let bufferCount = bufferData.count
        
        let multiple = bufferCount / DownloadBufferLimit
        
        guard multiple > 1 else { return }
        
        let length = DownloadBufferLimit * multiple
        
        let chunkRange = NSRange(location: bufferData.startIndex, length: length)
        
        VLog(.info, "task: buffer data count: \(bufferCount), subdata: \(chunkRange)")
        
        let chunkData = bufferData.subdata(with: chunkRange)
        
        VLog(.info, "task: buffer data remove subrange: \(chunkRange)")
        
        bufferData.replaceBytes(in: chunkRange, withBytes: nil, length: 0)
        
        delegate?.downloaderSession(self, didReceive: chunkData)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        
        VLog(.request, "task: \(task) did complete with error: \(String(describing: error))")
        
        lock.lock()
        defer { lock.unlock() }
        
        let bufferCount = bufferData.count
        
        if error == nil, bufferCount > 0 {
            
            let chunkRange = NSRange(location: bufferData.startIndex, length: bufferCount)
            let chunkData = bufferData.subdata(with: chunkRange)
            
            bufferData.replaceBytes(in: chunkRange, withBytes: nil, length: 0)
            
            delegate?.downloaderSession(self, didReceive: chunkData)
        }
        
        delegate?.downloaderSession(self, didCompleteWithError: error)
    }
}
