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
	
	var player: AVPlayer {
		return (view as! SampleBufferDisplayLayerView).player
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		// Do any additional setup after loading the view, typically from a nib.
		checkPermission()
		
	}
	
	// playItemEndTimeObserving
	var playItemEndTimeObserver: AnyObject! {
		didSet {
			if oldValue != nil && !oldValue.isEqual(playItemEndTimeObserver) {
				NotificationCenter.default.removeObserver(oldValue)
			}
		}
	}
	var playItemDidReachEndTime = false
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		playItemEndTimeObserver = NotificationCenter.default.addObserver(
			forName: NSNotification.Name.AVPlayerItemDidPlayToEndTime,
			object: nil,
			queue: nil) {
				note in
				if note.object as? AVPlayerItem == self.player.currentItem {
					self.playItemDidReachEndTime = true
				}
		}
		
	}
	
	override func viewWillDisappear(_ animated: Bool) {
		playItemEndTimeObserver = nil
	}
	
	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}
	
	func checkPermission() {
		let photoAuthorizationStatus = PHPhotoLibrary.authorizationStatus()
		switch photoAuthorizationStatus {
		case .authorized:
			print("Access is granted by user")
		case .notDetermined:
			PHPhotoLibrary.requestAuthorization({
				(newStatus) in
				print("status is \(newStatus)")
				if newStatus ==  PHAuthorizationStatus.authorized {
					/* do stuff here */
					print("success")
				}
			})
			print("It is not determined until now")
		case .restricted:
			// same same
			print("User do not have access to photo album.")
		case .denied:
			// same same
			print("User has denied the permission.")
		}
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
		//pickerController.sourceType = pickerSourceType     //カメラとライブラリどちらを表示するか指定
		pickerController.sourceType = .savedPhotosAlbum
		pickerController.mediaTypes = ["public.movie"]
		pickerController.videoQuality = .typeHigh
		pickerController.modalPresentationStyle = .popover
		
		pickerController.modalPresentationStyle = .popover
		let popPC = pickerController.popoverPresentationController
		popPC?.permittedArrowDirections = .any
		popPC?.barButtonItem = self.navigationItem.rightBarButtonItem
		
		DispatchQueue.main.async() {
			self.present(pickerController, animated: true, completion: nil)   //imagePickerControllerに遷移
		}
	}
	
	@objc func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
		
		self.dismiss(animated: true, completion: nil)
		
		if let videoURL = info["UIImagePickerControllerReferenceURL"] as? URL {
			print("\(NSStringFromClass(self.classForCoder)).\(#function) is called!")
			//let item = AVPlayerItem(url: videoURL)
			let asset = AVURLAsset(url: videoURL)
			let item = AVPlayerItem(asset: asset)
			player.replaceCurrentItem(with: item)
		}
		
		
		
	}

	@IBAction func pressTogglePlayPause(_ sender: Any) {

		if player.rate == 0.0 {
			let hostTimeNow = CMClockGetTime(CMClockGetHostTimeClock())
			let hostTimeDelta = CMTimeMakeWithSeconds(0.01, hostTimeNow.timescale)
			if playItemDidReachEndTime {
				playItemDidReachEndTime = false
				//player.setRate(1.0, time: kCMTimeZero, atHostTime: hostTimeNow)
				player.play()// だと再度再生できない。
			} else {
				//player.setRate(1.0, time: kCMTimeInvalid, atHostTime: hostTimeNow)
				player.play()
			}
		} else {
			player.pause()
		}
		
	}
	


}
