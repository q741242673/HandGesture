/*
	カメラ画面上への描画レイヤー
*/

import Foundation
import UIKit
import AVFoundation

private let drawPath = UIBezierPath()		// 曲線
private var lastDrawPoint: CGPoint?
private var isFirstSegment = true

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

	// 曲線を作る
	func updatePath(with points: SpatialGestureProcessorBase.PointsPair, isLastPointsPair: Bool) {
		// 親指と人差し指の中間点の座標を計算
		let (thumbTip, indexTip) = points
		let drawPoint = CGPoint.midPoint(p1: thumbTip, p2: indexTip)	// 中間点
		
		// 曲線の最後の点か？
		if isLastPointsPair {
			if let lastPoint = lastDrawPoint {
				// 最後に描画した点まで線を引く
				drawPath.addLine(to: lastPoint)
			}
			// 曲線の描画は終了。最後に描画した点もリセット
			lastDrawPoint = nil
			// 曲線の描画途中
		} else {
			// 曲線の描きはじめ？
			if lastDrawPoint == nil {
				// 開始点まで移動する
				drawPath.move(to: drawPoint)
				isFirstSegment = true
				// すでに曲線を作成中
			} else {
				let lastPoint = lastDrawPoint!
				// 今の指座標と直前の点との中間を計算する
				let midPoint = CGPoint.midPoint(p1: lastPoint, p2: drawPoint)
				if isFirstSegment {
					// If it's the first segment of the stroke, draw a line to the midpoint.
					// 描画ストロークの最初のセグメントであれば、直線を引く
					drawPath.addLine(to: midPoint)
					isFirstSegment = false
				} else {
					// 描画ストロークの最初でなければ、最後の点をコントロールポイントとして中間点までカーブを描く
					drawPath.addQuadCurve(to: midPoint, controlPoint: lastPoint)
				}
			}
			// 次回のために最後に描画した点を記憶しておく
			lastDrawPoint = drawPoint
		}
		// 曲線を描画するレイヤーに渡す
		self.path = drawPath.cgPath
	}
	
	func clearPath() {
		drawPath.removeAllPoints()
		self.path = drawPath.cgPath
	}
	
}


// MARK: - CGPoint helpers

extension CGPoint {	// CGPointの機能拡張

//	// 2点の中間点を計算して返す
//	static func midPoint(p1: CGPoint, p2: CGPoint) -> CGPoint {
//		return CGPoint(x: (p1.x + p2.x) / 2, y: (p1.y + p2.y) / 2)
//	}
	
//	// 2点間の距離を計算する
//	func distance(from point: CGPoint) -> CGFloat {
//		return hypot(point.x - x, point.y - y)
//	}
}

