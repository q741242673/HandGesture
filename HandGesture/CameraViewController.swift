//
//  CameraViewController.swift
//  HandGesture
//
//  Created by Yos Hashimoto on 2023/07/30.
//


import UIKit
import AVFoundation
import Vision

class CameraViewController: UIViewController {

	private var gestureProvider: SpatialGestureProvider?
		
	override func viewDidLoad() {
		super.viewDidLoad()
	}
	
	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)

		gestureProvider = SpatialGestureProvider(baseView: self.view)
		gestureProvider?.appendGesture(Gesture_Heart())
	}
	
	override func viewDidLayoutSubviews() {
		gestureProvider?.layoutSubviews()
	}
	
	override func viewWillDisappear(_ animated: Bool) {
		gestureProvider?.terminate()
		super.viewWillDisappear(animated)
	}
		
	@IBAction func handleGesture(_ gesture: UITapGestureRecognizer) {
		guard gesture.state == .ended else {
			return
		}
		gestureProvider?.clearDrawLayer()
	}
	
}
