/*
	カメラ処理
*/

import UIKit
import AVFoundation

class CameraView: UIView {

    private var overlayLayer = DrawLayer()	// カメラ画面上に描画するレイヤー
	private var pointsPath = UIBezierPath()		// 点

	// MARK: カメラレイヤーの初期化
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
		overlayLayer.cameraView = self
    }
	// ↑ ここまでカメラ処理のお決まりのパターン

	// MARK: 点を描く（描画とは別のレイヤー）
	// 点を描く　引数：points=描画する点の配列、 color=表示色
    func showPoints(_ points: [CGPoint], color: UIColor) {
		// いったん全ての点を消す
        pointsPath.removeAllPoints()
		// 点を１つずつ取り出して処理を繰り返す
        for point in points {
			// 座標pointまでの移動
            pointsPath.move(to: point)
			// その場所に点を追加する
            pointsPath.addArc(withCenter: point, radius: 5, startAngle: 0, endAngle: 2 * .pi, clockwise: true)
        }
		// 表示レイヤーに描きこむ色を設定
        overlayLayer.fillColor = color.cgColor
		// 描画トランザクション
		CATransaction.begin()					// 描画開始（描画終了まで、表向きは表示が変化しないようにする）
        CATransaction.setDisableActions(true)
        overlayLayer.path = pointsPath.cgPath	// 曲線表示レイヤーに点（複数）を入れ込む
        CATransaction.commit()					// 描画コミット（点の描画データを反映する → 表示される）
    }
}
