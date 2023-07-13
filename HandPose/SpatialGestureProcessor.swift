/*
	空間ジェスチャーのベースクラス
*/

import CoreGraphics
import UIKit
import Vision

// ハンドジェスチャーを判定するクラス
class SpatialGestureProcessor {
// MARK: 列挙
	// 判定状態のバリエーション（いまどんな状況かを表す）
	enum State {
		case unknown
	}

// MARK: 変数（プロパティ）

	// 外部のクラスからアクセスされる変数/定義
	var cameraView: CameraView!										// カメラ画像を表示するビュー
	var drawLayer: DrawLayer?										// カメラ画面上の描画レイヤー
	var didChangeStateClosure: ((State) -> Void)?					// stateが変化した時に呼び出す関数（上位のクラスCameraViewControllerから設定される関数）

	// このクラス内でのみ使用するprivate変数
	private var fingerJoints = [[VNRecognizedPoint?]]()				// 指の関節位置の配列
	private var fingerJointsCnv = [[CGPoint?]]()					// 指の関節位置の配列
	private var wristJoint: VNRecognizedPoint?
	private var tipsColor: UIColor = .red							// 指先を示す点の色
	private var gestureEvidenceCounter = 0							// ジェスチャーが安定するまでのカウンター
	private let evidenceCounterStateTrigger: Int					// ジェスチャーの状態がしばらく続いているかを判断する閾値
	private var state = State.unknown {								// 現在の判定状態を保持する変数
		didSet {
			didChangeStateClosure?(state)	// stateが変化したらdidChangeStateClosureを呼び出す
		}
	}
	
	// MARK: 初期化
	init(evidenceCounterStateTrigger: Int = 3) {
		self.evidenceCounterStateTrigger = evidenceCounterStateTrigger
		// ジェスチャーが検知された時に行う処理handleGestureStateChangeを登録する
		self.didChangeStateClosure = { [weak self] state in
			self?.handleGestureStateChange(state)
		}
		
		reset()
	}
	
	// MARK: カメラに写った手を画像認識する
	func processHandPoseObservation(observation: VNHumanHandPoseObservation) {
		
		do {
			self.fingerJoints = try getFingerJoints(with: observation)		// 指関節の検出
			drawLayer?.path = drawFingers(fingerJoints: self.fingerJoints)	// 指関節を描画
			
			// ここで指関節の座標を使ってジェスチャーを判断する
			// 　・・・
			// 　・・・

		} catch {
			NSLog("Error")
		}
	}

	// 指の関節座標を画面座標系（UIKit coordinates）で取得する
	func getFingerJoints(with observation: VNHumanHandPoseObservation) throws -> [[VNRecognizedPoint?]] {
		do {
			let fingers = try observation.recognizedPoints(.all)
			// 指の関節座標をVisionKit系（画像認識系）で取得する（VNRecognizedPoint）
			fingerJoints = [
				[fingers[.thumbTip], fingers[.thumbIP],  fingers[.thumbMP],  fingers[.thumbCMC]],
				[fingers[.indexTip], fingers[.indexDIP], fingers[.indexPIP], fingers[.indexMCP]],
				[fingers[.middleTip],fingers[.middleDIP],fingers[.middlePIP],fingers[.middleMCP]],
				[fingers[.ringTip],  fingers[.ringDIP],  fingers[.ringPIP],  fingers[.ringMCP]],
				[fingers[.littleTip],fingers[.littleDIP],fingers[.littlePIP],fingers[.littleMCP]]
			]
			// 指の関節座標を画面座標系（UIKit coordinates）で取得する（CGPoint）
			fingerJointsCnv = [
				[cnv(fingers[.thumbTip]), cnv(fingers[.thumbIP]),  cnv(fingers[.thumbMP]),  cnv(fingers[.thumbCMC])],
				[cnv(fingers[.indexTip]), cnv(fingers[.indexDIP]), cnv(fingers[.indexPIP]), cnv(fingers[.indexMCP])],
				[cnv(fingers[.middleTip]),cnv(fingers[.middleDIP]),cnv(fingers[.middlePIP]),cnv(fingers[.middleMCP])],
				[cnv(fingers[.ringTip]),  cnv(fingers[.ringDIP]),  cnv(fingers[.ringPIP]),  cnv(fingers[.ringMCP])],
				[cnv(fingers[.littleTip]),cnv(fingers[.littleDIP]),cnv(fingers[.littlePIP]),cnv(fingers[.littleMCP])]
			]
			wristJoint = fingers[.wrist]
		} catch {
			NSLog("Error")
		}
		return fingerJoints
	}

	// 指を描画
	func drawFingers(fingerJoints: [[VNRecognizedPoint?]]) -> CGMutablePath {
		let path = CGMutablePath()
		for fingerjoint in fingerJoints {
			var i = 0
			for joint in fingerjoint {
				let point = cnv(joint)
				guard let point else { continue }
				if i>0 {
					path.addLine(to: point)			// Line
				}
				path.addPath(drawJoin(at: point))	// Dot
				path.move(to: point)
				i += 1
			}
			if let wJoint = cnv(wristJoint) {
				path.addLine(to: wJoint)			// Line
				path.addPath(drawJoin(at: wJoint))	// Dot
			}
		}
		
		if !path.isEmpty {
			path.closeSubpath()
		}
		
		return path
	}

	func drawJoin(at point: CGPoint) -> CGPath {
		return CGPath(roundedRect: NSRect(x: point.x - 10, y: point.y - 10, width: 20, height: 20), cornerWidth: 10, cornerHeight: 10, transform: nil)
	}

	// 座標変換：VisionKit系（画像認識系）→ AVFoundation系（ビデオ系）→ 画面座標系（UIKit coordinates）に変換
	func cnv(_ point: VNRecognizedPoint?) -> CGPoint? {
		// 検出精度が低い関節は無視する
		guard let point else { return nil }
		if point.confidence < 0.6 { return nil }
		
		let point2 = CGPoint(x: point.location.x, y: 1 - point.location.y)
		let previewLayer = cameraView.previewLayer
		let pointConverted = previewLayer.layerPointConverted(fromCaptureDevicePoint: point2)
//		NSLog("%f, %f", pointConverted.x, pointConverted.y)
		return pointConverted
	}

	// MARK: ジェスチャー判定が更新された時に行う処理
	private func handleGestureStateChange(_ state: State) {

		switch state {
		case .unknown:
			tipsColor = .red
			NSLog("不明")
			break
		default:
			tipsColor = .red
			NSLog("不明")
			break
		}
	}

	// MARK: 判定状態のリセット
	func reset() {
		state = .unknown			// 状況不明
	}

}
