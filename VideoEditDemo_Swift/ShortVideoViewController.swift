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
                btn.setTitle("play", for: .normal)
                btn.setTitleColor(.purple, for: .normal)
            }
            .rx.tap.subscribe(onNext: { [unowned self] (_) in
                self.player.play()
//                self.p_cropVideo()
                self.p_getImageFromVideo(asset: self.asset, shortTime: CMTimeGetSeconds(self.player.currentTime()))
//                self.p_dropVideo(videoUrl: URL(string: "http://120.25.226.186:32812/resources/videos/minion_01.mp4")!, audioUrl: nil, captureRange: NSMakeRange(0, 3))
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
    
    /// 从视频中获取指定时间点的截图
    ///
    /// - Parameters:
    ///   - asset: 视频资源
    ///   - shortTime: 截取时间点
    /// - Returns: 截取的图片资源
    private func p_getImageFromVideo(asset: AVAsset, shortTime: Double) -> UIImage? {
        guard asset.tracks(withMediaType: .video).count > 0 else { return nil }
        
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.requestedTimeToleranceAfter = kCMTimeZero
        imageGenerator.requestedTimeToleranceBefore = CMTime(seconds: 1, preferredTimescale: 1)
        
        let shortPoint = CMTimeMakeWithSeconds(shortTime, 600)
        var actualTime = CMTime()
        let imageRef = try? imageGenerator.copyCGImage(at: shortPoint, actualTime: &actualTime)
        
        if let imageRef = imageRef {
            imageView.image = UIImage(cgImage: imageRef)
            print(CMTimeCopyDescription(nil, shortPoint) ?? "nil")
            print(CMTimeCopyDescription(nil, actualTime) ?? "nil")
            return UIImage(cgImage: imageRef)
        }
        return nil
    }
    
    private func p_dropVideo(videoUrl: URL, audioUrl: URL?, captureRange: NSRange) {
        let videoAsset = AVURLAsset(url: videoUrl)
        var audioAsset: AVURLAsset
        audioAsset = videoAsset
        if let audioUrl = audioUrl {
            audioAsset = AVURLAsset(url: audioUrl)
        }
        
        // 创建AVMutableComposition对象来添加视频音频资源的AVMutableCompositionTrack
        let mixConposition = AVMutableComposition()
        
        // 开始位置startTime
        let startTime = CMTimeMakeWithSeconds(Float64(captureRange.location), videoAsset.duration.timescale)
        // 截取长度videoDuration
        let videoDuration = CMTimeMakeWithSeconds(Float64(captureRange.length), videoAsset.duration.timescale)
        
        let videoTimeRange = CMTimeRangeMake(startTime, videoDuration)
        let audioTimeRange = CMTimeRangeMake(startTime, videoDuration)
        
        // 视频采集compositionVideoTrack
        let compositionVideoTrack = mixConposition.addMutableTrack(withMediaType: AVMediaType.video, preferredTrackID: kCMPersistentTrackID_Invalid)
        if let videoAssetTrack = videoAsset.tracks(withMediaType: AVMediaType.video).first {
            try? compositionVideoTrack?.insertTimeRange(videoTimeRange, of: videoAssetTrack, at: kCMTimeZero)
        }
        
        // 音频采集compositionAudioTrack
        let compositionAudioTrack = mixConposition.addMutableTrack(withMediaType: AVMediaType.audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        if let audioAssetTrack = audioAsset.tracks(withMediaType: AVMediaType.audio).first {
            try? compositionAudioTrack?.insertTimeRange(audioTimeRange, of: audioAssetTrack, at: kCMTimeZero)
        }
        
        // AVAssetExportSession用于合并文件，导出合并后文件，presetName文件的输出类型
        let assetExportSession = AVAssetExportSession(asset: mixConposition, presetName: AVAssetExportPresetPassthrough)
        let outputPath = NSTemporaryDirectory().appending("MixVideo.mp4")
        // 混合后的视频输出路径
        //        let outputPath = NSHomeDirectory().appending("/MixVideo.mov")
        print(outputPath)
        let outputUrl = URL(string: outputPath)
        if FileManager.default.fileExists(atPath: outputPath) {
            try? FileManager.default.removeItem(atPath: outputPath)
        }
        
        //输出视频格式 AVFileTypeMPEG4 AVFileTypeQuickTimeMovie...
        assetExportSession?.outputFileType = AVFileType.mp4
        assetExportSession?.outputURL = outputUrl
        assetExportSession?.shouldOptimizeForNetworkUse = true
        assetExportSession?.exportAsynchronously(completionHandler: {
            
            switch assetExportSession!.status {
            case .completed:
                print("completionHandler")
            case .exporting:
                print("exporting")
            default:
                print(assetExportSession?.error)
            }
            
        })
        
    }
    
    //    private func p_cropVideo() {
    //        let path = Bundle.main.path(forResource: "cropVideo", ofType: ".mp4")
    //
    //        let videoAsset = AVAsset(url: URL(string: "http://120.25.226.186:32812/resources/videos/minion_01.mp4")!)
    //
    //        var isWXVideo: Bool
    //
    //        for item in videoAsset.metadata {
    //
    //            print("-----------identifier-----------------")
    //            print(item.identifier ?? "nil")
    //            print("-----------extraAttributes-----------------")
    //            print(item.extraAttributes ?? "nil")
    //            print("-----------value-----------------")
    //            print(item.value ?? "nil")
    //            print("-----------dataType-----------------")
    //            print(item.dataType ?? "nil")
    //
    //
    //        }
    //    }
}
