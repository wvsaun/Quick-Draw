//
//  GameStateGates.swift
//  QuickDraw
//
//  Small pure gates the GameViewModel consults before allowing transitions.
//  Extracted so state rules are unit-testable without services or UI.
//

import Foundation

/// A round can only start when exactly two connected players are both ready,
/// both calibrated, and motion hardware works.
struct ReadinessGate: Equatable {
    var isConnected = false
    var localReady = false
    var opponentReady = false
    var motionAvailable = false

    var canProceedToCalibration: Bool {
        isConnected && localReady && opponentReady && motionAvailable
    }
}

/// Drops packets that belong to a different round than the current one.
struct RoundGate: Equatable {
    private(set) var currentRoundID: UUID?

    mutating func beginRound(_ id: UUID) { currentRoundID = id }
    mutating func endRound() { currentRoundID = nil }

    /// A message with no round ID passes (lobby traffic); a round-scoped
    /// message passes only when it matches the active round.
    func allows(_ messageRoundID: UUID?) -> Bool {
        guard let messageRoundID else { return true }
        return messageRoundID == currentRoundID
    }
}

/// A rematch starts only when BOTH current players asked for one.
struct RematchCoordinator: Equatable {
    private(set) var votes: Set<UUID> = []

    mutating func vote(playerID: UUID) { votes.insert(playerID) }
    mutating func reset() { votes.removeAll() }

    func bothAgreed(players: (UUID, UUID)) -> Bool {
        votes.contains(players.0) && votes.contains(players.1)
    }
}

/// Tracks per-player calibration completion; gameplay is gated on both.
struct CalibrationGate: Equatable {
    private(set) var completed: Set<UUID> = []

    mutating func markComplete(playerID: UUID) { completed.insert(playerID) }
    mutating func reset() { completed.removeAll() }

    func bothCalibrated(players: (UUID, UUID)) -> Bool {
        completed.contains(players.0) && completed.contains(players.1)
    }
}
