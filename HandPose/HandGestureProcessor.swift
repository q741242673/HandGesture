/*
See LICENSE folder for this sample’s licensing information.

Abstract:
This class is a state machine that transitions between states based on pair
    of points stream. These points are the tips for thumb and index finger.
    If the tips are closer than the desired distance, the state is "pinched", otherwise it's "apart".
    There are also "possiblePinch" and "possibeApart" states that are used to smooth out state transitions.
    During these possible states HandGestureProcessor collects the required amount of evidence before committing to a definite state.
*/

import CoreGraphics

// ハンドジェスチャーを判定するクラス
class HandGestureProcessor {
	// 判定状態のバリエーション（いまどんな状況かを表す）
    enum State {
        case possiblePinch
        case pinched
        case possibleApart
        case apart
        case unknown
    }
    
    typealias PointsPair = (thumbTip: CGPoint, indexTip: CGPoint)	// 2点をまとめて取り扱うための変数定義

	// 現在の判定状態を保持する変数
    private var state = State.unknown {
        didSet {
            didChangeStateClosure?(state)	// stateが変化したらdidChangeStateClosureを呼び出す
        }
    }
    private var pinchEvidenceCounter = 0	// 2点が近づいたカウンター
    private var apartEvidenceCounter = 0	// 2点が離れたカウンター
    private let pinchMaxDistance: CGFloat	// 2点が近づいていると判断する基準となる距離
    private let evidenceCounterStateTrigger: Int	// 2点が近づいてから、その状態がしばらく続いているかを判断するためのカウンター
    
    var didChangeStateClosure: ((State) -> Void)?	// stateが変化した時に呼び出す関数（上位のクラスCameraViewControllerから設定される関数）
    private (set) var lastProcessedPointsPair = PointsPair(.zero, .zero)	// 前回の2点
    
	// クラスの初期化。
	// 2点が近づいているかどうか判断する距離pinchMaxDistanceと、
	// どれだけ継続したら近づいたと判断するかのカウンターevidenceCounterStateTriggerを初期化する
    init(pinchMaxDistance: CGFloat = 40, evidenceCounterStateTrigger: Int = 3) {
        self.pinchMaxDistance = pinchMaxDistance
        self.evidenceCounterStateTrigger = evidenceCounterStateTrigger
    }
    
	// 判定状態のリセット
    func reset() {
        state = .unknown			// 状況不明
        pinchEvidenceCounter = 0	// 2点が近づいたカウンター = 0
        apartEvidenceCounter = 0	// 2点が離れたカウンター = 0
    }
    
	// 2点の位置関係を判断する
    func processPointsPair(_ pointsPair: PointsPair) {
		// 直前の2点をセーブしておく（CameraViewControllerクラスで使われている）
        lastProcessedPointsPair = pointsPair
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
    }
}

// MARK: - CGPoint helpers

extension CGPoint {	// CGPointの機能拡張

	// 2点の中間点を計算して返す
    static func midPoint(p1: CGPoint, p2: CGPoint) -> CGPoint {
        return CGPoint(x: (p1.x + p2.x) / 2, y: (p1.y + p2.y) / 2)
    }
    
	// 2点間の距離を計算する
    func distance(from point: CGPoint) -> CGFloat {
        return hypot(point.x - x, point.y - y)
    }
}

