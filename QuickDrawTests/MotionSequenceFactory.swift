//
//  MotionSequenceFactory.swift
//  QuickDrawTests
//
//  Generates synthetic 100 Hz motion-sample sequences that mimic real
//  gestures, so DrawDetector can be exercised deterministically.
//

import Foundation
@testable import QuickDraw

enum MotionSequenceFactory {

    static let dt: TimeInterval = 0.01  // 100 Hz

    /// Canonical resting pose: phone vertical at the hip, gravity straight
    /// down the device's long axis.
    static let restingGravity = Vector3(x: 0, y: -1, z: 0)

    static var calibration: CalibrationData {
        CalibrationData(restingGravity: restingGravity,
                        gravityNoise: 0.02,
                        accelerationNoise: 0.01,
                        restingPitch: 0)
    }

    /// Phone perfectly still (tiny sensor noise only).
    static func still(from start: TimeInterval,
                      duration: TimeInterval,
                      noise: Double = 0.005) -> [MotionSample] {
        stride(from: 0.0, to: duration, by: dt).enumerated().map { index, offset in
            let wobble = noise * sin(Double(index) * 1.3)
            return MotionSample(
                timestamp: start + offset,
                gravity: Vector3(x: wobble, y: -1 + abs(wobble) * 0.1, z: wobble * 0.5),
                userAcceleration: Vector3(x: wobble, y: wobble, z: wobble),
                rotationRate: Vector3(x: wobble * 2, y: wobble, z: wobble),
                pitch: wobble)
        }
    }

    /// A genuine draw: the phone rotates from vertical (gravity −y) to
    /// roughly horizontal (gravity −z) over `duration`, with a strong
    /// rotation-rate bell curve and moderate acceleration.
    static func draw(from start: TimeInterval,
                     duration: TimeInterval = 0.25,
                     peakRotation: Double = 6.0,
                     finalTiltDegrees: Double = 80) -> [MotionSample] {
        let steps = max(2, Int(duration / dt))
        let finalTilt = finalTiltDegrees * .pi / 180
        return (0...steps).map { i in
            let progress = Double(i) / Double(steps)          // 0 → 1
            let angle = finalTilt * progress                  // rotation about x
            // Bell-shaped angular velocity peaking mid-gesture.
            let bell = sin(progress * .pi)
            return MotionSample(
                timestamp: start + Double(i) * dt,
                gravity: Vector3(x: 0, y: -cos(angle), z: -sin(angle)),
                userAcceleration: Vector3(x: 0, y: 0.4 * bell, z: 0.5 * bell),
                rotationRate: Vector3(x: peakRotation * bell, y: 0, z: 0),
                pitch: angle)
        }
    }

    /// Vigorous shaking in place: high rotation and acceleration but the
    /// pose (gravity) barely changes.
    static func shake(from start: TimeInterval,
                      duration: TimeInterval = 0.6) -> [MotionSample] {
        stride(from: 0.0, to: duration, by: dt).enumerated().map { index, offset in
            let s = sin(Double(index) * 2.0)
            return MotionSample(
                timestamp: start + offset,
                gravity: Vector3(x: 0.05 * s, y: -0.995, z: 0.03 * s),
                userAcceleration: Vector3(x: 0.8 * s, y: 0.6 * s, z: 0.7 * s),
                rotationRate: Vector3(x: 3.5 * s, y: 2.5 * s, z: 3.0 * s),
                pitch: 0.05 * s)
        }
    }

    /// Small wrist adjustment: brief mild movement, small tilt, settles back.
    static func wristAdjust(from start: TimeInterval) -> [MotionSample] {
        var samples: [MotionSample] = []
        var t = start
        // 150 ms of mild movement (~11° tilt).
        for i in 0..<15 {
            let progress = Double(i) / 15.0
            let angle = 0.2 * sin(progress * .pi)
            samples.append(MotionSample(
                timestamp: t,
                gravity: Vector3(x: 0, y: -cos(angle), z: -sin(angle)),
                userAcceleration: Vector3(x: 0.1, y: 0.15, z: 0.1),
                rotationRate: Vector3(x: 1.8 * sin(progress * .pi), y: 0, z: 0),
                pitch: angle))
            t += dt
        }
        samples.append(contentsOf: still(from: t, duration: 0.8))
        return samples
    }

    /// Movement in the wrong direction: a partial downward/backward scoop
    /// with a real rotation burst, but the phone never reaches the raised
    /// pose (final tilt stays well under the confirmation threshold).
    static func wrongDirection(from start: TimeInterval,
                               duration: TimeInterval = 0.3) -> [MotionSample] {
        let steps = max(2, Int(duration / dt))
        let finalAngle = 0.5  // rad — below confirmTiltAngle
        return (0...steps).map { i in
            let progress = Double(i) / Double(steps)
            let angle = finalAngle * progress
            let bell = sin(progress * .pi)
            return MotionSample(
                timestamp: start + Double(i) * dt,
                gravity: Vector3(x: 0, y: -cos(angle), z: sin(angle)),
                userAcceleration: Vector3(x: 0, y: 0.3 * bell, z: 0.3 * bell),
                rotationRate: Vector3(x: -4.0 * bell, y: 0, z: 0),
                pitch: -angle)
        }
    }

    /// A slow, sneaky pre-aim: raising the phone gradually with almost no
    /// rotation rate (trying to cheat before the signal).
    static func slowLift(from start: TimeInterval,
                         duration: TimeInterval = 1.5) -> [MotionSample] {
        let steps = max(2, Int(duration / dt))
        let finalTilt = 1.1
        return (0...steps).map { i in
            let progress = Double(i) / Double(steps)
            let angle = finalTilt * progress
            return MotionSample(
                timestamp: start + Double(i) * dt,
                gravity: Vector3(x: 0, y: -cos(angle), z: -sin(angle)),
                userAcceleration: Vector3(x: 0.02, y: 0.03, z: 0.02),
                rotationRate: Vector3(x: finalTilt / duration, y: 0, z: 0),
                pitch: angle)
        }
    }
}
