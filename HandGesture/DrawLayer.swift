//
//  DrawLayer.swift
//  HandGesture
//
//  Created by Ryu Hashimoto on 2023/07/30.
//

import Foundation
import UIKit
import AVFoundation

private let drawPath = UIBezierPath()

class DrawLayer: CAShapeLayer {
	var cameraView: CameraView!

	func prepare() {
		lineWidth = 5
		backgroundColor = #colorLiteral(red: 0.9999018312, green: 1, blue: 0.9998798966, alpha: 0.5).cgColor
		strokeColor = #colorLiteral(red: 0.9098039269, green: 0.4784313738, blue: 0.6431372762, alpha: 1).cgColor
		fillColor = #colorLiteral(red: 0.9999018312, green: 1, blue: 0.9998798966, alpha: 0).cgColor
		lineCap = .round
	}

	func clearPath() {
		drawPath.removeAllPoints()
		self.path = drawPath.cgPath
	}
	
}
