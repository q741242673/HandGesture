//
//  Gesture_Heart.swift
//  HandGesture
//
//  Created by Yos Hashimoto on 2023/07/30.
//

import Foundation

class Gesture_Heart: SpatialGestureProcessor {
    
    override init() {
        super.init()
        stateReset()
    }
    
    // ジェスチャーを判定する流れ（ここに繰り返し入ってくる）
    override func checkGesture() {
        switch state {
        case .unknown:			// 初期状態では
            if(isFirstPose()) {		// 最初のポーズ（親指どうしが接触、人差し指どうしが接触）を待つ
                NSLog("最初のポーズ")
                state = State.waitForNextPose
                saveHandJoints()
            }
            break
        case .waitForNextPose:	// 最初のポーズが検出されたら
            if(isSecondPose()) {	// ２つ目のポーズ（人差し指が曲がってハートになる）を待つ
                NSLog("２つ目のポーズ")
                state = State.detected
            }
            break
        case .detected:			// ２つ目のポーズが検出されたら
            state = .waitForRelease	// ポーズ解除待ちへ移行
            break
        case .waitForRelease:	// ポーズ解除待ちで
            if(isPoseReleased()) {	// ポーズが解除される（指が離れる）のを待つ
                NSLog("ポーズ解除")
                state = State.unknown
            }
            break
        default:
            break
        }
    }
    
    func isFirstPose() -> Bool {
        var gestureDetected = false
        if handJoints.count > 1 { // 両手のジェスチャー
            let posRightT: CGPoint? = jointPosition(hand: WhichHand.right, finger: WhichFinger.thumb, joint: WhichJoint.tip)
            let posRightI: CGPoint? = jointPosition(hand: WhichHand.right, finger: WhichFinger.index, joint: WhichJoint.tip)
            let posLeftT:  CGPoint? = jointPosition(hand: WhichHand.left, finger: WhichFinger.thumb, joint: WhichJoint.tip)
            let posLeftI:  CGPoint? = jointPosition(hand: WhichHand.left, finger: WhichFinger.index, joint: WhichJoint.tip)
            guard let posRightI, let posRightT, let posLeftI, let posLeftT else { return false }
            
            let distance = 50.0
            if isNear(pos1: posRightT, pos2: posLeftT, value: distance) && isNear(pos1: posRightI, pos2: posLeftI, value: distance) {
                gestureDetected = true
            }
        }
        return gestureDetected
    }
    func isSecondPose() -> Bool {
        var gestureDetected = false
        if handJoints.count > 1 { // 両手のジェスチャー
            let posRightIt: CGPoint? = jointPosition(hand: WhichHand.right, finger: WhichFinger.index, joint: WhichJoint.tip)
            let posLeftIt:  CGPoint? = jointPosition(hand: WhichHand.left, finger: WhichFinger.index, joint: WhichJoint.tip)
            let posRightIp: CGPoint? = jointPosition(hand: WhichHand.right, finger: WhichFinger.index, joint: WhichJoint.pip)
            let posLeftIp:  CGPoint? = jointPosition(hand: WhichHand.left, finger: WhichFinger.index, joint: WhichJoint.pip)
            guard let posRightIt, let posLeftIt, let posRightIp, let posLeftIp else { return false }
            
            let distance = 50.0
            if isPoint(posRightIp, isUpperThan: posRightIt, value: distance) && isPoint(posLeftIp, isUpperThan: posLeftIt, value: distance) {
                gestureDetected = true
            }
        }
        return gestureDetected
    }
    func isPoseReleased() -> Bool {
        var gestureDetected = false
        if handJoints.count > 1 { // 両手のジェスチャー
            let posRightT: CGPoint? = jointPosition(hand: WhichHand.right, finger: WhichFinger.thumb, joint: WhichJoint.tip)
            let posRightI: CGPoint? = jointPosition(hand: WhichHand.right, finger: WhichFinger.index, joint: WhichJoint.tip)
            let posLeftT:  CGPoint? = jointPosition(hand: WhichHand.left, finger: WhichFinger.thumb, joint: WhichJoint.tip)
            let posLeftI:  CGPoint? = jointPosition(hand: WhichHand.left, finger: WhichFinger.index, joint: WhichJoint.tip)
            guard let posRightI, let posRightT, let posLeftI, let posLeftT else { return false }
            
            let distance = 200.0
            if isFar(pos1: posRightT, pos2: posLeftT, value: distance) && isFar(pos1: posRightI, pos2: posLeftI, value: distance) {
                gestureDetected = true
            }
        }
        return gestureDetected
    }
    
    
    
    
    func isGunPose() -> Bool {
        var gestureDetected = false
        if handJoints.count > 1 { // 両手のジェスチャー
            let posRightT: CGPoint? = jointPosition(hand: WhichHand.right, finger: WhichFinger.thumb, joint: WhichJoint.tip)
            let posRightI: CGPoint? = jointPosition(hand: WhichHand.right, finger: WhichFinger.index, joint: WhichJoint.tip)
            let posRightM: CGPoint? = jointPosition(hand: WhichHand.right, finger: WhichFinger.middle, joint: WhichJoint.tip)
            let posRightR: CGPoint? = jointPosition(hand: WhichHand.right, finger: WhichFinger.ring, joint: WhichJoint.tip)
            let posRightL: CGPoint? = jointPosition(hand: WhichHand.right, finger: WhichFinger.little, joint: WhichJoint.tip)
            //let posLeftT:  CGPoint? = jointPosition(hand: WhichHand.left, finger: WhichFinger.thumb, joint: WhichJoint.tip)
            //let posLeftI:  CGPoint? = jointPosition(hand: WhichHand.left, finger: WhichFinger.index, joint: WhichJoint.tip)
            let posWrist = wristJoint
            guard let posRightT, let posRightL, let posRightI, let posWrist  else { return false }
            
            let distance = 50.0
            if isNear(pos1: posRightM, pos2: posRightR,  value: distance) {
                gestureDetected = true
            }
        }
        return gestureDetected
    }
}
