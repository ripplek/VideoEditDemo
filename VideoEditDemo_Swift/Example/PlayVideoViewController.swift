//
//  PlayVideoViewController.swift
//  VideoEditDemo_Swift
//
//  Created by ripple_k on 2018/2/26.
//  Copyright © 2018年 mac. All rights reserved.
//

import UIKit
import MobileCoreServices
import MediaPlayer
import AVFoundation
import AVKit
import Photos

class PlayVideoViewController: UIViewController {

    @IBAction func playVideo(_ sender: UIButton) {
        startMediaBrowserFromViewController(self, usingDelegate: self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
    }

    private func startMediaBrowserFromViewController(_ viewController: UIViewController, usingDelegate delegate: UIImagePickerControllerDelegate & UINavigationControllerDelegate) {
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
}

extension PlayVideoViewController: UIImagePickerControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        guard let mediaType = info[UIImagePickerControllerMediaType] else { return }

        dismiss(animated: false, completion: nil)

        if CFStringCompare(mediaType as! CFString, kUTTypeMovie, CFStringCompareFlags(rawValue: 0)) == .compareEqualTo {
            let theMovie = AVPlayerViewController()
            if let mediaURL = info[UIImagePickerControllerMediaURL] as? URL {
                theMovie.player = AVPlayer(url: mediaURL)
                present(theMovie, animated: false, completion: nil)
            }
        }
        
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
}

extension PlayVideoViewController: UINavigationControllerDelegate {
    
}
