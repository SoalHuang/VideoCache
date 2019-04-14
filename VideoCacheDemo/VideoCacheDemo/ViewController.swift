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
        VideoCacheManager.default.logLevel = .request
        VideoCacheManager.default.capacityLimit = Int64(1).GB
        
        let version = 1
        
        let savedVersion = UserDefaults.standard.integer(forKey: VideoCacheVersionKey)
        if savedVersion < version {
            try? VideoCacheManager.default.cleanAll()
            UserDefaults.standard.set(version, forKey: VideoCacheVersionKey)
            UserDefaults.standard.synchronize()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupVideoCache()
        
        addChild(playerViewController)
        view.addSubview(playerViewController.view)
        
        let url = URL(string: "<#Video or Audio URL#>")!
        
        let cacheItem = AVPlayerItem(remote: url, cacheKey: <#Store Key or nil#>)
        playerViewController.player = AVPlayer(playerItem: cacheItem)
        playerViewController.player?.play()
    }
    
    lazy var playerViewController: AVPlayerViewController = AVPlayerViewController()
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        playerViewController.view.frame = view.bounds
    }
}

