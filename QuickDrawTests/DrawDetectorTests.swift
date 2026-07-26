//
//  DrawDetectorTests.swift
//  QuickDrawTests
//

import XCTest
@testable import QuickDraw

final class DrawDetectorTests: XCTestCase {

    private var detector: DrawDetector!
    private let t0: TimeInterval = 100.0   // arbitrary uptime origin

    override func setUp() {
        super.setUp()
        detector = DrawDetector()
        detector.setCalibration(MotionSequenceFactory.calibration)
    }

    /// Feed samples; collect every emitted event.
    @discardableResult
    private func feed(_ samples: [MotionSample]) -> [DrawDetectionEvent] {
        samples.compactMap { detector.process($0) }
    }

    private func containsDraw(_ events: [DrawDetectionEvent]) -> Bool {
        events.contains { if case .drawConfirmed = $0 { return true }; return false }
    }

    private func containsFalseStart(_ events: [DrawDetectionEvent]) -> Bool {
        events.contains { if case .falseStart = $0 { return true }; return false }
    }

    // MARK: Stillness & noise

    func testPhoneRemainsStillProducesNothing() {
        detector.arm(at: t0, signalAt: t0 + 2)
        let events = feed(MotionSequenceFactory.still(from: t0, duration: 5))
        XCTAssertFalse(containsDraw(events))
        XCTAssertFalse(containsFalseStart(events))
        XCTAssertEqual(detector.state, .holstered)
    }

    func testSingleNoisySampleDoesNotStartMovement() {
        detector.arm(at: t0, signalAt: t0 + 2)
        var samples = MotionSequenceFactory.still(from: t0, duration: 0.5)
        // One wild sample in the middle (sensor glitch).
        samples[25] = MotionSample(timestamp: samples[25].timestamp,
                                   gravity: Vector3(x: 0.3, y: -0.9, z: 0.3),
                                   userAcceleration: Vector3(x: 2, y: 2, z: 2),
                                   rotationRate: Vector3(x: 8, y: 8, z: 8),
                                   pitch: 0.4)
        let events = feed(samples)
        XCTAssertFalse(containsDraw(events))
        XCTAssertFalse(containsFalseStart(events))
    }

    func testSmallWristAdjustmentReturnsToHolster() {
        detector.arm(at: t0, signalAt: t0 + 10)
        let events = feed(MotionSequenceFactory.wristAdjust(from: t0 + 0.5))
        XCTAssertFalse(containsDraw(events))
        XCTAssertFalse(containsFalseStart(events))
        XCTAssertEqual(detector.state, .holstered)
    }

    func testRandomShakingIsNotADraw() {
        // Signal already passed: any confirmed draw would count, so shaking
        // must not confirm.
        detector.arm(at: t0, signalAt: t0 + 0.1)
        let events = feed(MotionSequenceFactory.shake(from: t0 + 0.2))
        XCTAssertFalse(containsDraw(events))
        XCTAssertFalse(containsFalseStart(events))
    }

    // MARK: Valid draws

    func testValidFastDrawIsConfirmedAfterSignal() {
        let signal = t0 + 1
        detector.arm(at: t0, signalAt: signal)
        feed(MotionSequenceFactory.still(from: t0, duration: 1.0))
        let events = feed(MotionSequenceFactory.draw(from: signal + 0.05, duration: 0.25))
        XCTAssertTrue(containsDraw(events))
        guard case .drawConfirmed(let at, let peak, let tilt)? =
                events.last(where: { if case .drawConfirmed = $0 { return true }; return false })
        else { return XCTFail("missing drawConfirmed payload") }
        XCTAssertGreaterThan(at, signal)
        XCTAssertLessThan(at - signal, 0.5)
        XCTAssertGreaterThan(peak, 2.0)
        XCTAssertGreaterThan(tilt, 0.9)
        XCTAssertEqual(detector.state, .drawConfirmed)
    }

    func testValidSlowerControlledDrawIsConfirmed() {
        let signal = t0 + 1
        detector.arm(at: t0, signalAt: signal)
        feed(MotionSequenceFactory.still(from: t0, duration: 1.0))
        let events = feed(MotionSequenceFactory.draw(from: signal + 0.1,
                                                     duration: 0.6,
                                                     peakRotation: 3.5))
        XCTAssertTrue(containsDraw(events))
    }

    // MARK: Early movement / false starts

    func testEarlyDrawIsFalseStart() {
        let signal = t0 + 5
        detector.arm(at: t0, signalAt: signal)
        feed(MotionSequenceFactory.still(from: t0, duration: 0.5))
        // Full draw two seconds before the signal.
        let events = feed(MotionSequenceFactory.draw(from: t0 + 0.5, duration: 0.25))
        XCTAssertTrue(containsFalseStart(events))
        XCTAssertFalse(containsDraw(events))
    }

    func testSlowPreSignalLiftIsFalseStartNotDraw() {
        let signal = t0 + 10
        detector.arm(at: t0, signalAt: signal)
        let events = feed(MotionSequenceFactory.slowLift(from: t0 + 0.2))
        XCTAssertTrue(containsFalseStart(events))
        XCTAssertFalse(containsDraw(events))
    }

    func testSamplesBeforeArmTimeAreIgnored() {
        detector.arm(at: t0 + 10, signalAt: t0 + 12)
        // A full draw BEFORE the arm moment must not register at all.
        let events = feed(MotionSequenceFactory.draw(from: t0, duration: 0.25))
        XCTAssertTrue(events.isEmpty)
        XCTAssertEqual(detector.state, .holstered)
    }

    // MARK: Direction & reset

    func testWrongDirectionMovementDoesNotConfirm() {
        let signal = t0 + 0.1
        detector.arm(at: t0, signalAt: signal)
        var events = feed(MotionSequenceFactory.wrongDirection(from: signal + 0.1))
        events += feed(MotionSequenceFactory.still(from: signal + 0.45, duration: 1.5))
        XCTAssertFalse(containsDraw(events))
    }

    func testDetectorResetClearsState() {
        let signal = t0 + 1
        detector.arm(at: signal - 1, signalAt: signal)
        feed(MotionSequenceFactory.draw(from: signal + 0.05))
        XCTAssertEqual(detector.state, .drawConfirmed)
        detector.reset()
        XCTAssertEqual(detector.state, .idle)
        // After reset (unarmed) nothing is processed.
        let events = feed(MotionSequenceFactory.draw(from: signal + 2))
        XCTAssertTrue(events.isEmpty)
    }

    func testDuplicateDetectionIsSuppressed() {
        let signal = t0 + 1
        detector.arm(at: t0, signalAt: signal)
        feed(MotionSequenceFactory.still(from: t0, duration: 1.0))
        let first = feed(MotionSequenceFactory.draw(from: signal + 0.05, duration: 0.25))
        XCTAssertTrue(containsDraw(first))
        // Continue feeding an entire second draw without re-arming: latched.
        let second = feed(MotionSequenceFactory.draw(from: signal + 1.0, duration: 0.25))
        XCTAssertTrue(second.isEmpty)
    }

    func testFalseStartLatchesUntilRearm() {
        let signal = t0 + 5
        detector.arm(at: t0, signalAt: signal)
        let first = feed(MotionSequenceFactory.draw(from: t0 + 0.3, duration: 0.25))
        XCTAssertTrue(containsFalseStart(first))
        // A later, post-signal draw in the same arm cycle must not emit.
        let second = feed(MotionSequenceFactory.draw(from: signal + 0.5, duration: 0.25))
        XCTAssertTrue(second.isEmpty)
        // Re-arming allows the next round to work normally.
        detector.arm(at: signal + 2, signalAt: signal + 3)
        feed(MotionSequenceFactory.still(from: signal + 2, duration: 1.0))
        let third = feed(MotionSequenceFactory.draw(from: signal + 3.1, duration: 0.25))
        XCTAssertTrue(containsDraw(third))
    }

    func testSensitivityScalingChangesThresholds() {
        let low = DrawDetectorConfiguration.forSensitivity(.low)
        let standard = DrawDetectorConfiguration.forSensitivity(.standard)
        let high = DrawDetectorConfiguration.forSensitivity(.high)
        XCTAssertGreaterThan(low.confirmTiltAngle, standard.confirmTiltAngle)
        XCTAssertLessThan(high.confirmTiltAngle, standard.confirmTiltAngle)
    }
}
