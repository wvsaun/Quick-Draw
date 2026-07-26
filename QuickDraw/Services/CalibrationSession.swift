//
//  CalibrationSession.swift
//  QuickDraw
//
//  Pure accumulator that captures the resting "holstered" pose. The player
//  holds the phone still at the hip for ~2 s; we record the mean gravity
//  vector (the resting orientation), how much it wobbles (sensor + tremor
//  noise), and the mean user acceleration. Those feed DrawDetector.
//

import Foundation

enum CalibrationOutcome: Equatable {
    case success(CalibrationData)
    case failedTooMuchMovement     // gravity wobbled or acceleration too high
    case failedNotUpright          // phone wasn't roughly vertical at the hip
    case failedNoData
}

final class CalibrationSession {

    private var samples: [MotionSample] = []
    private var startTime: TimeInterval?
    private let duration: TimeInterval

    init(duration: TimeInterval = GameTuning.calibrationDuration) {
        self.duration = duration
    }

    /// 0...1 progress for the UI.
    var progress: Double {
        guard let startTime, let last = samples.last else { return 0 }
        return ((last.timestamp - startTime) / duration).clamped(to: 0...1)
    }

    var isComplete: Bool { progress >= 1 }

    func add(_ sample: MotionSample) {
        if startTime == nil { startTime = sample.timestamp }
        samples.append(sample)
    }

    func restart() {
        samples.removeAll()
        startTime = nil
    }

    /// Evaluate the capture. Call once `isComplete`.
    func finish() -> CalibrationOutcome {
        guard samples.count >= 10 else { return .failedNoData }

        var sum = Vector3.zero
        var accelSum = 0.0
        var pitchSum = 0.0
        for s in samples {
            sum = Vector3(x: sum.x + s.gravity.x,
                          y: sum.y + s.gravity.y,
                          z: sum.z + s.gravity.z)
            accelSum += s.userAcceleration.magnitude
            pitchSum += s.pitch
        }
        let n = Double(samples.count)
        let meanGravity = Vector3(x: sum.x / n, y: sum.y / n, z: sum.z / n)
        let meanAccel = accelSum / n
        let meanPitch = pitchSum / n

        // Largest angular deviation from the mean = wobble during capture.
        var maxDeviation = 0.0
        for s in samples {
            maxDeviation = max(maxDeviation, s.gravity.angle(to: meanGravity))
        }

        if maxDeviation > GameTuning.calibrationMaxGravityNoise
            || meanAccel > GameTuning.calibrationMaxAccelNoise {
            return .failedTooMuchMovement
        }
        // Holstered means roughly vertical: gravity mostly along the device's
        // long (y) axis, pointing down (negative y in portrait).
        if abs(meanGravity.y) < GameTuning.calibrationMinDownwardComponent {
            return .failedNotUpright
        }

        return .success(CalibrationData(restingGravity: meanGravity.normalized,
                                        gravityNoise: maxDeviation,
                                        accelerationNoise: meanAccel,
                                        restingPitch: meanPitch))
    }
}
