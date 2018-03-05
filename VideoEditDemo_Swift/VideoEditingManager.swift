//
//  VideoEditingManager.swift
//  VideoEditDemo_Swift
//
//  Created by ripple_k on 2018/3/5.
//  Copyright © 2018年 mac. All rights reserved.
//

import UIKit
import AVFoundation
import MobileCoreServices

public protocol VideoEditingDelegate: NSObjectProtocol {
    func videoExportWillStart(session: AVAssetExportSession)
    func videoExportDidFinish(session: AVAssetExportSession)
}

public class VideoEditingManager: NSObject {
    // MARK: - public
    
    /// singleton
    public static let shared = VideoEditingManager()
    
    /// VideoEditingDelegate
    public weak var delegate: VideoEditingDelegate?
    
    /// VideoOutputPath
    public var defaultPath = URL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!)
    
    /// Take a screenshot of the specified time point from video.
    ///
    /// - Parameters:
    ///   - asset: Video asset
    ///   - shotTime: Shot time in video
    /// - Returns: Image form video
    public func getImageFromVideo(asset: AVAsset, shotTime: Double) -> UIImage? {
        return p_getImageFromVideo(asset: asset, shotTime: shotTime)
    }
    
    /// Merge multiple video.
    ///
    /// - Parameters:
    ///   - assets: Video assets
    ///   - savePath: Video output path default is `defaultPath`
    public func mergeVideo(_ assets: [AVAsset], savePath: URL? = nil) {
        if let savePath = savePath {
            defaultPath = savePath
        }
        p_mergeVideo(assets)
    }
    
    /// The video clip.
    ///
    /// - Parameters:
    ///   - asset: Video asset
    ///   - ranges: Video clip time segment
    ///   - savePath: Video output path default is `defaultPath`
    public func editAndSynthesizeVideo(_ asset: AVAsset, ranges: [(starTime: Float64, duration: Float64)], savePath: URL? = nil) {
        if let savePath = savePath {
            defaultPath = savePath
        }
        p_editAndSynthesizeVideo(asset, ranges: ranges)
    }
    
    // MARK: - private
    
    private func p_getImageFromVideo(asset: AVAsset, shotTime: Double) -> UIImage? {
        guard asset.tracks(withMediaType: .video).count > 0 else { return nil }
        
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.requestedTimeToleranceAfter = kCMTimeZero
        imageGenerator.requestedTimeToleranceBefore = CMTime(seconds: 1, preferredTimescale: 1)
        
        let shortPoint = CMTimeMakeWithSeconds(shotTime, 600)
        var actualTime = CMTime()
        let imageRef = try? imageGenerator.copyCGImage(at: shortPoint, actualTime: &actualTime)
        
        if let imageRef = imageRef {
            return UIImage(cgImage: imageRef)
        }
        return nil
    }
    
    private func p_mergeVideo(_ assets: [AVAsset]) {
        guard assets.count >= 2 else {
            print("Merge assets.count < 2")
            return
        }
        
        // Create AVMutableComposition object. This object will hold your AVMutableCompositionTrack instances.
        let mixComposition = AVMutableComposition()
        // Video track
        if let videoTrack = mixComposition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) {
            
            do {
                var beforeAsset: AVAsset?
                for asset in assets {
                    if let track = asset.tracks(withMediaType: .video).first {
                        try videoTrack.insertTimeRange(CMTimeRangeMake(kCMTimeZero, asset.duration), of: track, at: beforeAsset?.duration ?? kCMTimeZero)
                    }
                    beforeAsset = asset
                }
            } catch _ {
                print("Failed to load first track")
            }
        }
        
        // Audio track
        if let audioTrack = mixComposition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
            
            do {
                var beforeAsset: AVAsset?
                for asset in assets {
                    if let track = asset.tracks(withMediaType: .audio).first {
                        try audioTrack.insertTimeRange(CMTimeRangeMake(kCMTimeZero, asset.duration), of: track, at: beforeAsset?.duration ?? kCMTimeZero)
                    }
                    beforeAsset = asset
                }
            } catch _ {
                print("Failed to load audio track")
            }
        }
        
        // Get path
        let documentDirectory = defaultPath
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .short
        let date = dateFormatter.string(from: Date())
        let savePath = documentDirectory.appendingPathComponent("mergeVideo-\(date).mov", isDirectory: false)
        let outputURL = savePath
        
        // Create Exporter
        guard let exporter = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetHighestQuality) else { return }
        exporter.videoComposition = p_makeVideoSquare(mixAsset: mixComposition, unmixAssets: assets)
        exporter.outputURL = outputURL
        exporter.outputFileType = .mov
        exporter.shouldOptimizeForNetworkUse = true
        
        // Perform the Export
        delegate?.videoExportWillStart(session: exporter)
        exporter.exportAsynchronously {
            DispatchQueue.main.async {
                self.p_exportDidFinish(session: exporter)
            }
        }
    }
    
    private func p_editAndSynthesizeVideo(_ asset: AVAsset, ranges: [(starTime: Float64, duration: Float64)]) {
        // Create AVMutableComposition object. This object will hold your AVMutableCompositionTrack instances.
        let mixComposition = AVMutableComposition()
        // Video track
        if let videoTrack = mixComposition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) {
            
            do {
                var beforeTime = kCMTimeZero
                for range in ranges {
                    let starTime = CMTimeMakeWithSeconds(range.starTime, asset.duration.timescale)
                    let durationTime = CMTimeMakeWithSeconds(range.duration, asset.duration.timescale)
                    let videoRange = CMTimeRangeMake(starTime, durationTime)
                    
                    if let track = asset.tracks(withMediaType: .video).first {
                        try videoTrack.insertTimeRange(videoRange, of: track, at: beforeTime)
                    }
                    beforeTime = videoRange.duration
                }
            } catch _ {
                print("Failed to load first track")
            }
        }
        
        // Audio track
        if let audioTrack = mixComposition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
            
            do {
                var beforeTime = kCMTimeZero
                for range in ranges {
                    let starTime = CMTimeMakeWithSeconds(range.starTime, asset.duration.timescale)
                    let durationTime = CMTimeMakeWithSeconds(range.duration, asset.duration.timescale)
                    let audioRange = CMTimeRangeMake(starTime, durationTime)
                    
                    if let track = asset.tracks(withMediaType: .audio).first {
                        try audioTrack.insertTimeRange(audioRange, of: track, at: beforeTime)
                    }
                    beforeTime = audioRange.duration
                }
            } catch _ {
                print("Failed to load first track")
            }
        }
        
        // Get path
        let documentDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .short
        let date = dateFormatter.string(from: Date())
        let savePath = documentDirectory.appending("/mergeVideo-\(date).mov")
        let outputURL = URL(fileURLWithPath: savePath)
        
        // Create Exporter
        guard let exporter = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetHighestQuality) else { return }
        exporter.videoComposition = p_makeVideoSquare(mixAsset: mixComposition, unmixAssets: [asset])
        exporter.outputURL = outputURL
        exporter.outputFileType = .mov
        exporter.shouldOptimizeForNetworkUse = true
        
        // Perform the Export
        exporter.exportAsynchronously {
            DispatchQueue.main.async {
                self.p_exportDidFinish(session: exporter)
            }
        }
    }
    
    // MARK: - ExportDidFinish
    
    private func p_exportDidFinish(session: AVAssetExportSession) {
        guard let delegate = delegate else {
            if session.status == .completed {
                if let outputURL = session.outputURL {
                    if UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(outputURL.path) {
                        UISaveVideoAtPathToSavedPhotosAlbum(outputURL.path, self, #selector(p_video(path:didFinishSavingWithError:contextInfo:)), nil)
                    }
                }
            }
            
            if session.status == .failed {
                print("exportFailed:",
                      session.outputURL ?? "outputURL",
                      session.error?.localizedDescription ?? "error")
            }
            return
        }
        
        delegate.videoExportDidFinish(session: session)
    }
    
    @objc private func p_video(path: String, didFinishSavingWithError error: NSError?, contextInfo: Any) {
        if error != nil {
            print(error ?? "error")
            p_showAlert(controller: UIApplication.shared.keyWindow!.rootViewController!, title: "错误", message: "保存失败\n\(error!.localizedDescription)")
        } else {
            p_showAlert(controller: UIApplication.shared.keyWindow!.rootViewController!, title: "保存成功", message: "保存到本地相册")
        }
    }
    
    private func p_showAlert(controller: UIViewController, title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let action = UIAlertAction(title: "确定", style: .default, handler: nil)
        
        alert.addAction(action)
        controller.present(alert, animated: true, completion: nil)
    }
    
    // MARK: - Square
    
    private func p_makeVideoSquare(mixAsset: AVAsset, unmixAssets: [AVAsset]) -> AVMutableVideoComposition? {
        
        guard let assetTrack = mixAsset.tracks(withMediaType: .video).first else {
            return nil
        }
        // Make it square
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = CGSize(width: assetTrack.naturalSize.height, height: assetTrack.naturalSize.height)
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRangeMake(kCMTimeZero, CMTimeMakeWithSeconds(60, 30))
        
        // rotate to portrait
        let transformer = AVMutableVideoCompositionLayerInstruction(assetTrack: assetTrack)
        
        var beforeAsset: AVAsset?
        for asset in unmixAssets {
            if let assetTrack = asset.tracks(withMediaType: .video).first {
                
                let orientation = p_videoOrientation(asset: asset)
                let finalTransform = p_makeTransform(orientation: orientation, assetTrack: assetTrack)
                transformer.setTransform(finalTransform, at: beforeAsset?.duration ?? kCMTimeZero)
            }
            
            beforeAsset = asset
        }
        
        instruction.layerInstructions = [transformer]
        videoComposition.instructions = [instruction]
        
        return videoComposition
    }
    
    private func p_radiansToDegrees(_ radians: CGFloat) -> CGFloat {
        return radians * 180 / .pi
    }
    
    private func p_videoOrientation(asset: AVAsset) -> VideoOrientation {
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            return .notFound
        }
        
        let txf = videoTrack.preferredTransform
        let videoAngleInDegree = p_radiansToDegrees(atan2(txf.b, txf.a))
        
        var orientation: VideoOrientation
        switch Int(videoAngleInDegree) {
        case 0:
            orientation = .right
        case 90:
            orientation = .up
        case 180:
            orientation = .left
        case -90:
            orientation = .down
        default:
            orientation = .notFound
        }
        
        return orientation
    }
    
    private func p_makeTransform(orientation: VideoOrientation, assetTrack: AVAssetTrack) -> CGAffineTransform {
        let cropOffY = (assetTrack.naturalSize.width-assetTrack.naturalSize.height) / 2
        var t2: CGAffineTransform
        
        switch orientation {
        case .up:
            let t1 = CGAffineTransform(translationX: assetTrack.naturalSize.height, y: -cropOffY)
            t2 = t1.rotated(by: .pi/2)
        case .down:
            let t1 = CGAffineTransform(translationX: 0, y: assetTrack.naturalSize.width-cropOffY)
            t2 = t1.rotated(by: -.pi/2)
        case .right:
            let t1 = CGAffineTransform(translationX: 0, y: 0)
            t2 = t1.rotated(by: 0)
        case .left:
            let t1 = CGAffineTransform(translationX: assetTrack.naturalSize.width, y: assetTrack.naturalSize.height-cropOffY)
            t2 = t1.rotated(by: .pi)
        default:
            let t1 = CGAffineTransform(translationX: assetTrack.naturalSize.height, y: -cropOffY)
            t2 = t1.rotated(by: .pi/2)
        }
        return t2
    }
    
}

