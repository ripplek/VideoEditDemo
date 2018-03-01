//
//  RecordVideoViewController.swift
//  VideoEditDemo_Swift
//
//  Created by ripple_k on 2018/2/26.
//  Copyright © 2018年 mac. All rights reserved.
//

import UIKit
import MediaPlayer
import MobileCoreServices
import AssetsLibrary

class RecordVideoViewController: UIViewController {

    @IBAction func recordAndPlay(_ sender: Any) {
        startCameraControllerFromViewController(self, usingDelegate: self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
    }

    private func startCameraControllerFromViewController(_ controller: UIViewController, usingDelegate delegate: UIImagePickerControllerDelegate & UINavigationControllerDelegate) {
        // Validattions
        guard UIImagePickerController
                .isSourceTypeAvailable(UIImagePickerControllerSourceType.camera) else { return }
        // Get image picker
        let cameraUI = UIImagePickerController()
        cameraUI.sourceType = .camera
        // Displays a control that allows the user to choose movie capture
        cameraUI.mediaTypes = [kUTTypeMovie as String]
        // Hides the controls for moving & scaling pictures, or for trimming movies. To instead show the controls, use true.
        cameraUI.allowsEditing = false
        cameraUI.delegate = delegate
        // Display image picker
        controller.present(cameraUI, animated: true, completion: nil)
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
}

extension RecordVideoViewController: UIImagePickerControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        guard let mediaType = info[UIImagePickerControllerMediaType] else { return }
        
        dismiss(animated: false, completion: nil)
        // Handle a movie capture
        if CFStringCompare(mediaType as! CFString, kUTTypeMovie, CFStringCompareFlags(rawValue: 0)) == .compareEqualTo {
            if let moviePath = info[UIImagePickerControllerMediaURL] as? URL {
                if UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(moviePath.path) {
                    UISaveVideoAtPathToSavedPhotosAlbum(moviePath.path, self, #selector(video(path:didFinishSavingWithError:contextInfo:)), nil)
                }
            }
        }
    }
}

extension RecordVideoViewController: UINavigationControllerDelegate { }
