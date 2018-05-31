//
//  SampleBufferDisplayLayerView.swift
//  DisplayLinkPlayer
//
//  Created by anthrgrnwrld on 2018/03/19.
//  Copyright © 2018年 anthrgrnwrld. All rights reserved.
//

import UIKit
import AVFoundation

class SampleBufferDisplayLayerView: UIView, AVPlayerItemOutputPullDelegate {
	
	override public class var layerClass: Swift.AnyClass {
		get {
			return AVSampleBufferDisplayLayer.self
		}
	}
	
	let player = AVPlayer()
	
	required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
		player.addObserver(self, forKeyPath: "currentItem", options: [.new], context: nil)
		playerItemVideoOutput.setDelegate(self, queue: queue)
		playerItemVideoOutput.requestNotificationOfMediaDataChange(withAdvanceInterval: advancedInterval)
		displayLink = CADisplayLink(target: self, selector: #selector(displayLinkCallback(_:)))
		displayLink.preferredFramesPerSecond = 1 / 30
		displayLink.isPaused = true
		displayLink.add(to: RunLoop.current, forMode: RunLoopMode.defaultRunLoopMode)	//タイマーを開始
	}
	
	// KVO
	override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
		switch keyPath {
		case "currentItem"?:
			if let item = change![NSKeyValueChangeKey.newKey] as? AVPlayerItem {
				item.add(playerItemVideoOutput)
				videoLayer.controlTimebase = item.timebase
			}
		default:
			//super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
			break
		}
	}
	
	// MARK: AVPlayerItemOutputPullDelegate
	func outputMediaDataWillChange(_ sender: AVPlayerItemOutput) {
		print("outputMediaDataWillChange")
		displayLink.isPaused = false
	}
	
	func outputSequenceWasFlushed(_ output: AVPlayerItemOutput) {
		videoLayer.controlTimebase = player.currentItem?.timebase
		videoLayer.flush()
	}
	
	//private
	private let playerItemVideoOutput = AVPlayerItemVideoOutput(pixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String : kCVPixelFormatType_32ARGB])	// ピクセルフォーマット(32bit BGRA)
	private let queue = DispatchQueue.main
	private let advancedInterval: TimeInterval = 0.1
	private var displayLink: CADisplayLink!
	private var lastTimestamp: CFTimeInterval = 0
	private var videoInfo: CMVideoFormatDescription?
	
	private var videoLayer: AVSampleBufferDisplayLayer {
		return self.layer as! AVSampleBufferDisplayLayer
	}
	
	/**
	setCADiplayLinkSettingに呼び出されるselector。
	*/
	@objc private func displayLinkCallback(_ displayLink: CADisplayLink) {
		
		let nextOutputHostTime = displayLink.timestamp + displayLink.duration * CFTimeInterval(displayLink.preferredFramesPerSecond)
		let nextOutputItemTime = playerItemVideoOutput.itemTime(forHostTime: nextOutputHostTime)
		if playerItemVideoOutput.hasNewPixelBuffer(forItemTime: nextOutputItemTime) {
			lastTimestamp = displayLink.timestamp
			var presentationItemTime = kCMTimeZero
			let pixelBuffer = playerItemVideoOutput.copyPixelBuffer(forItemTime: nextOutputItemTime, itemTimeForDisplay: &presentationItemTime)
			displayPixelBuffer(pixelBuffer: pixelBuffer!, atTime: presentationItemTime)
		} else {
			if displayLink.timestamp - lastTimestamp > 0.5 {
				displayLink.isPaused = true
				playerItemVideoOutput.requestNotificationOfMediaDataChange(withAdvanceInterval: advancedInterval)
			}
		}
	}

	@objc private func displayPixelBuffer(pixelBuffer: CVPixelBuffer, atTime outputTime: CMTime) {
		
		var err: OSStatus = noErr
		
		if videoInfo == nil {
			err = CMVideoFormatDescriptionCreateForImageBuffer(nil, pixelBuffer, &videoInfo)

			if (err != noErr) {
				print("Error at CMVideoFormatDescriptionCreateForImageBuffer \(err)")
			}
			
		}
		
		var sampleTimingInfo = CMSampleTimingInfo(duration: kCMTimeInvalid, presentationTimeStamp: outputTime, decodeTimeStamp: kCMTimeInvalid)
		
		var sampleBuffer: CMSampleBuffer?
		err = CMSampleBufferCreateForImageBuffer(nil, pixelBuffer, true, nil, nil, videoInfo!, &sampleTimingInfo, &sampleBuffer)
		if (err != noErr) {
			NSLog("Error at CMSampleBufferCreateForImageBuffer \(err)")
		}
		
		if videoLayer.isReadyForMoreMediaData {
			videoLayer.enqueue(sampleBuffer!)
		}

		sampleBuffer = nil
	}
}
