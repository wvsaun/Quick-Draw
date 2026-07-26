//
//  NetworkMessageTests.swift
//  QuickDrawTests
//
//  Every message type must round-trip through the wire encoding.
//

import XCTest
@testable import QuickDraw

final class NetworkMessageTests: XCTestCase {

    private func roundTrip(_ message: NetworkMessage,
                           file: StaticString = #filePath,
                           line: UInt = #line) {
        do {
            let envelope = MessageEnvelope(seq: 7, message: message)
            let data = try envelope.encoded()
            let decoded = try MessageEnvelope.decode(data)
            XCTAssertEqual(decoded, envelope, file: file, line: line)
        } catch {
            XCTFail("round-trip failed for \(message): \(error)", file: file, line: line)
        }
    }

    func testAllMessageTypesRoundTrip() {
        let playerID = UUID()
        let opponentID = UUID()
        let roundID = UUID()
        let profile = PlayerProfile(id: playerID, displayName: "Dusty")
        let plan = RoundPlan.schedule(roundID: roundID, now: 123.456, suspenseDelay: 1.75)
        let report = PlayerRoundReport.draw(playerID: playerID, roundID: roundID,
                                            elapsed: 0.312, peakRotation: 5.5, tiltAngle: 1.2)
        let result = ResolvedRound(roundID: roundID, winnerID: playerID,
                                   reason: .fasterDraw,
                                   times: [playerID: 0.312, opponentID: 0.401],
                                   falseStarters: [], margin: 0.089, photoFinish: false)

        roundTrip(.hello(profile: profile))
        roundTrip(.readyChanged(playerID: playerID, isReady: true))
        roundTrip(.beginCalibration)
        roundTrip(.calibrationDone(playerID: playerID))
        roundTrip(.beginPositioning(roundID: roundID))
        roundTrip(.positionConfirmed(playerID: playerID, roundID: roundID))
        roundTrip(.roundScheduled(plan: plan))
        roundTrip(.report(report))
        roundTrip(.roundResult(result))
        roundTrip(.rematchRequest(playerID: playerID, afterRoundID: roundID))
        roundTrip(.leaveGame(playerID: playerID))
        roundTrip(.syncPing(id: 3, senderTime: 99.5))
        roundTrip(.syncPong(id: 3, senderTime: 99.5, hostTime: 205.25))
    }

    func testFalseStartAndNoDrawReportsRoundTrip() {
        let playerID = UUID()
        let roundID = UUID()
        roundTrip(.report(.falseStart(playerID: playerID, roundID: roundID)))
        roundTrip(.report(.noDraw(playerID: playerID, roundID: roundID)))
    }

    func testVoidResultRoundTrips() {
        let roundID = UUID()
        let result = ResolvedRound(roundID: roundID, winnerID: nil,
                                   reason: .bothFalseStart, times: [:],
                                   falseStarters: [UUID(), UUID()],
                                   margin: nil, photoFinish: false)
        roundTrip(.roundResult(result))
    }

    func testRoundIDExtraction() {
        let roundID = UUID()
        XCTAssertEqual(NetworkMessage.beginPositioning(roundID: roundID).roundID, roundID)
        XCTAssertEqual(NetworkMessage.report(.noDraw(playerID: UUID(), roundID: roundID)).roundID,
                       roundID)
        XCTAssertNil(NetworkMessage.beginCalibration.roundID)
        XCTAssertNil(NetworkMessage.hello(profile: PlayerProfile(id: UUID(),
                                                                 displayName: "x")).roundID)
    }

    func testCorruptDataFailsCleanly() {
        XCTAssertThrowsError(try MessageEnvelope.decode(Data("not json".utf8)))
    }
}
