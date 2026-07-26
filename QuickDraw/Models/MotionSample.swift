//
//  MotionSample.swift
//  QuickDraw
//
//  Platform-free motion types so DrawDetector and CalibrationSession can be
//  unit-tested without Core Motion.
//

import Foundation

/// Minimal 3-vector. Deliberately not SIMD/CoreMotion types so the detector
/// and its tests compile from Foundation alone.
struct Vector3: Codable, Equatable {
    var x: Double
    var y: Double
    var z: Double

    static let zero = Vector3(x: 0, y: 0, z: 0)

    var magnitude: Double { (x * x + y * y + z * z).squareRoot() }

    func dot(_ other: Vector3) -> Double {
        x * other.x + y * other.y + z * other.z
    }

    var normalized: Vector3 {
        let m = magnitude
        guard m > 1e-9 else { return .zero }
        return Vector3(x: x / m, y: y / m, z: z / m)
    }

    /// Angle in radians between two vectors (0 when parallel).
    func angle(to other: Vector3) -> Double {
        let d = normalized.dot(other.normalized).clamped(to: -1.0...1.0)
        return acos(d)
    }
}

/// One device-motion sample in the device reference frame.
/// `timestamp` is in the system-uptime timebase (matches `MonotonicClock.now`).
struct MotionSample: Codable, Equatable {
    var timestamp: TimeInterval
    /// Gravity direction in device coordinates, unit magnitude (in g).
    var gravity: Vector3
    /// User-generated acceleration in g (gravity removed).
    var userAcceleration: Vector3
    /// Rotation rate in rad/s.
    var rotationRate: Vector3
    /// Attitude pitch in radians (diagnostics only; detection uses gravity).
    var pitch: Double
}

/// Output of a successful calibration: the resting pose and its noise floor.
struct CalibrationData: Codable, Equatable {
    /// Mean gravity vector while holstered (unit-ish magnitude).
    var restingGravity: Vector3
    /// Largest angular deviation of gravity from the mean during capture (rad).
    var gravityNoise: Double
    /// Mean user-acceleration magnitude during capture (g).
    var accelerationNoise: Double
    /// Mean attitude pitch during capture (diagnostics).
    var restingPitch: Double
}
