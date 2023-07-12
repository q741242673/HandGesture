/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The app's main view controller object.
*/

import UIKit
import AVFoundation
import Vision

// カメラ画面
class CameraViewController: UIViewController {

	private let useSpatialGesture = true
	private let devicePosition: AVCaptureDevice.Position = .front	// .front セルフィー / .back 裏面カメラ
	
	// カメラに写った画面を表示するビュー。この上に曲線を表示していく（詳細はCameraView.swiftを参照）
    private var cameraView: CameraView { view as! CameraView }
    
    private let videoDataOutputQueue = DispatchQueue(label: "CameraFeedDataOutput", qos: .userInteractive)
    private var cameraFeedSession: AVCaptureSession?	// ビデオ画像キャプチャのセッション

	private let drawOverlay = CAShapeLayer()
    private let drawPath = UIBezierPath()
    private var lastDrawPoint: CGPoint?

	private var isFirstSegment = true
    private var lastObservationTimestamp = Date()
	private var evidenceBuffer = [HandGestureProcessor.PointsPair]()	// 2本指が確定するまでの指の軌跡を一時的に記録する

	// 最初のサンプルのジェスチャー
	private var gestureProcessor = HandGestureProcessor()				// 2本指ジェスチャーを判定するクラス
	private var handPoseRequest = VNDetectHumanHandPoseRequest()		// 指の関節の位置情報を検出するためのクラス

	// 空間ジェスチャー
	private var spatialGestureProcessor = SpatialGestureProcessorBase()		// 空間ジェスチャーを判定するクラス

	// アプリ画面が表示される直前の処理
    override func viewDidLoad() {
        super.viewDidLoad()
		// 曲線を描くレイヤーを準備する
        drawOverlay.frame = view.layer.bounds
        drawOverlay.lineWidth = 5
        drawOverlay.backgroundColor = #colorLiteral(red: 0.9999018312, green: 1, blue: 0.9998798966, alpha: 0.5).cgColor
        drawOverlay.strokeColor = #colorLiteral(red: 0.6, green: 0.1, blue: 0.3, alpha: 1).cgColor
        drawOverlay.fillColor = #colorLiteral(red: 0.9999018312, green: 1, blue: 0.9998798966, alpha: 0).cgColor
        drawOverlay.lineCap = .round
        view.layer.addSublayer(drawOverlay)

		// 手のポーズを検出するのは片手だけ
		if(useSpatialGesture) {
			handPoseRequest.maximumHandCount = 2
		}
		else {
			handPoseRequest.maximumHandCount = 1
		}
		// ジェスチャーが検知された時に行う処理handleGestureStateChangeを登録する
        gestureProcessor.didChangeStateClosure = { [weak self] state in
            self?.handleGestureStateChange(state: state)
        }
		// 画面をダブルタップされた時の処理handleGestureを登録する
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleGesture(_:)))
        recognizer.numberOfTouchesRequired = 1
        recognizer.numberOfTapsRequired = 2
        view.addGestureRecognizer(recognizer)
    }

	// アプリ画面が表示された直後の処理
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        do {
			// カメラのセッションがまだ生成されていなければ
            if cameraFeedSession == nil {
				// ビデオ画像の表示方法を設定（画面にどうフィットさせるか）
                cameraView.previewLayer.videoGravity = .resizeAspectFill
				// カメラのセッションを生成
                try setupAVSession()
				// カメラを表示するビューにセッションを接続する
                cameraView.previewLayer.session = cameraFeedSession
            }
			// カメラのセッションを開始（カメラ画像が更新される）
            cameraFeedSession?.startRunning()
        } catch {
			// セッションが生成できない場合はエラー表示
            AppError.display(error, inViewController: self)
        }
    }
    
	// アプリ画面が閉じる直前の処理
    override func viewWillDisappear(_ animated: Bool) {
		// セッションを停止
        cameraFeedSession?.stopRunning()
        super.viewWillDisappear(animated)
    }
    
    func setupAVSession() throws {
		guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: devicePosition) else {
            throw AppError.captureSessionSetup(reason: "Could not find a front facing camera.")
        }
        // ビデオ入力を生成する
        guard let deviceInput = try? AVCaptureDeviceInput(device: videoDevice) else {
            throw AppError.captureSessionSetup(reason: "Could not create video device input.")
        }

		// セッションを生成
        let session = AVCaptureSession()
        session.beginConfiguration()
        session.sessionPreset = AVCaptureSession.Preset.high	// 高画質
        
		// セッションにビデオ入力を接続する
        guard session.canAddInput(deviceInput) else {
            throw AppError.captureSessionSetup(reason: "Could not add video device input to the session")
        }
        session.addInput(deviceInput)

		// ビデオ出力先を生成する
        let dataOutput = AVCaptureVideoDataOutput()
        if session.canAddOutput(dataOutput) {
            session.addOutput(dataOutput)
            // Add a video data output.
			dataOutput.alwaysDiscardsLateVideoFrames = true	// ビデオフレームに遅延があった場合に、フレームを削除する
            dataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]	// ビデオ形式 Bi-Planar Component Y'CbCr 8-bit 4:2:0, full-range
            dataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)	// ビデオ出力の移譲先を指定（ビデオ出力が変化した場合の処理関数）
        } else {
            throw AppError.captureSessionSetup(reason: "Could not add video data output to the session")
        }
		// 以上の設定をコミットする
        session.commitConfiguration()
        cameraFeedSession = session
}
    
	// 画面をダブルタップされた時の処理
    @IBAction func handleGesture(_ gesture: UITapGestureRecognizer) {
		// ジェスチャーが完了するまでは何もしない
        guard gesture.state == .ended else {
            return
        }
        evidenceBuffer.removeAll()			// evidenceBufferをクリア
        drawPath.removeAllPoints()			// 曲線描画用データをクリア
        drawOverlay.path = drawPath.cgPath	// クリアされた情報を曲線描画するレイヤーに渡す（曲線をクリアするために）
    }
	
	// MARK: Sample Gesture
	// 親指と人差し指の先端ポイントを処理する
	func processPoints(thumbTip: CGPoint?, indexTip: CGPoint?) {
		// Check that we have both points.
		// 親指と人差し指の両方のポインタが検出できていない場合は
		guard let thumbPoint = thumbTip, let indexPoint = indexTip else {
			// 親指と人差し指の両方が2秒以上検出できなかったら、いったんジェスチャー検出をリセットして再開
			if Date().timeIntervalSince(lastObservationTimestamp) > 2 {
				gestureProcessor.reset()
			}
			// 曲線をクリア
			cameraView.showPoints([], color: .clear)
			return
		}
		
		// カメラ座標系（AVFoundation coordinates）から画面座標系（UIKit coordinates）に変換
		let previewLayer = cameraView.previewLayer
		let thumbPointConverted = previewLayer.layerPointConverted(fromCaptureDevicePoint: thumbPoint)
		let indexPointConverted = previewLayer.layerPointConverted(fromCaptureDevicePoint: indexPoint)
		
		// 2点の位置関係を判断して、ジェスチャー状況を判断する
		gestureProcessor.processPointsPair((thumbPointConverted, indexPointConverted))
	}
	
	// ジェスチャーが検知された時に行う処理
	private func handleGestureStateChange(state: HandGestureProcessor.State) {
		let pointsPair = gestureProcessor.lastProcessedPointsPair	// 直前の親指と人差し指の位置
		var tipsColor: UIColor
		switch state {
		case .possiblePinch, .possibleApart:
			// まだ指がくっついたとも離れたとも判断できていない状態なので曲線を描画できない。
			// 今後、状況によっては描画することになるため、指の座標をevidenceBufferに保存しておく
			evidenceBuffer.append(pointsPair)
			// 指先を示す点の色はオレンジ
			tipsColor = .orange
		case .pinched:
			// 指がくっついたと確証が持てた場合の処理
			// evidenceBuffer内の指の座標を使って曲線を生成する
			for bufferedPoints in evidenceBuffer {
				updatePath(with: bufferedPoints, isLastPointsPair: false)
			}
			// evidenceBufferに保存してあった情報を消す
			evidenceBuffer.removeAll()
			// Finally, draw the current point.
			// 最新の指の座標も曲線に追加
			updatePath(with: pointsPair, isLastPointsPair: false)	// 曲線描画は継続
			// 指先を示す点の色はグリーン
			tipsColor = .green
		case .apart, .unknown:
			// 指が離れたと確証が持てた場合の処理
			// evidenceBuffer内の保存データを削除する
			evidenceBuffer.removeAll()
			// And draw the last segment of our draw path.
			//
			updatePath(with: pointsPair, isLastPointsPair: true)	// 曲線描画は完了
			// 指先を示す点の色は赤
			tipsColor = .red
		}
		// カメラ画面上に指先を示す点を表示する
		cameraView.showPoints([pointsPair.thumbTip, pointsPair.indexTip], color: tipsColor)
	}
	
	// 曲線を作る
	private func updatePath(with points: HandGestureProcessor.PointsPair, isLastPointsPair: Bool) {
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
		drawOverlay.path = drawPath.cgPath
	}

}

// MARK: AVCaptureVideoDataOutputSampleBufferDelegate

// カメラから入った映像が出力バッファに蓄積された時に呼ばれる処理
extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
	// カメラ映像がキャプチャされた
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
		
		if(useSpatialGesture) {
			var handPoseObservation: VNHumanHandPoseObservation?
			defer {
				DispatchQueue.main.sync {
					guard let observation = handPoseObservation else {
						return
					}
					spatialGestureProcessor.processHandPoseObservation(observation: handPoseObservation!, cameraView: cameraView)
				}
			}
			let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .up, options: [:])
			do {
				try handler.perform([handPoseRequest])
				guard let observation = handPoseRequest.results?.first else { // observation: VNHumanHandPoseObservation
					handPoseObservation = nil
					return
				}
				handPoseObservation = observation
			} catch {
				cameraFeedSession?.stopRunning()
				let error = AppError.visionError(error: error)
				DispatchQueue.main.async {
					error.displayInViewController(self)
				}
			}
		}
		else {
			var thumbTip: CGPoint?
			var indexTip: CGPoint?
			
			// この関数が終了した後に実行されるブロック
			defer {
				DispatchQueue.main.sync {
					// この関数内で取得した親指thumbTipと人差し指indexTipの座標を処理する
					self.processPoints(thumbTip: thumbTip, indexTip: indexTip)
				}
			}

			// sampleBufferのカメラ画像を使ってイメージ処理する
			let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .up, options: [:])
			do {
				// 手のポーズ検出をリクエスト（トライする）
				try handler.perform([handPoseRequest])
				// 手のポーズが検出されなかったらリターン
				// 手の検出数を1に設定しているので、それ以外の場合はエラーになっているはず
				guard let observation = handPoseRequest.results?.first else {
					return
				}
				// 親指と人差し指の全ての関節位置を取得する
				let thumbPoints = try observation.recognizedPoints(.thumb)
				let indexFingerPoints = try observation.recognizedPoints(.indexFinger)
				// それぞれの指先位置を取得する
				// 取得できなかったらリターン
				guard let thumbTipPoint = thumbPoints[.thumbTip], let indexTipPoint = indexFingerPoints[.indexTip] else {
					return
				}
				// Ignore low confidence points.
				// 画像判断の結果、確証が低い（指先だと確証が持てない）場合はリターン
				guard thumbTipPoint.confidence > 0.3 && indexTipPoint.confidence > 0.3 else {
					return
				}
				// 指先座標をVisionKit系（画像認識系）からAVFoundation系（ビデオ系）へ変換
				thumbTip = CGPoint(x: thumbTipPoint.location.x, y: 1 - thumbTipPoint.location.y)
				indexTip = CGPoint(x: indexTipPoint.location.x, y: 1 - indexTipPoint.location.y)
			// doブロックの処理中にエラーが発生した場合
			} catch {
				// カメラのセッションを停止（カメラ画像が更新されなくなる）
				cameraFeedSession?.stopRunning()
				// エラーを表示する
				let error = AppError.visionError(error: error)
				DispatchQueue.main.async {
					error.displayInViewController(self)
				}
			}
		}
    }
}


