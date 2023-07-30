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
    
    // Gesture judging loop
    override func checkGesture() {
        switch state {
        case .unknown:			// initial state
            if(isFirstPose()) {		// wait for first pose (both thumb touched, both index finger touched)
                NSLog("detect first pose")
                state = State.waitForNextPose
                saveHandJoints()
            }
            break
        case .waitForNextPose:	// wait for next pose
            if(isSecondPose()) {	// wait for second pose (bend both index finger. make figure of "heart")
                NSLog("detect second pose")
                state = State.detected
            }
            break
        case .detected:			// second pose detected
            state = .waitForRelease
            break
        case .waitForRelease:	// wait for pose release
            if(isPoseReleased()) {	// wait until pose released (fingers depart)
                NSLog("pose released")
                state = State.unknown
            }
            break
        default:
            break
        }
    }
    
    func isFirstPose() -> Bool {
        var gestureDetected = false
        if handJoints.count > 1 { // gesture of both hands
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
        if handJoints.count > 1 { // gesture of both hands
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
        if handJoints.count > 1 { // gesture of both hands
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
    
}
