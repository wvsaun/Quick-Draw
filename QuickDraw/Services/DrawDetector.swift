//
//  DrawDetector.swift
//  QuickDraw
//
//  Pure state machine that turns a stream of MotionSamples into exactly one
//  gameplay event per round: a confirmed draw, a false start, or nothing.
//
//  WHY EACH SIGNAL IS USED
//  ────────────────────────
//  • Gravity tilt (angle between the live gravity vector and the CALIBRATED
//    resting gravity): the primary "the phone actually left the holster and
//    was raised" signal. Gravity is low-noise and orientation-absolute, so it
//    cannot be faked by shaking the phone in place.
//  • Raise direction (change in gravity.y, the device's long axis): a draw
//    rotates the phone from vertical-at-the-hip toward horizontal-aiming, so
//    gravity's long-axis component must shrink (delta ≥ confirmMinRaise).
//    Tilting the phone further DOWN or scooping sideways fails this check —
//    that is the "directional consistency" requirement.
//  • Rotation rate peak: a genuine draw is a deliberate rotation; requiring a
//    real angular-velocity peak rejects slow drifts that accumulate tilt
//    (e.g. slowly lifting the phone before the signal).
//  • User acceleration: helps detect the onset of movement quickly (it leads
//    the tilt change), but never confirms a draw by itself because walking
//    and hand tremor produce plenty of acceleration with no pose change.
//  • Consecutive-sample gate: movement only "starts" after N consecutive
//    above-threshold samples, so ONE noisy sample can never trigger anything.
//  • Duration window: the tilt threshold must be crossed between
//    minDrawDuration and maxDrawDuration after movement start. Too fast ⇒
//    physically implausible spike; too slow ⇒ not a draw, reset.
//
//  HOW FALSE POSITIVES ARE REDUCED
//  ────────────────────────────────
//  Tremor/walking: fails the tilt requirement (pose never changes) and the
//  movement-start streak resets whenever a sample dips below threshold.
//  Wrist adjustment: movement starts but subsides below the reset thresholds
//  before the tilt confirms ⇒ detector quietly returns to holstered.
//  Slow pre-signal lift: no rotation peak ⇒ never confirms as a draw; but a
//  sustained large pre-signal tilt IS a false start (you may not pre-aim).
//  Duplicate detections: the machine latches in drawConfirmed/falseStart and
//  emits nothing further until reset() is called for the next round.
//
//  HOW TO TUNE ON DEVICE
//  ──────────────────────
//  Enable Settings → Developer diagnostics, run rounds, and watch live tilt /
//  rotation / acceleration values on the overlay. All defaults live in
//  DrawDetectorConfiguration below and scale with the Motion Sensitivity
//  setting. See README.md for the recommended tuning procedure.
//

import Foundation

/// User-facing sensitivity presets. "High" makes draws easier to trigger
/// (lower thresholds); "Low" requires a more decisive motion.
enum MotionSensitivity: String, CaseIterable, Codable {
    case low, standard, high

    /// Multiplier applied to confirmation thresholds.
    var thresholdScale: Double {
        switch self {
        case .low: return 1.25
        case .standard: return 1.0
        case .high: return 0.75
        }
    }
}

struct DrawDetectorConfiguration: Equatable {
    // ── Movement-start gate ──────────────────────────────────────────────
    /// Rotation rate (rad/s) that counts as "moving".
    var startRotationRate: Double = 1.4
    /// User acceleration (g) that counts as "moving".
    var startAcceleration: Double = 0.30
    /// Consecutive above-threshold samples required before movement starts
    /// (3 samples ≈ 30 ms at 100 Hz). Kills isolated sensor spikes.
    var startConsecutiveSamples: Int = 3

    // ── Draw confirmation ────────────────────────────────────────────────
    /// Tilt away from the calibrated resting gravity (rad) that confirms the
    /// phone was raised. 0.9 rad ≈ 52°.
    var confirmTiltAngle: Double = 0.9
    /// The gravity component along the device's long axis must have moved
    /// toward zero by at least this much (g). This is the direction check.
    var confirmMinRaise: Double = 0.40
    /// Peak rotation rate (rad/s) that must occur during the movement.
    var confirmMinRotationPeak: Double = 2.0
    /// Tilt must confirm within this window after movement start.
    var minDrawDuration: TimeInterval = 0.05
    var maxDrawDuration: TimeInterval = 1.5

    // ── False-start policy (before the DRAW signal) ──────────────────────
    /// Pre-signal tilt a player may accumulate without penalty (grace for
    /// tremor and small adjustments). 0.35 rad ≈ 20°.
    var preSignalTiltTolerance: Double = 0.35
    /// Pre-signal movement must sustain an above-tolerance tilt this long to
    /// be called a false start (a single twitch is forgiven).
    var preSignalSustain: TimeInterval = 0.25

    // ── Reset back to holstered ──────────────────────────────────────────
    /// Movement is considered subsided below these.
    var resetRotationRate: Double = 0.5
    var resetAcceleration: Double = 0.12
    var resetTiltAngle: Double = 0.25
    /// Quiet time required in invalidMovement before re-arming.
    var resetHoldDuration: TimeInterval = 0.4

    /// Build a configuration scaled for the user's sensitivity preset.
    static func forSensitivity(_ sensitivity: MotionSensitivity) -> DrawDetectorConfiguration {
        var config = DrawDetectorConfiguration()
        let scale = sensitivity.thresholdScale
        config.confirmTiltAngle *= scale
        config.confirmMinRaise *= scale
        config.confirmMinRotationPeak *= scale
        config.startRotationRate *= scale
        config.startAcceleration *= scale
        return config
    }
}

enum DrawDetectorState: String, Equatable {
    case idle              // not armed (outside a round)
    case holstered
    case movementStarted
    case drawConfirmed
    case invalidMovement
    case resetting
}

/// Event emitted by `process(_:)`. At most one draw/falseStart per arm cycle.
enum DrawDetectionEvent: Equatable {
    case movementStarted(at: TimeInterval)
    /// timestamp = motion-sample time the tilt threshold was crossed.
    case drawConfirmed(at: TimeInterval, peakRotation: Double, tilt: Double)
    case falseStart(at: TimeInterval)
    case returnedToHolster
}

final class DrawDetector {

    private(set) var state: DrawDetectorState = .idle
    var configuration: DrawDetectorConfiguration
    private(set) var calibration: CalibrationData?

    /// Motion timestamps at/after which samples are considered (arm moment)
    /// and at/after which a confirmed draw is legal (the DRAW signal).
    /// Both are in the sample timebase (system uptime).
    private var armedAt: TimeInterval?
    private var drawSignalAt: TimeInterval?

    // Movement bookkeeping
    private var startStreak = 0
    private var movementStartTime: TimeInterval?
    private var peakRotation: Double = 0
    private var preSignalTiltSince: TimeInterval?
    private var quietSince: TimeInterval?
    private var latched = false   // a draw/falseStart has been emitted this cycle

    // Live values exposed for the diagnostics overlay.
    private(set) var lastTilt: Double = 0
    private(set) var lastRotationMagnitude: Double = 0
    private(set) var lastAccelerationMagnitude: Double = 0

    init(configuration: DrawDetectorConfiguration = DrawDetectorConfiguration()) {
        self.configuration = configuration
    }

    func setCalibration(_ data: CalibrationData) {
        calibration = data
    }

    /// Arm for a round. Samples earlier than `armTime` are ignored; a full
    /// draw completed before `signalTime` is a false start, at/after it a win.
    func arm(at armTime: TimeInterval, signalAt signalTime: TimeInterval) {
        armedAt = armTime
        drawSignalAt = signalTime
        state = .holstered
        startStreak = 0
        movementStartTime = nil
        peakRotation = 0
        preSignalTiltSince = nil
        quietSince = nil
        latched = false
    }

    /// Disarm and go idle (round over / aborted).
    func reset() {
        state = .idle
        armedAt = nil
        drawSignalAt = nil
        startStreak = 0
        movementStartTime = nil
        peakRotation = 0
        preSignalTiltSince = nil
        quietSince = nil
        latched = false
    }

    /// Feed one motion sample; returns an event when something notable happened.
    func process(_ sample: MotionSample) -> DrawDetectionEvent? {
        guard let calibration, let armedAt, let drawSignalAt,
              state != .idle, !latched,
              sample.timestamp >= armedAt else { return nil }

        let tilt = sample.gravity.angle(to: calibration.restingGravity)
        let rotation = sample.rotationRate.magnitude
        let acceleration = sample.userAcceleration.magnitude
        // Positive when gravity's long-axis component moved toward zero, i.e.
        // the phone rotated from vertical toward the raised/aiming pose.
        let raise = abs(calibration.restingGravity.y) - abs(sample.gravity.y)
        let beforeSignal = sample.timestamp < drawSignalAt

        lastTilt = tilt
        lastRotationMagnitude = rotation
        lastAccelerationMagnitude = acceleration

        switch state {
        case .idle, .drawConfirmed:
            return nil

        case .holstered:
            let moving = rotation > configuration.startRotationRate
                || acceleration > configuration.startAcceleration
                || tilt > configuration.preSignalTiltTolerance
            if moving {
                startStreak += 1
                if startStreak >= configuration.startConsecutiveSamples {
                    state = .movementStarted
                    movementStartTime = sample.timestamp
                    peakRotation = rotation
                    preSignalTiltSince = nil
                    return .movementStarted(at: sample.timestamp)
                }
            } else {
                startStreak = 0
            }
            return nil

        case .movementStarted:
            guard let started = movementStartTime else { return nil }
            peakRotation = max(peakRotation, rotation)
            let sinceStart = sample.timestamp - started

            // Full draw shape reached?
            let drawShape = tilt >= configuration.confirmTiltAngle
                && raise >= configuration.confirmMinRaise
                && peakRotation >= configuration.confirmMinRotationPeak
                && sinceStart >= configuration.minDrawDuration
            if drawShape {
                latched = true
                if beforeSignal {
                    state = .invalidMovement
                    return .falseStart(at: sample.timestamp)
                }
                state = .drawConfirmed
                return .drawConfirmed(at: sample.timestamp,
                                      peakRotation: peakRotation,
                                      tilt: tilt)
            }

            // Pre-signal sustained pre-aim (holding a big tilt without a full
            // draw) is also a false start once it outlives the grace window.
            if beforeSignal {
                if tilt > configuration.preSignalTiltTolerance {
                    if preSignalTiltSince == nil { preSignalTiltSince = sample.timestamp }
                    if let since = preSignalTiltSince,
                       sample.timestamp - since >= configuration.preSignalSustain {
                        latched = true
                        state = .invalidMovement
                        return .falseStart(at: sample.timestamp)
                    }
                } else {
                    preSignalTiltSince = nil
                }
            }

            // Took too long without confirming ⇒ not a draw.
            if sinceStart > configuration.maxDrawDuration {
                state = .invalidMovement
                quietSince = nil
                return nil
            }

            // Movement subsided without a draw (small wrist adjustment).
            let subsided = rotation < configuration.resetRotationRate
                && acceleration < configuration.resetAcceleration
                && tilt < configuration.resetTiltAngle
            if subsided {
                state = .holstered
                startStreak = 0
                movementStartTime = nil
                peakRotation = 0
                preSignalTiltSince = nil
                return .returnedToHolster
            }
            return nil

        case .invalidMovement:
            // Wait for sustained quiet, then re-arm (unless latched).
            let quiet = rotation < configuration.resetRotationRate
                && acceleration < configuration.resetAcceleration
                && tilt < configuration.resetTiltAngle
            if quiet {
                if quietSince == nil { quietSince = sample.timestamp }
                if let since = quietSince,
                   sample.timestamp - since >= configuration.resetHoldDuration {
                    state = .resetting
                }
            } else {
                quietSince = nil
            }
            return nil

        case .resetting:
            state = .holstered
            startStreak = 0
            movementStartTime = nil
            peakRotation = 0
            quietSince = nil
            return .returnedToHolster
        }
    }
}
