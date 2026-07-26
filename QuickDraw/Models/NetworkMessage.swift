//
//  NetworkMessage.swift
//  QuickDraw
//
//  Strongly typed wire protocol. Swift synthesizes Codable for enums with
//  associated values, so every message round-trips through JSON without any
//  stringly-typed dictionaries.
//

import Foundation

enum NetworkMessage: Codable, Equatable {
    /// First message after connecting: who am I.
    case hello(profile: PlayerProfile)
    /// Lobby ready toggle.
    case readyChanged(playerID: UUID, isReady: Bool)
    /// Host → both: leave the lobby and calibrate.
    case beginCalibration
    /// Device → host (and host → device): my calibration finished.
    case calibrationDone(playerID: UUID)
    /// Host → both: enter the pre-round "holster your phone" screen.
    case beginPositioning(roundID: UUID)
    /// Device → host: I'm in position for this round.
    case positionConfirmed(playerID: UUID, roundID: UUID)
    /// Host → joiner: the official timeline for this round (host clock).
    case roundScheduled(plan: RoundPlan)
    /// Device → host: my round outcome (draw / false start / no draw).
    case report(PlayerRoundReport)
    /// Host → both: the one official result.
    case roundResult(ResolvedRound)
    /// Either → host: I want a rematch of/after this round.
    case rematchRequest(playerID: UUID, afterRoundID: UUID)
    /// Politely leaving; the peer should return to home.
    case leaveGame(playerID: UUID)
    /// Clock sync: joiner → host with the joiner's monotonic send time.
    case syncPing(id: Int, senderTime: TimeInterval)
    /// Clock sync: host → joiner echoing the ping plus the host's monotonic time.
    case syncPong(id: Int, senderTime: TimeInterval, hostTime: TimeInterval)

    /// Round ID carried by round-scoped messages, used to drop stale packets.
    var roundID: UUID? {
        switch self {
        case .beginPositioning(let id): return id
        case .positionConfirmed(_, let id): return id
        case .roundScheduled(let plan): return plan.roundID
        case .report(let report): return report.roundID
        case .roundResult(let result): return result.roundID
        default: return nil
        }
    }
}

/// Every message travels inside an envelope with a per-sender sequence number
/// so duplicated packets can be dropped (MCSession .reliable is ordered, so
/// "seq not greater than the last seen" ⇒ duplicate/stale).
struct MessageEnvelope: Codable, Equatable {
    let seq: Int
    let message: NetworkMessage

    func encoded() throws -> Data {
        try JSONEncoder().encode(self)
    }

    static func decode(_ data: Data) throws -> MessageEnvelope {
        try JSONDecoder().decode(MessageEnvelope.self, from: data)
    }
}

/// Tracks the highest sequence number seen from the (single) peer and rejects
/// anything not newer. Pure and unit-tested.
struct DuplicateFilter {
    private(set) var lastSeq: Int = -1

    /// Returns true when the envelope is fresh and should be processed.
    mutating func accept(_ envelope: MessageEnvelope) -> Bool {
        guard envelope.seq > lastSeq else { return false }
        lastSeq = envelope.seq
        return true
    }

    mutating func reset() { lastSeq = -1 }
}
