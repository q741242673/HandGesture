//
//  SpatialGestureProcessor.swift
//  HandGesture
//
//  Created by Yos Hashimoto on 2023/07/30.
//

import CoreGraphics
import UIKit
import Vision

// MARK: SpatialGestureDelegate (gesture callback)

protocol SpatialGestureDelegate {
	func gestureBegan(gesture: SpatialGestureProcessor, atPoints:[CGPoint]);
	func gestureMoved(gesture: SpatialGestureProcessor, atPoints:[CGPoint]);
	func gestureFired(gesture: SpatialGestureProcessor, atPoints:[CGPoint]);
	func gestureEnded(gesture: SpatialGestureProcessor, atPoints:[CGPoint]);
	func gestureCanceled(gesture: SpatialGestureProcessor, atPoints:[CGPoint]);
}

extension SpatialGestureDelegate {
	func gestureBegan(gesture: SpatialGestureProcessor, atPoints:[CGPoint]) {}
	func gestureMoved(gesture: SpatialGestureProcessor, atPoints:[CGPoint]) {}
	func gestureFired(gesture: SpatialGestureProcessor, atPoints:[CGPoint]) {}
	func gestureEnded(gesture: SpatialGestureProcessor, atPoints:[CGPoint]) {}
	func gestureCanceled(gesture: SpatialGestureProcessor, atPoints:[CGPoint]) {}
}

// MARK: SpatialGestureProcessor (Base class of any Gesture)

class SpatialGestureProcessor {

// MARK: enum

	enum State {
		case unknown
		case possible
		case detected
		case waitForNextPose
		case waitForRelease
	}
	enum WhichHand: Int {
		case right = 0
		case left  = 1
	}
	enum WhichFinger: Int {
		case thumb  = 0
		case index
		case middle
		case ring
		case little
		case wrist
	}
	enum WhichJoint: Int {
		case tip = 0	// finger top
		case dip = 1	// first joint
		case pip = 2	// second joint
		case mcp = 3	// third joint
	}
	let wristJointIndex = 0

// MARK: propaties

	var delegate: SpatialGestureDelegate?
	var cameraView: CameraView!
	var drawLayer: DrawLayer?
	var didChangeStateClosure:((State)->Void)?
	var state = State.unknown {
		didSet {
			didChangeStateClosure?(state)
		}
	}
	var defaultHand = WhichHand.right

	var handJoints: [[[VNRecognizedPoint?]]] = []			// array of fingers of both hand (0:right hand, 1:left hand)
	var lastHandJoints: [[[VNRecognizedPoint?]]] = []		// remember first pose

	private var fingerJoints: [[VNRecognizedPoint?]] = []			// array of finger joint position (VisionKit coordinates) --> FINGER_JOINTS
	private var fingerJointsCnv = [[CGPoint?]]()					// array of finger joint position (UIKit coordinates)
	
	init() {
		self.didChangeStateClosure = { [weak self] state in
			self?.handleGestureStateChange(state)
		}
		stateReset()
	}

	convenience init(delegate: UIViewController) {
		self.init()
		self.delegate = delegate as! any SpatialGestureDelegate
	}
	
	private func handleGestureStateChange(_ state: State) {
	}

	func stateReset() {
		clearHandJoints()
		state = .unknown
	}

	// MARK: Compare joint positions
	
    // is finger bend or outstretched
    func isBend(pos1: CGPoint?, pos2: CGPoint?, pos3: CGPoint? ) -> Bool {
        guard let p1 = pos1, let p2 = pos2, let p3 = pos3 else { return false }
        if p1.distance(from: p2) > p1.distance(from: p3) { return true }
        return false
    }
	func isBend(hand: WhichHand, finger: WhichFinger) -> Bool {
		let posTip: CGPoint? = jointPosition(hand:hand, finger:finger, joint: .tip)
		let pos2nd: CGPoint? = jointPosition(hand:hand, finger:finger, joint: .pip)
		let posWrist = jointPosition(hand:hand, finger:.wrist, joint: .tip)
		guard let posTip, let pos2nd, let posWrist else { return false }

		if posWrist.distance(from: pos2nd) > posWrist.distance(from: posTip) { return true }
		return false
	}
    func isStraight(pos1: CGPoint?, pos2: CGPoint?, pos3: CGPoint? ) -> Bool {
        guard let p1 = pos1, let p2 = pos2, let p3 = pos3 else { return false }
        if p1.distance(from: p2) < p1.distance(from: p3) { return true }
        return false
    }
	func isStraight(hand: WhichHand, finger: WhichFinger) -> Bool {
		let posTip: CGPoint? = jointPosition(hand:hand, finger:finger, joint: .tip)
		let pos2nd: CGPoint? = jointPosition(hand:hand, finger:finger, joint: .pip)
		let posWrist = jointPosition(hand:hand, finger:.wrist, joint: .tip)
		guard let posTip, let pos2nd, let posWrist else { return false }

		if posWrist.distance(from: pos2nd) < posWrist.distance(from: posTip) { return true }
		return false
	}

	// is two joints near?
	func isNear(pos1: CGPoint?, pos2: CGPoint?, value: Double) -> Bool {
		guard let p1 = pos1, let p2 = pos2 else { return false }
		if p1.distance(from: p2) < value { return true }
		return false
	}
	// is two joints far enough?
	func isFar(pos1: CGPoint?, pos2: CGPoint?, value: Double) -> Bool {
		guard let p1 = pos1, let p2 = pos2 else { return false }
		if p1.distance(from: p2) > value { return true }
		return false
	}
	// is the joint upper than another?
	func isPoint(_ pos: CGPoint?, isUpperThan: CGPoint?, value: Double) -> Bool {
		guard let p1 = pos, let p2 = isUpperThan else { return false }
		if (p1 - p2).y < value { return true }
		return false
	}
	// is the joint lower than another?
    func isPoint(_ pos: CGPoint?, isLowerThan: CGPoint?, value: Double) -> Bool {
	    guard let p1 = pos, let p2 = isLowerThan else { return false }
	    if (p1 - p2).y > value { return true }
	    return false
    }

	// MARK: Observation processing
	func processHandPoseObservations(observations: [VNHumanHandPoseObservation]) {

		var fingerJoints1 = [[VNRecognizedPoint?]]()
		var fingerJoints2 = [[VNRecognizedPoint?]]()
		var fingerPath = CGMutablePath()
		
		do {
			if observations.count>0 {
				fingerJoints1 = try getFingerJoints(with: observations[0])
				fingerPath.addPath(drawFingers(fingerJoints: fingerJoints1))
			}
			if observations.count>1 {
				fingerJoints2 = try getFingerJoints(with: observations[1])
				fingerPath.addPath(drawFingers(fingerJoints: fingerJoints2))
			}

			// decide which hand is right/left
			switch observations.count {
			case 1:
				handJoints.removeAll()
				handJoints.insert(fingerJoints1, at: defaultHand.rawValue)
			case 2:
				let thumbPos1 = jointPosition(hand: fingerJoints1, finger: WhichFinger.thumb.rawValue, joint: WhichJoint.tip.rawValue)
				let thumbPos2 = jointPosition(hand: fingerJoints2, finger: WhichFinger.thumb.rawValue, joint: WhichJoint.tip.rawValue)
				guard let pos1=thumbPos1, let pos2=thumbPos2 else {
					return
				}
				handJoints.removeAll()
				if pos1.x < pos2.x {
					handJoints.append(fingerJoints2)	// WhichHand.right
					handJoints.append(fingerJoints1)
				}
				else {
					handJoints.append(fingerJoints1)	// WhichHand.right
					handJoints.append(fingerJoints2)
				}
			default:
				handJoints.removeAll()
			}
			
		} catch {
			NSLog("Error")
		}

		drawLayer?.path = fingerPath	// draw bones

		checkGesture()
	}

	func checkGesture() {
		
	}
	
	// save joint data array for later use
	func saveHandJoints() {
		lastHandJoints.removeAll()
		lastHandJoints.append(handJoints[0])
		if handJoints.count > 1 {
			lastHandJoints.append(handJoints[1])
		}
	}
	
	// clear last joint data array
	func clearHandJoints() {
		lastHandJoints.removeAll()
	}
	
	// get finger joint position array (VisionKit coordinate)
	func getFingerJoints(with observation: VNHumanHandPoseObservation) throws -> [[VNRecognizedPoint?]] {
		do {
			let fingers = try observation.recognizedPoints(.all)
			// get all finger joint point in VisionKit coordinate (VNRecognizedPoint)
			fingerJoints = [	// (FINGER_JOINTS)
				[fingers[.thumbTip], fingers[.thumbIP],  fingers[.thumbMP],  fingers[.thumbCMC]],
				[fingers[.indexTip], fingers[.indexDIP], fingers[.indexPIP], fingers[.indexMCP]],
				[fingers[.middleTip],fingers[.middleDIP],fingers[.middlePIP],fingers[.middleMCP]],
				[fingers[.ringTip],  fingers[.ringDIP],  fingers[.ringPIP],  fingers[.ringMCP]],
				[fingers[.littleTip],fingers[.littleDIP],fingers[.littlePIP],fingers[.littleMCP]],
				[fingers[.wrist]]	// <-- wrist joint here
			]
		} catch {
			NSLog("Error")
		}
		return fingerJoints
	}

	// get joint position (UIKit coordinates)
	func jointPosition(hand: [[VNRecognizedPoint?]], finger: Int, joint: Int) -> CGPoint? {
		if finger==WhichFinger.wrist.rawValue {
			return cnv(hand[finger][wristJointIndex])
		}
		else {
			return cnv(hand[finger][joint])
		}
	}
	func jointPosition(hand: WhichHand, finger: WhichFinger, joint: WhichJoint) -> CGPoint? {
		
		var jnt = joint.rawValue
		if finger == .wrist { jnt = wristJointIndex }

		switch handJoints.count {
		case 1:
			return jointPosition(hand:handJoints[WhichHand.right.rawValue], finger:finger.rawValue, joint:jnt)
		case 2:
			return jointPosition(hand:handJoints[hand.rawValue], finger:finger.rawValue, joint:jnt)
		default:
			return nil
		}
	}
	func lastJointPosition(hand: WhichHand, finger: WhichFinger, joint: WhichJoint) -> CGPoint? {

		var jnt = joint.rawValue
		if finger == .wrist { jnt = wristJointIndex }

		switch lastHandJoints.count {
		case 1:
			return jointPosition(hand:lastHandJoints[WhichHand.right.rawValue], finger:finger.rawValue, joint:jnt)
		case 2:
			return jointPosition(hand:lastHandJoints[hand.rawValue], finger:finger.rawValue, joint:jnt)
		default:
			return nil
		}
	}

	// conver coordinate : VisionKit --> AVFoundation (video) --> UIKit
	func cnv(_ point: VNRecognizedPoint?) -> CGPoint? {
		guard let point else { return nil }
		if point.confidence < 0.6 { return nil }	// ignore if confidence is low
		
		let point2 = CGPoint(x: point.location.x, y: 1 - point.location.y)
		let previewLayer = cameraView.previewLayer
		let pointConverted = previewLayer.layerPointConverted(fromCaptureDevicePoint: point2)
//		NSLog("%f, %f", pointConverted.x, pointConverted.y)
		return pointConverted
	}

	// draw finger bones
	func drawFingers(fingerJoints: [[VNRecognizedPoint?]]) -> CGMutablePath {
		let path = CGMutablePath()
		for fingerjoint in fingerJoints {
			var i = 0
			for joint in fingerjoint {
				let point = cnv(joint)
				guard let point else { continue }
				if i>0 {
					path.addLine(to: point)			// Line
				}
				path.addPath(drawJoint(at: point))	// Dot
				if i==WhichFinger.wrist.rawValue { break }
				path.move(to: point)
				i += 1
			}
		}
		
		if !path.isEmpty {
			path.closeSubpath()
		}
		
		return path
	}

	func drawJoint(at point: CGPoint) -> CGPath {
		return CGPath(roundedRect: CGRect(x: point.x - 5, y: point.y - 5, width: 10, height: 10), cornerWidth: 5, cornerHeight: 5, transform: nil)
	}

}
