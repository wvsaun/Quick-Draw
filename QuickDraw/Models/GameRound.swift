//
//  GameRound.swift
//  QuickDraw
//

import Foundation

/// The host's schedule for one round. All times are in the HOST's monotonic
/// (system-uptime) timebase; the joiner converts them with its estimated clock
/// offset before scheduling anything locally.
struct RoundPlan: Codable, Equatable {
    let roundID: UUID
    /// When "READY" appears.
    let readyAt: TimeInterval
    /// When "STEADY" appears.
    let steadyAt: TimeInterval
    /// When "DRAW!" fires. steadyAt→drawAt includes the secret suspense delay.
    let drawAt: TimeInterval

    /// Host-side factory. `now` is injected for testability.
    static func schedule(roundID: UUID,
                         now: TimeInterval,
                         suspenseDelay: TimeInterval) -> RoundPlan {
        let ready = now + GameTuning.roundLeadTime
        let steady = ready + GameTuning.readyToSteady
        return RoundPlan(roundID: roundID,
                         readyAt: ready,
                         steadyAt: steady,
                         drawAt: steady + suspenseDelay)
    }
}
