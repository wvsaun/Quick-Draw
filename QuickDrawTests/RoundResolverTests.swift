//
//  RoundResolverTests.swift
//  QuickDrawTests
//

import XCTest
@testable import QuickDraw

final class RoundResolverTests: XCTestCase {

    private let resolver = RoundResolver()
    private let roundID = UUID()
    private let p1 = UUID()
    private let p2 = UUID()

    private var players: (UUID, UUID) { (p1, p2) }

    private func resolve(_ reports: [PlayerRoundReport],
                         timedOut: Bool = false) -> ResolvedRound? {
        var dict: [UUID: PlayerRoundReport] = [:]
        for r in reports { dict[r.playerID] = r }
        return resolver.resolve(roundID: roundID, players: players,
                                reports: dict, timedOut: timedOut)
    }

    // MARK: Speed

    func testPlayerOneFaster() {
        let result = resolve([.draw(playerID: p1, roundID: roundID, elapsed: 0.30),
                              .draw(playerID: p2, roundID: roundID, elapsed: 0.45)])
        XCTAssertEqual(result?.winnerID, p1)
        XCTAssertEqual(result?.reason, .fasterDraw)
        XCTAssertEqual(result?.margin ?? 0, 0.15, accuracy: 1e-9)
        XCTAssertEqual(result?.photoFinish, false)
        XCTAssertEqual(result?.times[p1], 0.30)
        XCTAssertEqual(result?.times[p2], 0.45)
    }

    func testPlayerTwoFaster() {
        let result = resolve([.draw(playerID: p1, roundID: roundID, elapsed: 0.50),
                              .draw(playerID: p2, roundID: roundID, elapsed: 0.28)])
        XCTAssertEqual(result?.winnerID, p2)
        XCTAssertEqual(result?.reason, .fasterDraw)
    }

    func testNearTieStillPicksFasterAndFlagsPhotoFinish() {
        let result = resolve([.draw(playerID: p1, roundID: roundID, elapsed: 0.3000),
                              .draw(playerID: p2, roundID: roundID, elapsed: 0.3100)])
        XCTAssertEqual(result?.winnerID, p1)
        XCTAssertEqual(result?.photoFinish, true)
    }

    func testExactTieIsDeterministic() {
        let a = resolve([.draw(playerID: p1, roundID: roundID, elapsed: 0.3),
                         .draw(playerID: p2, roundID: roundID, elapsed: 0.3)])
        let b = resolve([.draw(playerID: p2, roundID: roundID, elapsed: 0.3),
                         .draw(playerID: p1, roundID: roundID, elapsed: 0.3)])
        XCTAssertNotNil(a?.winnerID)
        XCTAssertEqual(a?.winnerID, b?.winnerID, "tie-break must not depend on report order")
        XCTAssertEqual(a?.photoFinish, true)
    }

    // MARK: False starts

    func testPlayerOneFalseStartLoses() {
        let result = resolve([.falseStart(playerID: p1, roundID: roundID),
                              .draw(playerID: p2, roundID: roundID, elapsed: 0.4)])
        XCTAssertEqual(result?.winnerID, p2)
        XCTAssertEqual(result?.reason, .opponentFalseStart)
        XCTAssertEqual(result?.falseStarters, [p1])
    }

    func testPlayerTwoFalseStartLoses() {
        let result = resolve([.draw(playerID: p1, roundID: roundID, elapsed: 0.4),
                              .falseStart(playerID: p2, roundID: roundID)])
        XCTAssertEqual(result?.winnerID, p1)
        XCTAssertEqual(result?.reason, .opponentFalseStart)
        XCTAssertEqual(result?.falseStarters, [p2])
    }

    func testBothFalseStartIsVoid() {
        let result = resolve([.falseStart(playerID: p1, roundID: roundID),
                              .falseStart(playerID: p2, roundID: roundID)])
        XCTAssertNil(result?.winnerID)
        XCTAssertEqual(result?.reason, .bothFalseStart)
        XCTAssertEqual(result?.isVoid, true)
        XCTAssertEqual(Set(result?.falseStarters ?? []), Set([p1, p2]))
    }

    func testLoneFalseStartResolvesOnTimeout() {
        // Only the offender reported; the settle window elapsed.
        let result = resolve([.falseStart(playerID: p1, roundID: roundID)],
                             timedOut: true)
        XCTAssertEqual(result?.winnerID, p2)
        XCTAssertEqual(result?.reason, .opponentFalseStart)
    }

    // MARK: Timeouts & missing data

    func testWaitsWhileAReportIsMissing() {
        let result = resolve([.draw(playerID: p1, roundID: roundID, elapsed: 0.4)])
        XCTAssertNil(result, "must not resolve early with one report and no timeout")
    }

    func testOneResultTimesOutOtherWins() {
        let result = resolve([.draw(playerID: p1, roundID: roundID, elapsed: 0.4)],
                             timedOut: true)
        XCTAssertEqual(result?.winnerID, p1)
        XCTAssertEqual(result?.reason, .opponentNoDraw)
    }

    func testNobodyDrawsIsVoid() {
        let result = resolve([.noDraw(playerID: p1, roundID: roundID),
                              .noDraw(playerID: p2, roundID: roundID)])
        XCTAssertNil(result?.winnerID)
        XCTAssertEqual(result?.reason, .noDraws)
    }

    func testNoReportsAtAllTimesOutVoid() {
        let result = resolve([], timedOut: true)
        XCTAssertNil(result?.winnerID)
        XCTAssertEqual(result?.reason, .noDraws)
    }

    // MARK: Bad data

    func testStaleRoundIDIsInvalid() {
        let stale = UUID()
        let result = resolve([.draw(playerID: p1, roundID: stale, elapsed: 0.4),
                              .draw(playerID: p2, roundID: roundID, elapsed: 0.5)])
        XCTAssertEqual(result?.reason, .invalidData)
        XCTAssertEqual(result?.isVoid, true)
    }

    func testNegativeElapsedIsInvalid() {
        let result = resolve([.draw(playerID: p1, roundID: roundID, elapsed: -0.2),
                              .draw(playerID: p2, roundID: roundID, elapsed: 0.5)])
        XCTAssertEqual(result?.reason, .invalidData)
        XCTAssertNil(result?.winnerID)
    }

    func testAbsurdlyLargeElapsedIsInvalid() {
        let result = resolve([.draw(playerID: p1, roundID: roundID, elapsed: 60),
                              .draw(playerID: p2, roundID: roundID, elapsed: 0.5)])
        XCTAssertEqual(result?.reason, .invalidData)
    }

    func testImpossiblyFastReactionCountsAsFalseStart() {
        // 15 ms is faster than any human: the player must have started moving
        // before the signal, so the honest opponent wins.
        let result = resolve([.draw(playerID: p1, roundID: roundID, elapsed: 0.015),
                              .draw(playerID: p2, roundID: roundID, elapsed: 0.42)])
        XCTAssertEqual(result?.winnerID, p2)
        XCTAssertEqual(result?.reason, .opponentFalseStart)
        XCTAssertEqual(result?.falseStarters, [p1])
    }

    func testDuplicateReportPacketDoesNotChangeOutcome() {
        // Simulates the host receiving the same report twice: the dictionary
        // keying by player makes the second write idempotent.
        var dict: [UUID: PlayerRoundReport] = [:]
        let report = PlayerRoundReport.draw(playerID: p1, roundID: roundID, elapsed: 0.4)
        dict[report.playerID] = report
        dict[report.playerID] = report
        dict[p2] = .draw(playerID: p2, roundID: roundID, elapsed: 0.5)
        let result = resolver.resolve(roundID: roundID, players: players,
                                      reports: dict, timedOut: false)
        XCTAssertEqual(result?.winnerID, p1)
    }
}
