//
//  MergeVideoViewController.swift
//  VideoEditDemo_Swift
//
//  Created by ripple_k on 2018/2/26.
//  Copyright © 2018年 mac. All rights reserved.
//

import UIKit
import MediaPlayer
import MobileCoreServices
import AssetsLibrary
import AVKit
import Photos

enum VideoOrientation {
    case up, down, left, right, notFound
}

class MergeVideoViewController: UIViewController {
    
    @IBAction func loadAudio(_ sender: Any) {
//        let mediaPickerController = MPMediaPickerController(mediaTypes: .anyAudio)
//        mediaPickerController.allowsPickingMultipleItems = true
//        mediaPickerController.delegate = self
//        mediaPickerController.prompt = "选择音频"
//        mediaPickerController.loadView()
//        present(mediaPickerController, animated: true, completion: nil)
//        let mediaQuery = MPMediaQuery.songs()
//        print(mediaQuery)
    }
    
    @IBAction func loadAsset(_ sender: UIButton) {
        _currentTag = sender.tag
        p_startMediaBrowserFromViewController(self, usingDelegate: self)
    }
    
    @IBAction func merge(_ sender: UIButton) {
        if let firstAsset = _firstAsset, let secondAsset = _secondAsset {
//            p_mergeVideo([firstAsset, secondAsset])
            VideoEditingManager.shared.mergeVideo([firstAsset, secondAsset])
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    static func showAlert(controller: UIViewController, title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let action = UIAlertAction(title: "确定", style: .default, handler: nil)
        
        alert.addAction(action)
        controller.present(alert, animated: true, completion: nil)
    }
    
    private var _currentTag: Int = 0
    private var _firstAsset: AVAsset?
    private var _secondAsset: AVAsset?
    
    @objc private func p_video(path: String, didFinishSavingWithError error: NSError?, contextInfo: Any) {
        if error != nil {
            print(error ?? "error")
            MergeVideoViewController.showAlert(controller: self, title: "错误", message: "保存失败\n\(error!.localizedDescription)")
        } else {
            MergeVideoViewController.showAlert(controller: self, title: "保存成功", message: "保存到本地相册")
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
    
    private func p_exportDidFinish(session: AVAssetExportSession) {
        if session.status == .completed {
            if let outputURL = session.outputURL {
                if UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(outputURL.path) {
                    UISaveVideoAtPathToSavedPhotosAlbum(outputURL.path, self, #selector(p_video), nil)
                }
            }
        }
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
        let documentDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .short
        let date = dateFormatter.string(from: Date())
        let savePath = documentDirectory.appending("/mergeVideo-\(date).mov")
        let outputURL = URL(fileURLWithPath: savePath)
        
        // Create Exporter
        guard let exporter = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetHighestQuality) else { return }
        exporter.videoComposition = p_makeVideoSquare(mixAsset: mixComposition, unmixAssets: assets)
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

extension MergeVideoViewController: MPMediaPickerControllerDelegate {
    
}

extension MergeVideoViewController: UIImagePickerControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        guard let mediaType = info[UIImagePickerControllerMediaType] else { return }
        
        dismiss(animated: false, completion: nil)
        
        if CFStringCompare(mediaType as! CFString, kUTTypeMovie, CFStringCompareFlags(rawValue: 0)) == .compareEqualTo {
            
            if let mediaURL = info[UIImagePickerControllerMediaURL] as? URL {
                switch _currentTag {
                case 1:
                    _firstAsset = AVAsset(url: mediaURL)
                case 2:
                    _secondAsset = AVAsset(url: mediaURL)
                default:
                    break
                }
            }
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
}

extension MergeVideoViewController: UINavigationControllerDelegate {
    
}
