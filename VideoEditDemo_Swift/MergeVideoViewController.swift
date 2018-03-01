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

class MergeVideoViewController: UIViewController {
    
    @IBAction func loadAudio(_ sender: Any) {
//        let mediaPickerController = MPMediaPickerController(mediaTypes: .anyAudio)
//        mediaPickerController.allowsPickingMultipleItems = true
//        mediaPickerController.delegate = self
//        mediaPickerController.prompt = "选择音频"
//        mediaPickerController.loadView()
//        present(mediaPickerController, animated: true, completion: nil)
        let mediaQuery = MPMediaQuery.songs()
        print(mediaQuery)
    }
    
    @IBAction func loadAsset(_ sender: UIButton) {
        currentTag = sender.tag
        p_startMediaBrowserFromViewController(self, usingDelegate: self)
    }
    
    @IBAction func merge(_ sender: UIButton) {
        p_mergeVideo()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    @objc private func video(path: String, didFinishSavingWithError error: NSError?, contextInfo: Any) {
        if error != nil {
            print(error ?? "error")
            let alert = UIAlertController(title: "错误", message: "保存失败", preferredStyle: .actionSheet)
            let action = UIAlertAction(title: "确定", style: .default, handler: nil)
            
            alert.addAction(action)
            present(alert, animated: true, completion: nil)
        } else {
            let alert = UIAlertController(title: "保存成功", message: "保存到本地相册", preferredStyle: .alert)
            let action = UIAlertAction(title: "确定", style: .default, handler: nil)
            
            alert.addAction(action)
            present(alert, animated: true, completion: nil)
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
                    UISaveVideoAtPathToSavedPhotosAlbum(outputURL.path, self, #selector(video(path:didFinishSavingWithError:contextInfo:)), nil)
                }
            }
        }
    }
    
    private func p_mergeVideo() {
        guard let firstAsset = firstAsset, let secondAsset = secondAsset else {
            return
        }
        
        // Create AVMutableComposition object. This object will hold your AVMutableCompositionTrack instances.
        let mixComposition = AVMutableComposition()
        // Video track
        if let videoTrack = mixComposition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
           let firstAssetTrack = firstAsset.tracks(withMediaType: AVMediaType.video).first,
           let secondAssetTrack = secondAsset.tracks(withMediaType: AVMediaType.video).first {
            
            do {
                try videoTrack.insertTimeRange(CMTimeRangeMake(kCMTimeZero, firstAsset.duration), of: firstAssetTrack, at: kCMTimeZero)
                try videoTrack.insertTimeRange(CMTimeRangeMake(kCMTimeZero, secondAsset.duration), of: secondAssetTrack, at: firstAsset.duration)
            } catch _ {
                print("Failed to load first track")
            }
        }
        
        // Audio track
        if let audioTrack = mixComposition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid),
           let firstAudioTrack = firstAsset.tracks(withMediaType: .audio).first,
           let secondAudioTrack = secondAsset.tracks(withMediaType: .audio).first {
            
            do {
                try audioTrack.insertTimeRange(CMTimeRangeMake(kCMTimeZero, firstAsset.duration), of: firstAudioTrack, at: kCMTimeZero)
                try audioTrack.insertTimeRange(CMTimeRangeMake(kCMTimeZero, secondAsset.duration), of: secondAudioTrack, at: firstAsset.duration)
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
        exporter.videoComposition = p_makeVideoSquare(mixComposition.tracks(withMediaType: .video).first!)
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
    
    private func p_makeVideoSquare(_ assetTrack: AVAssetTrack) -> AVMutableVideoComposition {
        // Make it square
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = CGSize(width: assetTrack.naturalSize.height, height: assetTrack.naturalSize.height)
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRangeMake(kCMTimeZero, CMTimeMakeWithSeconds(60, 30))
        
        // rotate to portrait
        let transformer = AVMutableVideoCompositionLayerInstruction(assetTrack: assetTrack)
        let t1 = CGAffineTransform(translationX: assetTrack.naturalSize.height, y: -(assetTrack.naturalSize.width-assetTrack.naturalSize.height)/2)
        let t2 = t1.rotated(by: .pi/2)
        
        let finalTransform = t2
        transformer.setTransform(finalTransform, at: kCMTimeZero)
        instruction.layerInstructions = [transformer]
        videoComposition.instructions = [instruction]
        
        return videoComposition
    }
    
    private var currentTag: Int = 0
    private var firstAsset: AVAsset?
    private var secondAsset: AVAsset?
}

extension MergeVideoViewController: MPMediaPickerControllerDelegate {
    
}

extension MergeVideoViewController: UIImagePickerControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        guard let mediaType = info[UIImagePickerControllerMediaType] else { return }
        
        dismiss(animated: false, completion: nil)
        
        if CFStringCompare(mediaType as! CFString, kUTTypeMovie, CFStringCompareFlags(rawValue: 0)) == .compareEqualTo {
            
            if let mediaURL = info[UIImagePickerControllerMediaURL] as? URL {
                switch currentTag {
                case 1:
                    firstAsset = AVAsset(url: mediaURL)
                case 2:
                    secondAsset = AVAsset(url: mediaURL)
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
