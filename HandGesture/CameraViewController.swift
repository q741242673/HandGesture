//
//  CameraViewController.swift
//  HandGesture
//
//  Created by Yos Hashimoto on 2023/07/30.
//

import UIKit
import AVFoundation
import Vision

// MARK: CameraViewController

class CameraViewController: UIViewController {

	private var gestureProvider: SpatialGestureProvider?
		
	override func viewDidLoad() {
		super.viewDidLoad()
	}
	
	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)

		gestureProvider = SpatialGestureProvider(baseView: self.view)
		gestureProvider?.appendGesture(Gesture_Heart(delegate: self))
		gestureProvider?.appendGesture(Gesture_Aloha(delegate: self))
//		gestureProvider?.appendGesture(Gesture_Gun(delegate: self))
	}
	
	override func viewDidLayoutSubviews() {
		gestureProvider?.layoutSubviews()
	}
	
	override func viewWillDisappear(_ animated: Bool) {
		gestureProvider?.terminate()
		super.viewWillDisappear(animated)
	}
		
}

// MARK: SpecialGestureDelegate

extension CameraViewController: SpatialGestureDelegate {
	func gestureBegan(gesture: SpatialGestureProcessor, atPoints:[CGPoint]) {
		print("Gesture[\(String(describing: type(of: gesture)))] began")
	}
	func gestureMoved(gesture: SpatialGestureProcessor, atPoints:[CGPoint]) {
		gestureProvider?.cameraView.showPoints(atPoints, color: #colorLiteral(red: 0.0, green: 1.0, blue: 0.0, alpha: 1.0))
	}
	func gestureFired(gesture: SpatialGestureProcessor, atPoints:[CGPoint]) {
		gestureProvider?.cameraView.showPoints(atPoints, color: #colorLiteral(red: 0.0, green: 1.0, blue: 0.0, alpha: 1.0))
	}
	func gestureEnded(gesture: SpatialGestureProcessor, atPoints:[CGPoint]) {
		gestureProvider?.cameraView.clearPoints()
		print("Gesture[\(String(describing: type(of: gesture)))] ended")
	}
	func gestureCanceled(gesture: SpatialGestureProcessor, atPoints:[CGPoint]) {
		gestureProvider?.cameraView.clearPoints()
		print("Gesture[\(String(describing: type(of: gesture)))] canceled")
	}
}
