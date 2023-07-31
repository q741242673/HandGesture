//
//  Gesture_Gun.swift
//  HandGesture
//
//  Created by Ryu Hashimoto on 2023/07/30.
//

import Foundation
import UIKit

class Gesture_Gun: SpatialGestureProcessor {
    
    override init() {
        super.init()
        stateReset()
    }

	convenience init(delegate: UIViewController) {
		self.init()
		self.delegate = delegate as? any SpatialGestureDelegate
	}

    // ジェスチャーを判定する流れ（ここに繰り返し入ってくる）
    override func checkGesture() {
        var pose:Int = 0
        struct Holder {
            static var lastPose:Int = -1
        }

        if(isFistPose()) { pose=1 }
        if(isStraightPose()) { pose=2 }
        if(isShot()) { pose=3 }

//        NSLog("POSE(%d, %d)", Holder.lastPose, pose)
        
        switch state {
        case .unknown:			// 初期状態では
            if(pose==1) {		// 最初のポーズ（握る）を待つ
                NSLog("in position")
				delegate?.gestureBegan(gesture: self, atPoints: [CGPointZero])
                state = State.waitForNextPose
            }
            break
        case .waitForNextPose:	// 最初のポーズが検出されたら
            if(pose==2) {	// ２つ目のポーズ（人差し指が伸びる）を待つ
				delegate?.gestureMoved(gesture: self, atPoints: gunPoint())
				if (Holder.lastPose != 2) {
					NSLog("aim")
					state = State.waitForNextPose
				}
            }
            if(pose==3) {    // ３つ目のポーズ（親指が曲がる）を待つ
				delegate?.gestureFired(gesture: self, atPoints: gunPoint())
				if(Holder.lastPose != 3) {
					NSLog("shoot")
					state = State.waitForNextPose
				}
            }
            if(pose==1) && (Holder.lastPose != 1) {
				delegate?.gestureEnded(gesture: self, atPoints: [CGPointZero])
                state = State.unknown
            }
            break
        case .detected:			// ２つ目のポーズが検出されたら
            state = .waitForRelease	// ポーズ解除待ちへ移行
            break
        case .waitForRelease:	// ポーズ解除待ちで
            break
        default:
            break
        }

        Holder.lastPose = pose
    }
   
    //拳から拳銃ポーズ↓
    func isFistPose() -> Bool {
        var gestureDetected = false
        if handJoints.count > 0 {
            let posRightI: CGPoint? = jointPosition(hand: WhichHand.right, finger: WhichFinger.index, joint: WhichJoint.tip)
            let posRightIm: CGPoint? = jointPosition(hand: WhichHand.right, finger: WhichFinger.index, joint: WhichJoint.mcp)
			let posWrist = jointPosition(hand: WhichHand.right, finger: WhichFinger.wrist, joint: WhichJoint.tip)
            guard let posRightI, let posRightIm, let posWrist  else { return false }

            if isBend(pos1: posWrist, pos2: posRightIm, pos3: posRightI){
                gestureDetected = true
            }
        }
        return gestureDetected
    }
    
    
    func isStraightPose() -> Bool {
        var gestureDetected = false
        if handJoints.count > 0 {
            let posRightI: CGPoint? = jointPosition(hand: WhichHand.right, finger: WhichFinger.index, joint: WhichJoint.tip)
            let posRightIm: CGPoint? = jointPosition(hand: WhichHand.right, finger: WhichFinger.index, joint: WhichJoint.mcp)
			let posWrist = jointPosition(hand: WhichHand.right, finger: WhichFinger.wrist, joint: WhichJoint.tip)
            guard let posRightI, let posRightIm, let posWrist  else { return false }
            
            if isStraight(pos1: posWrist, pos2: posRightIm, pos3: posRightI){
                gestureDetected = true
            }
        }
        return gestureDetected
    }
    
    func isShot() -> Bool {
        var gestureDetected = false
        if handJoints.count > 0 {
            let posRightT: CGPoint? = jointPosition(hand: WhichHand.right, finger: WhichFinger.thumb, joint: WhichJoint.tip)
            let posRightTm: CGPoint? = jointPosition(hand: WhichHand.right, finger: WhichFinger.thumb, joint: WhichJoint.dip)
			let posWrist = jointPosition(hand: WhichHand.right, finger: WhichFinger.wrist, joint: WhichJoint.tip)
            guard let posRightT, let posRightTm, let posWrist  else { return false }
            
            if isBend(pos1: posWrist, pos2: posRightTm, pos3: posRightT){
                gestureDetected = true
            }
        }
        return gestureDetected
    }
	
	func gunPoint() -> [CGPoint] {
		let posIndexTip: CGPoint? = jointPosition(hand: WhichHand.right, finger: WhichFinger.index, joint: WhichJoint.tip)
		let posIndexMcp: CGPoint? = jointPosition(hand: WhichHand.right, finger: WhichFinger.index, joint: WhichJoint.mcp)
		guard let posIndexTip, let posIndexMcp else { return [CGPointZero] }
		
		return [posIndexTip, posIndexMcp]
	}
}
