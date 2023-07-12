/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The camera view shows the feed from the camera, and renders the points
     returned from VNDetectHumanHandpose observations.
*/

import UIKit
import AVFoundation

// カメラ処理
class CameraView: UIView {

    private var overlayLayer = CAShapeLayer()	// カメラ画面上に曲線を表示するレイヤー
    private var pointsPath = UIBezierPath()		// 曲線の接続点

	// ↓ ここからカメラ処理のお決まりのパターン
	
    var previewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }

    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupOverlay()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupOverlay()
    }
    
    override func layoutSublayers(of layer: CALayer) {
        super.layoutSublayers(of: layer)
        if layer == previewLayer {
            overlayLayer.frame = layer.bounds
        }
    }

    private func setupOverlay() {
        previewLayer.addSublayer(overlayLayer)
    }
	// ↑ ここまでカメラ処理のお決まりのパターン

	// 曲線を描く　引数：points=曲線の接続点、 color=表示色
    func showPoints(_ points: [CGPoint], color: UIColor) {
		// いったん全ての曲線を消す
        pointsPath.removeAllPoints()
		// 曲線の接続点を１つずつ取り出して処理を繰り返す
        for point in points {
			// 座標pointまでの曲線を追加
            pointsPath.move(to: point)
            pointsPath.addArc(withCenter: point, radius: 5, startAngle: 0, endAngle: 2 * .pi, clockwise: true)
        }
		// 曲線表示レイヤーに描きこむ色を設定
        overlayLayer.fillColor = color.cgColor
		// 描画トランザクション
		CATransaction.begin()					// 描画開始（描画終了まで、表向きは表示が変化しないようにする）
        CATransaction.setDisableActions(true)
        overlayLayer.path = pointsPath.cgPath	// 曲線表示レイヤーに曲線を入れ込む
        CATransaction.commit()					// 描画コミット（描きこんだ曲線を有効にする→表示される）
    }
}
