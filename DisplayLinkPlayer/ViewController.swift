//
//  ViewController.swift
//  DisplayLinkPlayer
//
//  Created by anthrgrnwrld on 2018/03/05.
//  Copyright © 2018年 anthrgrnwrld. All rights reserved.
//

import UIKit
import AVFoundation
import Photos

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, AVPlayerItemOutputPullDelegate {
	
	@IBOutlet weak var sampleBufferDiaplayLayerView: SampleBufferDisplayLayerView!
	
	var player: AVPlayer {
		return sampleBufferDiaplayLayerView.player
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
	}
	
	// playItemEndTimeObserving
	var playItemEndTimeObserver: AnyObject! {
		didSet {
			if oldValue != nil && !oldValue.isEqual(playItemEndTimeObserver) {
				NotificationCenter.default.removeObserver(oldValue)
			}
		}
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		playItemEndTimeObserver = NotificationCenter.default.addObserver(
			forName: NSNotification.Name.AVPlayerItemDidPlayToEndTime,
			object: nil,
			queue: nil) { note in }
	}
	
	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
	}
	
	@IBAction func pressMovieLibraryButton(_ sender: Any) {
		
		//引数よりSourceTypeを指定
		var pickerSourceType: UIImagePickerControllerSourceType
		pickerSourceType = .photoLibrary
		
		//Libraryにアクセス出来るか確認. 出来なければreturn.
		guard UIImagePickerController.isSourceTypeAvailable(pickerSourceType) else {
			print("Cannot access PickerControllerSourceType.")
			return
		}
		
		let pickerController = UIImagePickerController()   //ImagePickerControllerをインスタンス化
		pickerController.delegate = self                   //delegateを自身に設定
		pickerController.sourceType = .savedPhotosAlbum
		pickerController.mediaTypes = ["public.movie"]
		pickerController.videoQuality = .typeHigh
		pickerController.modalPresentationStyle = .popover
		
		DispatchQueue.main.async() {
			self.present(pickerController, animated: true, completion: nil)   //imagePickerControllerに遷移
		}
	}
	
	@objc func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
		
		self.dismiss(animated: true, completion: nil)
		
		if let videoURL = info["UIImagePickerControllerReferenceURL"] as? URL {
			print("\(NSStringFromClass(self.classForCoder)).\(#function) is called!")
			
			let asset = AVURLAsset(url: videoURL)
			let item = AVPlayerItem(asset: asset)
			player.replaceCurrentItem(with: item)
		}
		
	}

	@IBAction func pressTogglePlayPause(_ sender: Any) {
		
		if player.rate == 0.0 {
			player.play()
		} else {
			player.pause()
		}
		
	}
	
	override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
		sampleBufferDiaplayLayerView.touchesBegan(touches, with: event)
	}
	
	override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
		sampleBufferDiaplayLayerView.touchesEnded(touches, with: event)
	}
	
}
