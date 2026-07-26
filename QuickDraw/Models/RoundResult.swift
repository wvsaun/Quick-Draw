//
//  RoundResult.swift
//  QuickDraw
//

import Foundation

/// What one device tells the host about its round.
/// `elapsed` is the reaction time measured locally against the synchronized
/// DRAW moment (motion-sample timestamp minus local draw time), or nil when
/// the player never drew inside the window.
struct PlayerRoundReport: Codable, Equatable {
    let playerID: UUID
    let roundID: UUID
    let elapsed: TimeInterval?
    let falseStart: Bool
    /// Supporting metrics for diagnostics/tuning (not used for resolution).
    var peakRotation: Double?
    var tiltAngle: Double?

    static func draw(playerID: UUID, roundID: UUID, elapsed: TimeInterval,
                     peakRotation: Double? = nil, tiltAngle: Double? = nil) -> PlayerRoundReport {
        PlayerRoundReport(playerID: playerID, roundID: roundID, elapsed: elapsed,
                          falseStart: false, peakRotation: peakRotation, tiltAngle: tiltAngle)
    }

    static func falseStart(playerID: UUID, roundID: UUID) -> PlayerRoundReport {
        PlayerRoundReport(playerID: playerID, roundID: roundID, elapsed: nil,
                          falseStart: true, peakRotation: nil, tiltAngle: nil)
    }

    static func noDraw(playerID: UUID, roundID: UUID) -> PlayerRoundReport {
        PlayerRoundReport(playerID: playerID, roundID: roundID, elapsed: nil,
                          falseStart: false, peakRotation: nil, tiltAngle: nil)
    }
}

/// Why the round ended the way it did — from the WINNER's perspective when
/// there is a winner, otherwise a void/neutral reason.
enum RoundEndReason: String, Codable {
    case fasterDraw          // both drew; earliest valid draw wins
    case opponentFalseStart  // loser moved before DRAW
    case opponentNoDraw      // loser never drew inside the window
    case bothFalseStart      // void: both moved early → replay
    case noDraws             // void: neither player drew
    case invalidData         // void: timing data was implausible
    case disconnected        // void: a player dropped mid-round
}

/// The host's official, authoritative outcome, broadcast to both devices.
struct ResolvedRound: Codable, Equatable {
    let roundID: UUID
    /// nil when the round is void (bothFalseStart / noDraws / invalidData).
    let winnerID: UUID?
    let reason: RoundEndReason
    /// Valid reaction times by player (absent for false start / no draw).
    let times: [UUID: TimeInterval]
    let falseStarters: [UUID]
    /// Winner's margin over the loser when both times exist.
    let margin: TimeInterval?
    /// True when the margin was inside GameTuning.photoFinishThreshold.
    let photoFinish: Bool

    var isVoid: Bool { winnerID == nil }
}
