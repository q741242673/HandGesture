/*
	空間ジェスチャーのベースクラス
*/

import CoreGraphics
import UIKit
import Vision

// ハンドジェスチャーを判定するクラス
class SpatialGestureProcessorBase {
// MARK: 列挙
	// 判定状態のバリエーション（いまどんな状況かを表す）
	enum State {
		case possiblePinch
		case pinched
		case possibleApart
		case apart
		case unknown
	}

// MARK: 変数（プロパティ）

	// 外部のクラスからアクセスされる変数/定義
	typealias PointsPair = (thumbTip: CGPoint, indexTip: CGPoint)	// 2点をまとめて取り扱うための定義
	var didChangeStateClosure: ((State) -> Void)?					// stateが変化した時に呼び出す関数（上位のクラスCameraViewControllerから設定される関数）

	// このクラス内でのみ使用するprivate変数
	private var tipsColor: UIColor = .red									// 指先を示す点の色
	private var gestureEvidenceCounter = 0									// ジェスチャーが安定するまでのカウンター
	private let evidenceCounterStateTrigger: Int							// ジェスチャーの状態がしばらく続いているかを判断する閾値
	private var evidenceBuffer = [PointsPair]()								// 2本指が確定するまでの指の軌跡を一時的に記録する
	private var pinchEvidenceCounter = 0									// 2点が近づいたカウンター
	private var apartEvidenceCounter = 0									// 2点が離れたカウンター
	private let pinchMaxDistance: CGFloat = 40								// 2点が近づいていると判断する基準となる距離
	private (set) var lastProcessedPointsPair = PointsPair(.zero, .zero)	// 前回の2点
	private var state = State.unknown {	// 現在の判定状態を保持する変数
		didSet {
			didChangeStateClosure?(state)	// stateが変化したらdidChangeStateClosureを呼び出す
		}
	}

	// カメラ画面へのアクセス
	var cameraView: CameraView!										// カメラ画像を表示するビュー
	var drawLayer: DrawLayer?										// カメラ画面上の描画レイヤー

// MARK: カメラ画面へのアクセス

	
// MARK: 関数（メソッド）
	// クラスの初期化。
	init(evidenceCounterStateTrigger: Int = 3) {
		self.evidenceCounterStateTrigger = evidenceCounterStateTrigger
		
		// ジェスチャーが検知された時に行う処理handleGestureStateChangeを登録する
		self.didChangeStateClosure = { [weak self] state in
			self?.handleGestureStateChange(state)
		}
		
		reset()
	}
	
	// 判定状態のリセット
	func reset() {
		state = .unknown			// 状況不明
		pinchEvidenceCounter = 0	// 2点が近づいたカウンター = 0
		apartEvidenceCounter = 0	// 2点が離れたカウンター = 0
	}

	// ジェスチャーが検知された時に行う処理
	private func handleGestureStateChange(_ state: State) {

		switch state {
		case .possiblePinch:
			tipsColor = .orange
			NSLog("指がくっつきそう")
			break
		case .pinched:
			tipsColor = .green
			NSLog("指がくっついた")
			break
		case .possibleApart:
			tipsColor = .orange
			NSLog("指が離れそう")
			break
		case .apart:
			tipsColor = .red
			NSLog("指が離れた")
			break
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

	// カメラに写った手を画像処理する関数
	func processHandPoseObservation(observation: VNHumanHandPoseObservation) {
		
		var thumbTip: CGPoint?
		var indexTip: CGPoint?

		do {
			// 親指と人差し指の全ての関節位置を取得する
			let thumbPoints = try observation.recognizedPoints(.thumb)
			let indexFingerPoints = try observation.recognizedPoints(.indexFinger)
			// それぞれの指先位置を取得する
			guard let thumbTipPoint = thumbPoints[.thumbTip], let indexTipPoint = indexFingerPoints[.indexTip] else {
				// 取得できなかったらリターン
				return
			}
			// 画像判断の結果、確証が低い（指先だと確証が持てない）場合はリターン
			guard thumbTipPoint.confidence > 0.3 && indexTipPoint.confidence > 0.3 else {
				return
			}
			// 指先座標をVisionKit系（画像認識系）からAVFoundation系（ビデオ系）へ変換
			thumbTip = CGPoint(x: thumbTipPoint.location.x, y: 1 - thumbTipPoint.location.y)
			indexTip = CGPoint(x: indexTipPoint.location.x, y: 1 - indexTipPoint.location.y)
			
			// AVFoundation系（ビデオ系）から画面座標系（UIKit coordinates）に変換
			let previewLayer = cameraView.previewLayer
			let thumbPointConverted = previewLayer.layerPointConverted(fromCaptureDevicePoint: thumbTip!)
			let indexPointConverted = previewLayer.layerPointConverted(fromCaptureDevicePoint: indexTip!)
			var pointsPair: PointsPair = (thumbPointConverted, indexPointConverted)

//			NSLog("%f, %f", thumbPointConverted.x, thumbPointConverted.y)
			
			// 直前の2点をセーブしておく（CameraViewControllerクラスで使われている）
			lastProcessedPointsPair = pointsPair
			
			// 指先を画面にドット表示
			self.cameraView?.showPoints([pointsPair.thumbTip, pointsPair.indexTip], color: tipsColor)

			// 今回の2点（pointsPair）の距離を計算
			let distance = pointsPair.indexTip.distance(from: pointsPair.thumbTip)
			
			// 判断基準となる2点間距離より近づいていたら
			if distance < pinchMaxDistance {
				// その状態がしばらく続くのを観察する（その状態が何回続いたかをカウント）
				pinchEvidenceCounter += 1	// 近づいた状態をカウントアップ
				apartEvidenceCounter = 0	// 遠ざかった状態はカウントしない
				// 数回続いたら pinched、続きそうなら possiblePinch をstateに入れる
				state = (pinchEvidenceCounter >= evidenceCounterStateTrigger) ? .pinched : .possiblePinch
				// 判断基準となる2点間距離より離れていたら
			} else {
				// その状態がしばらく続くのを観察する（その状態が何回続いたかをカウント）
				apartEvidenceCounter += 1	// 離れた状態をカウントアップ
				pinchEvidenceCounter = 0	// 近づいた状態はカウントしない
				// 数回続いたら apart、続きそうなら possibleApart をstateに入れる
				state = (apartEvidenceCounter >= evidenceCounterStateTrigger) ? .apart : .possibleApart
			}
			
			// 状況によって曲線バッファを更新する
			switch state {
			case .possiblePinch, .possibleApart:
				evidenceBuffer.append(pointsPair)
			case .pinched:
				for bufferedPoints in evidenceBuffer {
					drawLayer?.updatePath(with: bufferedPoints, isLastPointsPair: false)
				}
				evidenceBuffer.removeAll()
				drawLayer?.updatePath(with: pointsPair, isLastPointsPair: false)
			case .apart, .unknown:
				evidenceBuffer.removeAll()
				drawLayer?.updatePath(with: pointsPair, isLastPointsPair: true)
			}
		} catch {
			NSLog("エラー発生")
		}
	}
	
}
