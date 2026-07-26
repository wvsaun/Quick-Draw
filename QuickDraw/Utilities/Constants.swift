//
//  Constants.swift
//  QuickDraw
//
//  Every gameplay-tunable number lives here so physical-device tuning is a
//  one-file job. See README.md ("Tuning motion thresholds") for the intended
//  tuning workflow.
//

import Foundation

enum GameTuning {

    // MARK: Networking

    /// Bonjour service type. Must be 1–15 characters, lowercase ASCII letters,
    /// digits and hyphens, and must match the NSBonjourServices Info.plist keys.
    static let serviceType = "quickdraw-duel"

    /// Number of ping/pong exchanges used to estimate the host clock offset.
    static let clockSyncPingCount = 8

    /// Delay between clock-sync pings.
    static let clockSyncPingInterval: TimeInterval = 0.08

    // MARK: Round timeline (all relative, seconds)

    /// Lead time between the host scheduling a round and READY appearing.
    /// Must comfortably exceed one-way message latency so both devices receive
    /// the plan before the timeline starts.
    static let roundLeadTime: TimeInterval = 1.5

    /// READY is displayed for this long, then STEADY appears.
    static let readyToSteady: TimeInterval = 1.2

    /// Suspense delay between STEADY and DRAW. Chosen by the host per round and
    /// never displayed to either player.
    static let suspenseDelayRange: ClosedRange<TimeInterval> = 1.0...3.5

    /// After DRAW, a device that has detected nothing reports "no draw" once
    /// this window closes.
    static let maxDrawWindow: TimeInterval = 4.0

    /// Extra slack the host waits past the draw window before force-resolving
    /// with whatever reports arrived (covers message latency).
    static let hostResolveGrace: TimeInterval = 2.0

    /// When the host receives a false-start report it waits this long for the
    /// other player's report (both players can false-start almost together)
    /// before resolving.
    static let falseStartSettleWindow: TimeInterval = 0.75

    // MARK: Winner resolution

    /// Margins tighter than this still produce a winner but are labelled
    /// "PHOTO FINISH" on both screens.
    static let photoFinishThreshold: TimeInterval = 0.030

    /// A reported reaction below this is physically implausible for a human;
    /// clamp handling documented in RoundResolver.
    static let minPlausibleReaction: TimeInterval = 0.05

    // MARK: Motion sampling

    /// Target device-motion rate during active gameplay. 100 Hz gives ~10 ms
    /// timing resolution, appropriate for reaction comparison, and is only
    /// active from calibration through the end of a round.
    static let motionUpdateHz: Double = 100

    // MARK: Calibration

    static let calibrationDuration: TimeInterval = 2.0
    /// Maximum angular wobble (radians) of gravity around its mean during
    /// calibration for the capture to count as "held still".
    static let calibrationMaxGravityNoise: Double = 0.12
    /// Maximum mean user-acceleration magnitude (g) during calibration.
    static let calibrationMaxAccelNoise: Double = 0.08
    /// The phone must be roughly upright at the hip: the calibrated gravity
    /// vector needs a strong downward component along the device's long axis.
    static let calibrationMinDownwardComponent: Double = 0.55
}
