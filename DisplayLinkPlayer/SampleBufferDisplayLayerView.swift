//
//  SampleBufferDisplayLayerView.swift
//  DisplayLinkPlayer
//
//  Created by anthrgrnwrld on 2018/03/19.
//  Copyright © 2018年 anthrgrnwrld. All rights reserved.
//

import UIKit
import AVFoundation
import Vision

class SampleBufferDisplayLayerView: UIView, AVPlayerItemOutputPullDelegate {
	
	private var requestHandler: VNSequenceRequestHandler = VNSequenceRequestHandler()
	private var lastObservation: VNDetectedObjectObservation?
	private lazy var highlightView: UIView = {
		let view = UIView()
		view.layer.borderColor = UIColor.white.cgColor
		view.layer.borderWidth = 4
		view.backgroundColor = .clear
		return view
	}()
	private var isTouched: Bool = false
	
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
		
		let ciImage:CIImage = CIImage(cvPixelBuffer: pixelBuffer)
		let orientation:CGImagePropertyOrientation = CGImagePropertyOrientation.right
		let targetCIImage = ciImage.oriented(orientation)	//回転させたい時はこっち
//		let targetCIImage = ciImage							//回転させたくない時はこっち
		
		let targetPixelBuffer:CVPixelBuffer = convertFromCIImageToCVPixelBuffer(ciImage: targetCIImage)!
		
		if videoInfo == nil {
			err = CMVideoFormatDescriptionCreateForImageBuffer(nil, targetPixelBuffer, &videoInfo)

			if (err != noErr) {
				print("Error at CMVideoFormatDescriptionCreateForImageBuffer \(err)")
			}
			
		}
		
		detectObject(pixelBuffer: targetPixelBuffer)
		
		var sampleTimingInfo = CMSampleTimingInfo(duration: kCMTimeInvalid, presentationTimeStamp: outputTime, decodeTimeStamp: kCMTimeInvalid)
		
		var sampleBuffer: CMSampleBuffer?
		err = CMSampleBufferCreateForImageBuffer(nil, targetPixelBuffer, true, nil, nil, videoInfo!, &sampleTimingInfo, &sampleBuffer)
		if (err != noErr) {
			NSLog("Error at CMSampleBufferCreateForImageBuffer \(err)")
		}
		
		if videoLayer.isReadyForMoreMediaData {
			videoLayer.enqueue(sampleBuffer!)
		}

		sampleBuffer = nil
	}
	

	
	
	private func convertFromCIImageToCVPixelBuffer (ciImage:CIImage) -> CVPixelBuffer? {
		let size:CGSize = ciImage.extent.size
		var pixelBuffer:CVPixelBuffer?
		let options = [
			kCVPixelBufferCGImageCompatibilityKey as String: true,
			kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
			kCVPixelBufferIOSurfacePropertiesKey as String: [:]
			] as [String : Any]
		
		let status:CVReturn = CVPixelBufferCreate(kCFAllocatorDefault,
												  Int(size.width),
												  Int(size.height),
												  kCVPixelFormatType_32BGRA,
												  options as CFDictionary,
												  &pixelBuffer)
		
		
		CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
		CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
		
		let ciContext = CIContext()
		
		if (status == kCVReturnSuccess && pixelBuffer != nil) {
			ciContext.render(ciImage, to: pixelBuffer!)
		}
		
		return pixelBuffer
	}
	
	
	private func detectObject (pixelBuffer: CVPixelBuffer) {
		
		guard
			let lastObservation = self.lastObservation
			else {
				requestHandler = VNSequenceRequestHandler()
				return
		}
		
		if self.isTouched { return }
		
		let request = VNTrackObjectRequest(detectedObjectObservation: lastObservation, completionHandler: update)
		
		request.trackingLevel = .accurate
		
		do {
			try requestHandler.perform([request], on: pixelBuffer)	//画像処理の実行
		} catch {
			print("Throws: \(error)")
		}
		
	}
	
	
	private func update(_ request: VNRequest, error: Error?) {
		
		DispatchQueue.main.async {
			guard let newObservation = request.results?.first as? VNDetectedObjectObservation else { return }

			self.lastObservation = newObservation
			guard newObservation.confidence >= 0.3 else {
				self.highlightView.frame = .zero
				return
			}
			var transformedRect = newObservation.boundingBox
			transformedRect.origin.y = 1 - transformedRect.origin.y
			
			let t = CGAffineTransform(scaleX: self.frame.size.width, y: self.frame.size.height)
			let convertedRect = transformedRect.applying(t)
			self.highlightView.frame = convertedRect
		}
	}
	
	//ViewControllerのtouchesBeganの中の処理でSampleBufferDisplayLayerView.touchBeganを呼び出してあげる
	override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
		highlightView.frame = .zero
		lastObservation = nil
		isTouched = true
	}
	
	//ViewControllerのtouchesEndedの中の処理でSampleBufferDisplayLayerView.touchesEndedを呼び出してあげる
	override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
		guard let touch: UITouch = touches.first else { return }
		highlightView.frame.size = CGSize(width: 90, height: 90)
		highlightView.center = touch.location(in: self)
		isTouched = false
		
		let t = CGAffineTransform(scaleX: 1.0 / self.frame.size.width, y: 1.0 / self.frame.size.height)
		var normalizedTrackImageBoundingBox = highlightView.frame.applying(t)
		normalizedTrackImageBoundingBox.origin.y = 1 - normalizedTrackImageBoundingBox.origin.y
		lastObservation = VNDetectedObjectObservation(boundingBox: normalizedTrackImageBoundingBox)
		self.addSubview(highlightView)
	}
	
}
