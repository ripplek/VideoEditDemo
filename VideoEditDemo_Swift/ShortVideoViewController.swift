//
//  ShortVideoViewController.swift
//  VideoEditDemo_Swift
//
//  Created by ripple_k on 2018/2/26.
//  Copyright © 2018年 mac. All rights reserved.
//

import UIKit
import SnapKit
import AVFoundation
import RxCocoa
import RxSwift

class ShortVideoViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        asset = AVURLAsset(url: URL(string: "http://120.25.226.186:32812/resources/videos/minion_01.mp4")!, options: [AVURLAssetPreferPreciseDurationAndTimingKey : true])
        player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
        let playerLayer = AVPlayerLayer(player: player)
        view.layer.addSublayer(playerLayer)
        playerLayer.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.width * 9/16)
        
        UIButton()
            .soap.adhere(toSuperView: view)
            .soap.layout { (make) in
                make.center.equalToSuperview()
            }
            .soap.config { (btn) in
                btn.setTitle("play and cut", for: .normal)
                btn.setTitleColor(.purple, for: .normal)
            }
            .rx.tap.subscribe(onNext: { [unowned self] (_) in
                self.player.play()
                self.imageView.image = VideoEditingManager.shared.getImageFromVideo(asset: self.asset, shotTime: CMTimeGetSeconds(self.player.currentTime()))
            }).disposed(by: disposeBag)
        
        imageView
            .soap.adhere(toSuperView: view)
            .soap.layout { (make) in
                make.centerX.equalToSuperview()
                make.centerY.equalToSuperview().offset(200)
                make.size.equalTo(CGSize(width: 300, height: 300 * 9/16))
            }
            .soap.config { (imageV) in
                imageV.contentMode = .scaleAspectFit
                imageV.layer.contentsScale = UIScreen.main.scale
        }
        
        player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 1), queue: DispatchQueue.main) { (time) in
            self.playerTime = time
            DispatchQueue.main.async {
                
            }
        }
        
    }
    
    private var playerTime: CMTime?
    private var asset: AVAsset!
    private var player: AVPlayer!
    private let imageView = UIImageView()
    private let disposeBag = DisposeBag()
    
}
