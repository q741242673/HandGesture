//
//  Gesture_Draw.swift
//  HandGesture
//
//  Created by Yos Hashimoto on 2023/07/30.
//

import Foundation
import UIKit

class Gesture_Draw: SpatialGestureProcessor {
    
	// MARK: enum
	enum TriggerType: Int {
		case canvasClear
	}

	let checkDistance = 100.0

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
            if(isPencilPose()) {		// wait for first pose (thumb and little finger outstretched, other fingers bending)
				delegate?.gestureBegan(gesture: self, atPoints: [CGPointZero])
                state = State.waitForRelease
            }
			if(isClearCanvasPose()) {	// wait for canvas clear pose (open hand)
				delegate?.gestureFired(gesture: self, atPoints: [CGPointZero], triggerType:0)
				state = State.unknown
			}
            break
        case .waitForRelease:	// wait for pose release
			delegate?.gestureMoved(gesture: self, atPoints: IndexTip())
            if(!isPencilPose()) {	// wait until pose released
				delegate?.gestureEnded(gesture: self, atPoints: [CGPointZero])
                state = State.unknown
            }
            break
        default:
            break
        }
    }
    
    func isPencilPose() -> Bool {	// make pencil gesture ==> touch thumb tip to the second joint of index finger
		if handJoints.count > 0 { // gesture of single hands
			if isStraight(hand: .right, finger: .index) {
				if isNear(pos1: jointPosition(hand: .right, finger: .thumb, joint: .tip), pos2: jointPosition(hand: .right, finger: .index, joint: .pip), value: checkDistance) {
					return true
				}
			}
		}
        return false
    }

	func isClearCanvasPose() -> Bool {	// open hand
		if handJoints.count > 0 { // gesture of single hands
			var check = 0
			if isStraight(hand: .right, finger: .thumb){ check += 1 }
			if isStraight(hand: .right, finger: .index){ check += 1 }
			if isStraight(hand: .right, finger: .middle){ check += 1 }
			if isStraight(hand: .right, finger: .ring){ check += 1 }
			if isStraight(hand: .right, finger: .little){ check += 1 }
			if check == 5 { return true }
		}
		return false
	}

	func IndexTip() -> [CGPoint] {
		let posIndex: CGPoint? = jointPosition(hand: .right, finger: .index, joint: .tip)
		guard let posIndex else { return [CGPointZero] }
		return [posIndex]
	}
	
}
