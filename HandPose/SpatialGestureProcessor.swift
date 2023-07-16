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
		case waitForNextPose
		case possible
		case detected
		case waitForRelease
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

	// 継承クラスから使用する変数
	var state = State.unknown {								// 現在の判定状態を保持する変数
		didSet {
			didChangeStateClosure?(state)	// stateが変化したらdidChangeStateClosureを呼び出す
		}
	}
	var defaultHand = WhichHand.right						// 片手だけ検出された場合は右手と仮定する（世界的に右利きが多いので）
	var handJoints: [[[VNRecognizedPoint?]]] = []			// 両手の指の関節位置の配列（0:右手、1:左手）
	var lastHandJoints: [[[VNRecognizedPoint?]]] = []		// 両手の指の関節位置の配列（0:右手、1:左手）... 動作のあるジェスチャーを検知するために最初のポーズを記憶

	// このクラス内でのみ使用するprivate変数
	private var fingerJoints: [[VNRecognizedPoint?]] = []			// 指の関節位置の配列
	private var fingerJointsCnv = [[CGPoint?]]()					// 指の関節位置の配列
	private var wristJoint: VNRecognizedPoint?
	private var tipsColor: UIColor = .red							// 指先を示す点の色
	private var gestureEvidenceCounter = 0							// ジェスチャーが安定するまでのカウンター
	
	// MARK: 初期化
	init() {
		// ジェスチャーが検知された時に行う処理handleGestureStateChangeを登録する
		self.didChangeStateClosure = { [weak self] state in
			self?.handleGestureStateChange(state)
		}
		
		stateReset()
	}

	// MARK: ジェスチャー判定が更新された時に行う処理
	private func handleGestureStateChange(_ state: State) {
	}

	// MARK: ジェスチャー判定ロジック
	func checkGesture() {
	}

	// MARK: 判定状態のリセット
	func stateReset() {
		clearHandJoints()
		state = .unknown			// 状況不明
	}

	// MARK: ジェスチャー判定用の演算
	// 関節位置が近いか判断
	func isNear(pos1: CGPoint?, pos2: CGPoint?, value: Double) -> Bool {
		guard let p1 = pos1, let p2 = pos2 else { return false }
		if p1.distance(from: p2) < value { return true }
		return false
	}
	// 関節位置が遠いか判断
	func isFar(pos1: CGPoint?, pos2: CGPoint?, value: Double) -> Bool {
		guard let p1 = pos1, let p2 = pos2 else { return false }
		if p1.distance(from: p2) > value { return true }
		return false
	}
	// 関節位置が画面内で上か
	func isPoint(_ pos: CGPoint?, isUpperThan: CGPoint?, value: Double) -> Bool {
		guard let p1 = pos, let p2 = isUpperThan else { return false }
		if (p1 - p2).y < value { return true }
		return false
	}
	// 関節位置が画面内で下か
    func isPoint(_ pos: CGPoint?, isLowerThan: CGPoint?, value: Double) -> Bool {
	    guard let p1 = pos, let p2 = isLowerThan else { return false }
	    if (p1 - p2).y > value { return true }
	    return false
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
					handJoints.append(fingerJoints2)	// WhichHand.right
					handJoints.append(fingerJoints1)
				}
				else {
					handJoints.append(fingerJoints1)	// WhichHand.right
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

	// 動きのあるジェスチャーの場合、最初の関節位置を記録する
	func saveHandJoints() {
		lastHandJoints.removeAll()
		lastHandJoints.append(handJoints[0])
		lastHandJoints.append(handJoints[1])
	}
	
	// 記録しておいた関節位置をクリアする
	func clearHandJoints() {
		lastHandJoints.removeAll()
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
			return jointPosition(hand:handJoints[WhichHand.right.rawValue], finger:finger.rawValue, joint:joint.rawValue)
		case 2:
			return jointPosition(hand:handJoints[hand.rawValue], finger:finger.rawValue, joint:joint.rawValue)
		default:
			return nil
		}
	}
	func lastJointPosition(hand: WhichHand, finger: WhichFinger, joint: WhichJoint) -> CGPoint? {
		switch lastHandJoints.count {
		case 1:
			return jointPosition(hand:lastHandJoints[WhichHand.right.rawValue], finger:finger.rawValue, joint:joint.rawValue)
		case 2:
			return jointPosition(hand:lastHandJoints[hand.rawValue], finger:finger.rawValue, joint:joint.rawValue)
		default:
			return nil
		}
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
				path.addPath(drawJoint(at: point))	// Dot
				path.move(to: point)
				i += 1
			}
			if let wJoint = cnv(wristJoint) {
				path.addLine(to: wJoint)			// Line
				path.addPath(drawJoint(at: wJoint))	// Dot
			}
		}
		
		if !path.isEmpty {
			path.closeSubpath()
		}
		
		return path
	}

	func drawJoint(at point: CGPoint) -> CGPath {
		return CGPath(roundedRect: NSRect(x: point.x - 5, y: point.y - 5, width: 10, height: 10), cornerWidth: 5, cornerHeight: 5, transform: nil)
	}

}
