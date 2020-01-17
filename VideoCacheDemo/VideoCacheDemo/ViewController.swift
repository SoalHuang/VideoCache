//
//  ViewController.swift
//  VideoCacheDemo
//
//  Created by SoalHunag on 2019/2/27.
//  Copyright © 2019 soso. All rights reserved.
//

import UIKit
import AVKit
import AVFoundation
import VideoCache

private let VideoCacheVersionKey = "VideoCacheVersionKey"

class ViewController: UIViewController {
    
    func setupVideoCache() {
        
        VideoCacheManager.logLevel = .request
        
        VideoCacheManager.default.capacityLimit = Int64(1).GB
        
        let version = 1
        
        let savedVersion = UserDefaults.standard.integer(forKey: VideoCacheVersionKey)
        if savedVersion < version {
            try? VideoCacheManager.default.cleanAll(true)
            UserDefaults.standard.set(version, forKey: VideoCacheVersionKey)
            UserDefaults.standard.synchronize()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupVideoCache()
        
        addChild(playerViewController)
        view.addSubview(playerViewController.view)
        
        let url = URL(string: "https://vod.putaocdn.com/IMG_4449.MOV?auth_key=1579155925-3012-0-36f3aa6455033a9b078ad93eef7dcdea")!
        let cacheItem = AVPlayerItem(remote: url, cacheKey: "1111")
        
        playerViewController.player = AVPlayer(playerItem: cacheItem)
        playerViewController.player?.play()
    }
    
    lazy var playerViewController: AVPlayerViewController = AVPlayerViewController()
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        playerViewController.view.frame = view.bounds
    }
}

