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
		gestureProvider?.appendGesture(Gesture_Cursor(delegate: self))
//		gestureProvider?.appendGesture(Gesture_Draw(delegate: self))
//		gestureProvider?.appendGesture(Gesture_Heart(delegate: self))
//		gestureProvider?.appendGesture(Gesture_Aloha(delegate: self))
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
		if gesture is Gesture_Draw {
			guard let point = atPoints.first else { return }
			gestureProvider?.cameraView.updatePath(with: point, isLastPoint: false)
		}
	}
	func gestureFired(gesture: SpatialGestureProcessor, atPoints:[CGPoint], triggerType: Int) {
		gestureProvider?.cameraView.showPoints(atPoints, color: #colorLiteral(red: 0.0, green: 1.0, blue: 0.0, alpha: 1.0))
		if gesture is Gesture_Draw {
			if triggerType == Gesture_Draw.TriggerType.canvasClear.rawValue {
				gestureProvider?.cameraView.clearPath()
			}
		}
		if gesture is Gesture_Cursor {
			var cursor: Gesture_Cursor.CursorType = Gesture_Cursor.CursorType(rawValue: triggerType)!
			switch cursor {
			case .up:
				print("UP")
			case .down:
				print("DOWN")
			case .right:
				print("RIGHT")
			case .left:
				print("LEFT")
			case .fire:
				print("FIRE")
			default:
				break
			}
			if triggerType == Gesture_Draw.TriggerType.canvasClear.rawValue {
				gestureProvider?.cameraView.clearPath()
			}
		}
	}
	func gestureEnded(gesture: SpatialGestureProcessor, atPoints:[CGPoint]) {
		gestureProvider?.cameraView.clearPoints()
		print("Gesture[\(String(describing: type(of: gesture)))] ended")
		if gesture is Gesture_Draw {
			guard let point = atPoints.first else { return }
			gestureProvider?.cameraView.updatePath(with: point, isLastPoint: true)
		}
	}
	func gestureCanceled(gesture: SpatialGestureProcessor, atPoints:[CGPoint]) {
		gestureProvider?.cameraView.clearPoints()
		if gesture is Gesture_Draw {
			guard let point = atPoints.first else { return }
			gestureProvider?.cameraView.updatePath(with: point, isLastPoint: true)
		}
	}
	
}
