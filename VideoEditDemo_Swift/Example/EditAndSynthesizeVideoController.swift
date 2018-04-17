//
//  EditAndSynthesizeVideoController.swift
//  VideoEditDemo_Swift
//
//  Created by ripple_k on 2018/3/2.
//  Copyright © 2018年 mac. All rights reserved.
//

import UIKit
import AVFoundation
import MobileCoreServices

class EditAndSynthesizeVideoController: UIViewController {
    
    @IBOutlet weak var starTimeTextField: UITextField!
    @IBOutlet weak var durationTimeTextField: UITextField!
    @IBOutlet weak var MessageLabel: UILabel!
    
    @IBAction func chooseVideoAsset(_ sender: UIButton) {
        p_startMediaBrowserFromViewController(self, usingDelegate: self)
    }
    
    @IBAction func addTimeRange(_ sender: UIButton) {
        if let star = Float64(starTimeTextField.text ?? ""), let duration = Float64(durationTimeTextField.text ?? "") {
            _timeRanges.append((star, duration))
            MessageLabel.text?.append("addTimeRange\((star, duration))\n")
        }
    }
    
    @IBAction func cutVideo(_ sender: UIButton) {
        guard let asset = _videoAsset, _timeRanges.count > 0 else {
            return
        }
        MessageLabel.text?.append("cutVideo...")
        VideoEditingManager.shared.editAndSynthesizeVideo(asset, ranges: _timeRanges)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    private var _videoAsset: AVAsset?
    private var _timeRanges: [(Float64, Float64)] = []
    
    @objc private func video(path: String, didFinishSavingWithError error: NSError?, contextInfo: Any) {
        if error != nil {
            print(error ?? "error")
            MergeVideoViewController.showAlert(controller: self, title: "错误", message: "保存失败\n\(error!.localizedDescription)")
        } else {
            MergeVideoViewController.showAlert(controller: self, title: "保存成功", message: "保存到本地相册")
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
    
    private func p_exportDidFinish(session: AVAssetExportSession) {
        if session.status == .completed {
            if let outputURL = session.outputURL {
                if UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(outputURL.path) {
                    UISaveVideoAtPathToSavedPhotosAlbum(outputURL.path, self, #selector(video(path:didFinishSavingWithError:contextInfo:)), nil)
                }
            }
        }
    }

    private func p_startMediaBrowserFromViewController(_ viewController: UIViewController, usingDelegate delegate: UIImagePickerControllerDelegate & UINavigationControllerDelegate) {
        guard UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceType.savedPhotosAlbum) else {
            return
        }
        
        let mediaUI = UIImagePickerController()
        mediaUI.sourceType = UIImagePickerControllerSourceType.savedPhotosAlbum
        mediaUI.mediaTypes = [kUTTypeMovie as String]
        mediaUI.allowsEditing = false
        mediaUI.delegate = delegate
        viewController.present(mediaUI, animated: true, completion: nil)
    }
    
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

extension EditAndSynthesizeVideoController: UIImagePickerControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        guard let mediaType = info[UIImagePickerControllerMediaType] else { return }
        
        dismiss(animated: false, completion: nil)
        
        if CFStringCompare(mediaType as! CFString, kUTTypeMovie, CFStringCompareFlags(rawValue: 0)) == .compareEqualTo {
            
            if let mediaURL = info[UIImagePickerControllerMediaURL] as? URL {
                _videoAsset = AVAsset(url: mediaURL)
            }
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
}

extension EditAndSynthesizeVideoController: UINavigationControllerDelegate { }
