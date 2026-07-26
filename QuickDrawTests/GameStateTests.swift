//
//  GameStateTests.swift
//  QuickDrawTests
//
//  State rules: readiness, stale-round filtering, rematch agreement,
//  calibration gating, duplicate-packet filtering.
//

import XCTest
@testable import QuickDraw

final class GameStateTests: XCTestCase {

    private let p1 = UUID()
    private let p2 = UUID()

    // MARK: Readiness

    func testRoundRequiresBothPlayersReady() {
        var gate = ReadinessGate(isConnected: true, localReady: true,
                                 opponentReady: false, motionAvailable: true)
        XCTAssertFalse(gate.canProceedToCalibration)
        gate.opponentReady = true
        XCTAssertTrue(gate.canProceedToCalibration)
    }

    func testRoundRequiresConnection() {
        let gate = ReadinessGate(isConnected: false, localReady: true,
                                 opponentReady: true, motionAvailable: true)
        XCTAssertFalse(gate.canProceedToCalibration)
    }

    func testRoundRequiresMotionAvailability() {
        let gate = ReadinessGate(isConnected: true, localReady: true,
                                 opponentReady: true, motionAvailable: false)
        XCTAssertFalse(gate.canProceedToCalibration)
    }

    // MARK: Stale rounds

    func testOldRoundMessagesAreRejected() {
        var gate = RoundGate()
        let oldRound = UUID()
        let newRound = UUID()
        gate.beginRound(oldRound)
        XCTAssertTrue(gate.allows(oldRound))
        gate.beginRound(newRound)
        XCTAssertFalse(gate.allows(oldRound), "stale round packets must be dropped")
        XCTAssertTrue(gate.allows(newRound))
    }

    func testNonRoundMessagesAlwaysPass() {
        var gate = RoundGate()
        XCTAssertTrue(gate.allows(nil))
        gate.beginRound(UUID())
        XCTAssertTrue(gate.allows(nil))
    }

    func testNoActiveRoundRejectsRoundMessages() {
        let gate = RoundGate()
        XCTAssertFalse(gate.allows(UUID()))
    }

    // MARK: Rematch

    func testRematchRequiresBothPlayers() {
        var rematch = RematchCoordinator()
        rematch.vote(playerID: p1)
        XCTAssertFalse(rematch.bothAgreed(players: (p1, p2)))
        rematch.vote(playerID: p2)
        XCTAssertTrue(rematch.bothAgreed(players: (p1, p2)))
    }

    func testRematchVoteFromStrangerDoesNotCount() {
        var rematch = RematchCoordinator()
        rematch.vote(playerID: p1)
        rematch.vote(playerID: UUID())  // not one of the current players
        XCTAssertFalse(rematch.bothAgreed(players: (p1, p2)))
    }

    func testRematchResetsBetweenRounds() {
        var rematch = RematchCoordinator()
        rematch.vote(playerID: p1)
        rematch.vote(playerID: p2)
        rematch.reset()
        XCTAssertFalse(rematch.bothAgreed(players: (p1, p2)))
    }

    // MARK: Calibration gating

    func testGameplayRequiresBothCalibrations() {
        var gate = CalibrationGate()
        gate.markComplete(playerID: p1)
        XCTAssertFalse(gate.bothCalibrated(players: (p1, p2)))
        gate.markComplete(playerID: p2)
        XCTAssertTrue(gate.bothCalibrated(players: (p1, p2)))
    }

    func testCalibrationSessionRejectsMovement() {
        let session = CalibrationSession(duration: 1.0)
        for sample in MotionSequenceFactory.shake(from: 0, duration: 1.2) {
            session.add(sample)
        }
        XCTAssertTrue(session.isComplete)
        XCTAssertEqual(session.finish(), .failedTooMuchMovement)
    }

    func testCalibrationSessionRejectsHorizontalPhone() {
        let session = CalibrationSession(duration: 1.0)
        for offset in stride(from: 0.0, to: 1.2, by: 0.01) {
            session.add(MotionSample(timestamp: offset,
                                     gravity: Vector3(x: 0, y: -0.1, z: -0.99),
                                     userAcceleration: .zero,
                                     rotationRate: .zero,
                                     pitch: 1.4))
        }
        XCTAssertEqual(session.finish(), .failedNotUpright)
    }

    func testCalibrationSessionSucceedsWhenStill() {
        let session = CalibrationSession(duration: 1.0)
        for sample in MotionSequenceFactory.still(from: 0, duration: 1.2) {
            session.add(sample)
        }
        guard case .success(let data) = session.finish() else {
            return XCTFail("expected success")
        }
        XCTAssertLessThan(data.restingGravity.angle(to: Vector3(x: 0, y: -1, z: 0)), 0.05)
        XCTAssertLessThan(data.gravityNoise, GameTuning.calibrationMaxGravityNoise)
    }

    // MARK: Duplicate filtering

    func testDuplicateEnvelopesAreDropped() {
        var filter = DuplicateFilter()
        let first = MessageEnvelope(seq: 1, message: .beginCalibration)
        let second = MessageEnvelope(seq: 2, message: .beginCalibration)
        XCTAssertTrue(filter.accept(first))
        XCTAssertFalse(filter.accept(first), "replayed packet must be dropped")
        XCTAssertTrue(filter.accept(second))
        XCTAssertFalse(filter.accept(first), "stale packet must be dropped")
    }

    // MARK: Clock sync

    func testClockSyncPrefersLowestRTT() {
        let estimator = ClockSyncEstimator()
        // Noisy exchange: 200 ms RTT, offset polluted by asymmetric delay.
        estimator.addExchange(pingSentAt: 10.0, hostTime: 110.15, pongReceivedAt: 10.2)
        // Clean exchange: 10 ms RTT, true offset 100.
        estimator.addExchange(pingSentAt: 11.0, hostTime: 111.005, pongReceivedAt: 11.01)
        XCTAssertEqual(estimator.offset, 100.0, accuracy: 1e-9)
        XCTAssertEqual(estimator.estimatedError ?? 0, 0.005, accuracy: 1e-9)
        // Converting a host time into local time undoes the offset.
        XCTAssertEqual(estimator.localTime(forHostTime: 150), 50, accuracy: 1e-9)
    }

    func testClockSyncDefaultsToZeroOffset() {
        let estimator = ClockSyncEstimator()
        XCTAssertEqual(estimator.offset, 0)
        XCTAssertEqual(estimator.localTime(forHostTime: 42), 42)
    }

    // MARK: Round plan

    func testRoundPlanTimelineOrdering() {
        let plan = RoundPlan.schedule(roundID: UUID(), now: 1000, suspenseDelay: 2.0)
        XCTAssertGreaterThan(plan.readyAt, 1000)
        XCTAssertGreaterThan(plan.steadyAt, plan.readyAt)
        XCTAssertEqual(plan.drawAt - plan.steadyAt, 2.0, accuracy: 1e-9)
    }
}
