//
//  SpatialGestureProvider.swift
//  HandGesture
//
//  Created by Yos Hashimoto on 2023/07/30.
//

import Foundation
import UIKit
import AVFoundation
import Vision

class SpatialGestureProvider: NSObject {

	let devicePosition: AVCaptureDevice.Position = .front	// .front / .back
	var baseView: UIView? = nil

	private var cameraView: CameraView!
	private let videoDataOutputQueue = DispatchQueue(label: "CameraFeedDataOutput", qos: .userInteractive)
	private var cameraFeedSession: AVCaptureSession?
	private let drawLayer = DrawLayer()
	private var handPoseRequest = VNDetectHumanHandPoseRequest()
	private var gestureProcessors = [SpatialGestureProcessor]()
	
	init(baseView: UIView? = nil) {
		super.init()

		handPoseRequest.maximumHandCount = 2	// both hands

		self.baseView = baseView
		self.cameraView = baseView as! CameraView
		if let view = baseView {
			drawLayer.frame = view.layer.bounds
			drawLayer.prepare()
			view.layer.addSublayer(drawLayer)
		}
		
		do {
			if cameraFeedSession == nil {
				cameraView.previewLayer.videoGravity = .resizeAspectFill
				try setupAVSession()
				cameraView.previewLayer.session = cameraFeedSession
			}
			cameraFeedSession?.startRunning()
		} catch {
			NSLog("camera session could not run")
		}

	}
	
	func terminate() {
		cameraFeedSession?.stopRunning()
	}
	
	func appendGesture(_ gesture: SpatialGestureProcessor) {
		gesture.cameraView = cameraView
		gesture.drawLayer = drawLayer
		gestureProcessors.append(gesture)
	}

	func layoutSubviews() {
		drawLayer.frame = (baseView?.layer.bounds)!
	}
	
	func clearDrawLayer() {
		drawLayer.clearPath()
	}

	func setupAVSession() throws {
		guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: devicePosition) else {
			throw AppError.captureSessionSetup(reason: "Could not find a front facing camera.")
		}
		guard let deviceInput = try? AVCaptureDeviceInput(device: videoDevice) else {
			throw AppError.captureSessionSetup(reason: "Could not create video device input.")
		}
		
		let session = AVCaptureSession()
		session.beginConfiguration()
		session.sessionPreset = AVCaptureSession.Preset.high
		
		guard session.canAddInput(deviceInput) else {
			throw AppError.captureSessionSetup(reason: "Could not add video device input to the session")
		}
		session.addInput(deviceInput)
		
		let dataOutput = AVCaptureVideoDataOutput()
		if session.canAddOutput(dataOutput) {
			session.addOutput(dataOutput)
			dataOutput.alwaysDiscardsLateVideoFrames = true
			dataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]	// Bi-Planar Component Y'CbCr 8-bit 4:2:0, full-range
			dataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
		} else {
			throw AppError.captureSessionSetup(reason: "Could not add video data output to the session")
		}
		session.commitConfiguration()
		cameraFeedSession = session
	}

}

// MARK: AVCaptureVideoDataOutputSampleBufferDelegate

extension SpatialGestureProvider: AVCaptureVideoDataOutputSampleBufferDelegate {
	public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
		
		var handPoseObservation: VNHumanHandPoseObservation?
		defer {
			DispatchQueue.main.sync {
				guard let observations = handPoseRequest.results else {
					return
				}
				for processor in gestureProcessors {
					processor.processHandPoseObservations(observations: observations)
				}
			}
		}
		
		let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .up, options: [:])
		do {
			try handler.perform([handPoseRequest])
			guard let observation = handPoseRequest.results?.first else { // observation: VNHumanHandPoseObservation
				handPoseObservation = nil
				return
			}
			handPoseObservation = observation
		} catch {
			cameraFeedSession?.stopRunning()
			let error = AppError.visionError(error: error)
			DispatchQueue.main.async {
				NSLog("image handling error")
			}
		}
	}
}
