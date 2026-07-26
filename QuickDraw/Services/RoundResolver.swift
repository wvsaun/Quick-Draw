//
//  RoundResolver.swift
//  QuickDraw
//
//  Host-authoritative outcome resolution. Pure and fully unit-tested; the
//  host feeds it the two PlayerRoundReports (or fewer after a timeout) and
//  broadcasts the single ResolvedRound it returns. Devices NEVER decide the
//  winner locally.
//

import Foundation

struct ResolverConfiguration: Equatable {
    var photoFinishThreshold: TimeInterval = GameTuning.photoFinishThreshold
    var minPlausibleReaction: TimeInterval = GameTuning.minPlausibleReaction
    var maxPlausibleReaction: TimeInterval = GameTuning.maxDrawWindow + 1.0
}

struct RoundResolver {

    var configuration = ResolverConfiguration()

    /// Resolve a round between `players` from whatever reports arrived.
    ///
    /// - Parameters:
    ///   - reports: reports keyed by player, already filtered to `roundID`.
    ///   - timedOut: true when the host's resolve deadline passed; missing
    ///     reports are then treated as "no draw".
    /// - Returns: the official result, or nil when the host should keep
    ///   waiting (not all reports in and not timed out — except that a lone
    ///   false start with the settle window elapsed resolves immediately via
    ///   `timedOut`).
    func resolve(roundID: UUID,
                 players: (UUID, UUID),
                 reports: [UUID: PlayerRoundReport],
                 timedOut: Bool) -> ResolvedRound? {

        let a = reports[players.0]
        let b = reports[players.1]

        // Ignore anything from the wrong round (defence in depth; the caller
        // should have filtered already).
        if let a, a.roundID != roundID { return voidRound(roundID, .invalidData) }
        if let b, b.roundID != roundID { return voidRound(roundID, .invalidData) }

        guard a != nil && b != nil || timedOut else { return nil }

        let reportA = a ?? .noDraw(playerID: players.0, roundID: roundID)
        let reportB = b ?? .noDraw(playerID: players.1, roundID: roundID)
        return decide(roundID: roundID, reportA, reportB)
    }

    private func decide(roundID: UUID,
                        _ a: PlayerRoundReport,
                        _ b: PlayerRoundReport) -> ResolvedRound {

        // False starts dominate everything else.
        switch (a.falseStart, b.falseStart) {
        case (true, true):
            return ResolvedRound(roundID: roundID, winnerID: nil,
                                 reason: .bothFalseStart, times: [:],
                                 falseStarters: [a.playerID, b.playerID],
                                 margin: nil, photoFinish: false)
        case (true, false):
            return falseStartLoss(roundID: roundID, offender: a, winner: b)
        case (false, true):
            return falseStartLoss(roundID: roundID, offender: b, winner: a)
        case (false, false):
            break
        }

        // Validate timings. A negative elapsed means the device claims it drew
        // before its own DRAW moment without flagging a false start — that is
        // corrupted/desynchronized data, so the round is void.
        for report in [a, b] {
            if let t = report.elapsed,
               t < 0 || t > configuration.maxPlausibleReaction {
                return voidRound(roundID, .invalidData)
            }
        }

        switch (a.elapsed, b.elapsed) {
        case (nil, nil):
            return voidRound(roundID, .noDraws)

        case (.some(let ta), nil):
            return ResolvedRound(roundID: roundID, winnerID: a.playerID,
                                 reason: .opponentNoDraw,
                                 times: [a.playerID: ta],
                                 falseStarters: [], margin: nil, photoFinish: false)

        case (nil, .some(let tb)):
            return ResolvedRound(roundID: roundID, winnerID: b.playerID,
                                 reason: .opponentNoDraw,
                                 times: [b.playerID: tb],
                                 falseStarters: [], margin: nil, photoFinish: false)

        case (.some(let ta), .some(let tb)):
            // Earliest valid draw wins — even a hair's difference counts, per
            // the rules; margins inside the threshold get the PHOTO FINISH
            // label but still produce the measured winner. Exact ties go to
            // the deterministic lower UUID so both screens always agree.
            let winner: PlayerRoundReport
            let loser: PlayerRoundReport
            if ta == tb {
                let aWins = a.playerID.uuidString < b.playerID.uuidString
                winner = aWins ? a : b
                loser = aWins ? b : a
            } else {
                winner = ta < tb ? a : b
                loser = ta < tb ? b : a
            }
            let margin = abs(ta - tb)
            return ResolvedRound(roundID: roundID, winnerID: winner.playerID,
                                 reason: .fasterDraw,
                                 times: [a.playerID: ta, b.playerID: tb],
                                 falseStarters: [],
                                 margin: margin,
                                 photoFinish: margin <= configuration.photoFinishThreshold)
        }
    }

    private func falseStartLoss(roundID: UUID,
                                offender: PlayerRoundReport,
                                winner: PlayerRoundReport) -> ResolvedRound {
        var times: [UUID: TimeInterval] = [:]
        if let t = winner.elapsed, t >= 0 { times[winner.playerID] = t }
        return ResolvedRound(roundID: roundID, winnerID: winner.playerID,
                             reason: .opponentFalseStart, times: times,
                             falseStarters: [offender.playerID],
                             margin: nil, photoFinish: false)
    }

    private func voidRound(_ roundID: UUID, _ reason: RoundEndReason) -> ResolvedRound {
        ResolvedRound(roundID: roundID, winnerID: nil, reason: reason,
                      times: [:], falseStarters: [], margin: nil, photoFinish: false)
    }
}
