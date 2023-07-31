//
//  Gesture_Heart.swift
//  HandGesture
//
//  Created by Yos Hashimoto on 2023/07/30.
//

import Foundation
import UIKit

class Gesture_Heart: SpatialGestureProcessor {
    
	let distance = 75.0
	
    override init() {
        super.init()
        stateReset()
    }

	convenience init(delegate: UIViewController) {
		self.init()
		self.delegate = delegate as? any SpatialGestureDelegate
	}

    // Gesture judging loop
    override func checkGesture() {
        switch state {
        case .unknown:			// initial state
            if(isThumbAndIndexTouched()) {		// wait for first pose (both thumb touched, both index finger touched)
				delegate?.gestureBegan(gesture: self, atPoints: [CGPointZero])
                state = State.waitForNextPose
                saveHandJoints()
            }
            break
        case .waitForNextPose:	// wait for next pose
            if(isHeartFigure()) {	// wait for second pose (bend both index finger. make figure of "heart")
                state = State.waitForRelease
            }
			if(!isThumbAndIndexTouched()) {	// pose released (fingers depart)
				delegate?.gestureEnded(gesture: self, atPoints: [CGPointZero])
				state = State.unknown
			}
            break
        case .waitForRelease:	// wait for pose release
			delegate?.gestureMoved(gesture: self, atPoints: [centerOfHeart()])
            if(!isThumbAndIndexTouched()) {	// wait until pose released (fingers depart)
				delegate?.gestureEnded(gesture: self, atPoints: [CGPointZero])
                state = State.unknown
            }
            break
        default:
            break
        }
    }
    
    func isThumbAndIndexTouched() -> Bool {
		
		if handJoints.count > 1 { // gesture of both hands
			if isNear(pos1: jointPosition(hand: .right, finger: .thumb, joint: .tip), pos2: jointPosition(hand: .left, finger: .thumb, joint: .tip), value: distance) && isNear(pos1: jointPosition(hand: .right, finger: .index, joint: .tip), pos2: jointPosition(hand: .left, finger: .index, joint: .tip), value: distance) {
				return true
			}
		}
		return false
    }
    func isHeartFigure() -> Bool {
		if isThumbAndIndexTouched()==false { return false }

		if handJoints.count > 1 { // gesture of both hands
			if isPoint(jointPosition(hand: .right, finger: .index, joint: .pip), upperThan: jointPosition(hand: .right, finger: .index, joint: .tip), value: distance) && isPoint(jointPosition(hand: .left, finger: .index, joint: .pip), upperThan: jointPosition(hand: .left, finger: .index, joint: .tip), value: distance) {
				return true
			}
		}
		return false
    }
    
	func centerOfHeart() -> CGPoint {
		let posRightI: CGPoint? = jointPosition(hand: .right, finger: .index, joint: .tip)
		let posLeftT:  CGPoint? = jointPosition(hand: .left, finger: .thumb, joint: .tip)
		guard let posRightI, let posLeftT else { return CGPointZero }

		return CGPoint.midPoint(p1: posRightI, p2: posLeftT)
	}
}
