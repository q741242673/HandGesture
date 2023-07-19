/*
	曲げ伸ばし型ジェスチャー
*/

import Foundation

class Gesture_Gun: SpatialGestureProcessor {
    
    override init() {
        super.init()
        stateReset()
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
                NSLog("構える")
                state = State.waitForNextPose
//                saveHandJoints()
            }
            break
        case .waitForNextPose:	// 最初のポーズが検出されたら
            if(pose==2) && (Holder.lastPose != 2) {	// ２つ目のポーズ（人差し指が伸びる）を待つ
                NSLog("狙う")
                state = State.waitForNextPose
            }
            if(pose==3) && (Holder.lastPose != 3) {    // ３つ目のポーズ（親指が曲がる）を待つ
                NSLog("撃つ")
                state = State.waitForNextPose
            }
            if(pose==1) && (Holder.lastPose != 1) {
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
            let posWrist = wristJoint
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
            let posWrist = wristJoint
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
            let posWrist = wristJoint
            guard let posRightT, let posRightTm, let posWrist  else { return false }
            
            if isBend(pos1: posWrist, pos2: posRightTm, pos3: posRightT){
                gestureDetected = true
            }
        }
        return gestureDetected
    }
}
