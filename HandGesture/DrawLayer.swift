/*
	カメラ画面上への描画レイヤー
*/

import Foundation
import UIKit
import AVFoundation

private let drawPath = UIBezierPath()		// 曲線

// カメラ処理
class DrawLayer: CAShapeLayer {
	var cameraView: CameraView!

	func prepare() {
		lineWidth = 5
		backgroundColor = #colorLiteral(red: 0.9999018312, green: 1, blue: 0.9998798966, alpha: 0.5).cgColor
		strokeColor = #colorLiteral(red: 0.6, green: 0.1, blue: 0.3, alpha: 1).cgColor
		fillColor = #colorLiteral(red: 0.9999018312, green: 1, blue: 0.9998798966, alpha: 0).cgColor
		lineCap = .round
	}

	func clearPath() {
		drawPath.removeAllPoints()
		self.path = drawPath.cgPath
	}
	
}