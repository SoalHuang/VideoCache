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
        
//        let url = URL(string: "https://sylvan.apple.com/Videos/comp_A006_C003_1219EE_CC_v01_SDR_PS_FINAL_20180709_SDR_2K_AVC.mov")!
//        let url = URL(string: "https://sylvan.apple.com/Videos/KP_A010_C002_SDR_20190717_SDR_2K_AVC.mov")!
//        let url = URL(string: "https://vod.putaocdn.com/postman.mp4?auth_key=1574514306-6275-0-752f6c637ce71ff00b0840461203fa44")!
        let url = URL(string: "https://vod.putaocdn.com/KP_A010_C002_SDR_20190717_SDR_2K_AVC.mov?auth_key=1574661737-3194-0-25102037fbc6c7d4c6fe3a0f980dd56e")!
        
        let cacheItem = AVPlayerItem(remote: url)
        playerViewController.player = AVPlayer(playerItem: cacheItem)
        playerViewController.player?.play()
    }
    
    lazy var playerViewController: AVPlayerViewController = AVPlayerViewController()
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        playerViewController.view.frame = view.bounds
    }
}

