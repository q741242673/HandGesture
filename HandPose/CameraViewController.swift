/*
	コントローラクラス
 　　（カメラビュー、空間ジェスチャー、描画レイヤー）
*/

import UIKit
import AVFoundation
import Vision

// カメラ画面
class CameraViewController: UIViewController {

	// 使用するカメラ
	private let devicePosition: AVCaptureDevice.Position = .front	// .front セルフィー / .back 裏面カメラ
	
	// カメラビュー
	private var cameraView: CameraView { view as! CameraView }
	private let videoDataOutputQueue = DispatchQueue(label: "CameraFeedDataOutput", qos: .userInteractive)
	private var cameraFeedSession: AVCaptureSession?	// ビデオ画像キャプチャのセッション

	// 描画レイヤー
	private let drawLayer = DrawLayer()
	
	// 空間ジェスチャー
	private var handPoseRequest = VNDetectHumanHandPoseRequest()		// 指の関節の位置情報を検出するためのクラス
	
	// 空間ジェスチャー
	private var spatialGestureProcessor = SpatialGestureProcessor()		// 空間ジェスチャーを判定するクラス

	// アプリ画面が表示される直前の処理
	override func viewDidLoad() {
		super.viewDidLoad()
		// 曲線を描くレイヤーを準備する
		drawLayer.frame = view.layer.bounds
		drawLayer.prepare()
		view.layer.addSublayer(drawLayer)
		
		// 手のポーズを検出するのは？
		handPoseRequest.maximumHandCount = 2	// 両手
//		handPoseRequest.maximumHandCount = 1	// 片手

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
				// 空間ジェスチャークラスにカメラを紐付ける
				spatialGestureProcessor.cameraView = cameraView
				spatialGestureProcessor.drawLayer = drawLayer
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
	
	// ビデオ入力を開始
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
	
	// 画面をダブルタップされた時の処理（いままで描いた曲線を消去する）
	@IBAction func handleGesture(_ gesture: UITapGestureRecognizer) {
		// ジェスチャーが完了するまでは何もしない
		guard gesture.state == .ended else {
			return
		}
		// DrawLayerをクリア
		drawLayer.clearPath()
	}
	
}

// MARK: AVCaptureVideoDataOutputSampleBufferDelegate

// カメラから入った映像が出力バッファに蓄積された時に呼ばれる処理
extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
	// カメラ映像がキャプチャされた
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
		
		var handPoseObservation: VNHumanHandPoseObservation?
		defer {
			DispatchQueue.main.sync {
				guard let observation = handPoseObservation else {
					return
				}
				spatialGestureProcessor.processHandPoseObservation(observation: observation)
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
}
