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
		case possible
		case detected
	}
	enum WhichHand: Int {
		case right = 0
		case left  = 1
	}
	enum WhichFinger: Int {
		case thumb  = 0
		case index
		case middle
		case ring
		case little
	}
	enum WhichJoint: Int {
		case tip = 0	// 指先
		case dip		// 第1関節
		case pip		// 第2関節
		case mcp		// 第3関節
	}

// MARK: 変数（プロパティ）

	// 外部のクラスからアクセスされる変数/定義
	var cameraView: CameraView!										// カメラ画像を表示するビュー
	var drawLayer: DrawLayer?										// カメラ画面上の描画レイヤー
	var didChangeStateClosure: ((State) -> Void)?					// stateが変化した時に呼び出す関数（上位のクラスCameraViewControllerから設定される関数）

	// このクラス内でのみ使用するprivate変数
	private var defaultHand = WhichHand.right						// 片手だけ検出された場合は右手と仮定する（世界的に右利きが多いので）
	private var handJoints: [[[VNRecognizedPoint?]]] = []			// 両手の指の関節位置の配列（0:右手、1:左手）
	private var fingerJoints: [[VNRecognizedPoint?]] = []			// 指の関節位置の配列
//	private var fingerJoints = [[VNRecognizedPoint?]]()				// 指の関節位置の配列
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
	
	// MARK: ジェスチャー判定ロジック
	func checkGesture() {
		if handJoints.count > 1 { // 両手のジェスチャー
			var posRightT: CGPoint? = jointPosition(hand: WhichHand.right, finger: WhichFinger.thumb, joint: WhichJoint.tip)
			var posRightI: CGPoint? = jointPosition(hand: WhichHand.right, finger: WhichFinger.index, joint: WhichJoint.tip)
			var posLeftT:  CGPoint? = jointPosition(hand: WhichHand.left, finger: WhichFinger.thumb, joint: WhichJoint.tip)
			var posLeftI:  CGPoint? = jointPosition(hand: WhichHand.left, finger: WhichFinger.index, joint: WhichJoint.tip)
			
			NSLog("Gesture checking.")
			guard let posRightI, let posRightT, let posLeftI, let posLeftT else {
				return
			}
			var closePos = 50.0
			var iDiff = fabs(posRightI.x - posLeftI.x)
			var tDiff = fabs(posRightT.x - posLeftT.x)
			if iDiff < closePos {
				if tDiff < closePos {
					NSLog("Gesture recognized diff=(%f, %f)", tDiff, iDiff)
				}
			}
		}
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

	// MARK: カメラに写った手を画像認識する

	func processHandPoseObservations(observations: [VNHumanHandPoseObservation]) {

		var fingerJoints1 = [[VNRecognizedPoint?]]()
		var fingerJoints2 = [[VNRecognizedPoint?]]()
		var fingerPath = CGMutablePath()
		
		do {
			// 片手ずつgetFingerJoints
			if observations.count>0 {
				fingerJoints1 = try getFingerJoints(with: observations[0])		// 指関節の検出
				fingerPath.addPath(drawFingers(fingerJoints: fingerJoints1))	// 指関節のパスを取得
			}
			if observations.count>1 {
				fingerJoints2 = try getFingerJoints(with: observations[1])		// 指関節の検出
				fingerPath.addPath(drawFingers(fingerJoints: fingerJoints2))	// 指関節のパスを取得
			}

			// 手が2つあったら、親指関節の位置関係で右手と左手を判断する
			switch observations.count {
			case 1:
				handJoints.removeAll()
				handJoints.insert(fingerJoints1, at: defaultHand.rawValue)
			case 2:
				let thumbPos1 = jointPosition(hand: fingerJoints1, finger: WhichFinger.thumb.rawValue, joint: WhichJoint.tip.rawValue)
				let thumbPos2 = jointPosition(hand: fingerJoints2, finger: WhichFinger.thumb.rawValue, joint: WhichJoint.tip.rawValue)
				guard let pos1=thumbPos1, let pos2=thumbPos2 else {
					return
				}
				handJoints.removeAll()
				if pos1.x < pos2.x {
					handJoints.append(fingerJoints2)	// WhichHand.right.rawValue
					handJoints.append(fingerJoints1)
				}
				else {
					handJoints.append(fingerJoints1)	// WhichHand.right.rawValue
					handJoints.append(fingerJoints2)
				}
			default:
				handJoints.removeAll()
			}
			
		} catch {
			NSLog("Error")
		}

		drawLayer?.path = fingerPath	// パスを描画

		// ここで指関節の座標を使ってジェスチャーを判断する
		checkGesture()
	}

	// 指の関節座標を取得する
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
			wristJoint = fingers[.wrist]	// 手首の位置
		} catch {
			NSLog("Error")
		}
		return fingerJoints
	}

	// 指の関節座標を画面座標系（UIKit coordinates）で取得する（CGPoint）
	func jointPosition(hand: [[VNRecognizedPoint?]], finger: Int, joint: Int) -> CGPoint? {
		return cnv(hand[finger][joint])
	}
	func jointPosition(hand: WhichHand, finger: WhichFinger, joint: WhichJoint) -> CGPoint? {
		switch handJoints.count {
		case 1:
			return cnv(handJoints[WhichHand.right.rawValue][finger.rawValue][joint.rawValue])
		case 2:
			return cnv(handJoints[hand.rawValue][finger.rawValue][joint.rawValue])
		default:
			return nil
		}
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

}
