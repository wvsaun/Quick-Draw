//
//  MotionService.swift
//  QuickDraw
//
//  Thin CMMotionManager wrapper behind a protocol so the detector pipeline
//  can be driven by synthetic samples in tests and in the simulator.
//
//  Sampling runs at ~100 Hz (≈10 ms timing resolution — appropriate for a
//  reaction game) but ONLY between calibration start and round end, so the
//  gyroscope is not burning battery on menu screens.
//

import Foundation
import CoreMotion

protocol MotionSource: AnyObject {
    var isAvailable: Bool { get }
    /// Actual sampling interval achieved (for diagnostics).
    var updateInterval: TimeInterval { get }
    /// Called on an arbitrary internal queue for every sample. The consumer
    /// is responsible for any main-thread hops.
    var onSample: ((MotionSample) -> Void)? { get set }
    func start()
    func stop()
}

final class MotionService: MotionSource {

    private let manager = CMMotionManager()
    private let queue: OperationQueue = {
        let q = OperationQueue()
        q.maxConcurrentOperationCount = 1
        q.qualityOfService = .userInteractive
        return q
    }()

    var onSample: ((MotionSample) -> Void)?

    var isAvailable: Bool { manager.isDeviceMotionAvailable }
    var updateInterval: TimeInterval { manager.deviceMotionUpdateInterval }

    private(set) var isRunning = false

    func start() {
        guard !isRunning, manager.isDeviceMotionAvailable else { return }
        isRunning = true
        manager.deviceMotionUpdateInterval = 1.0 / GameTuning.motionUpdateHz
        // xArbitraryZVertical: cheap reference frame, no compass calibration
        // prompts; we only need gravity/rotation/acceleration, not heading.
        manager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: queue) { [weak self] motion, error in
            guard let self, let motion else {
                if let error {
                    Log.motion.error("Motion error: \(error.localizedDescription, privacy: .public)")
                }
                return
            }
            let sample = MotionSample(
                timestamp: motion.timestamp,
                gravity: Vector3(x: motion.gravity.x,
                                 y: motion.gravity.y,
                                 z: motion.gravity.z),
                userAcceleration: Vector3(x: motion.userAcceleration.x,
                                          y: motion.userAcceleration.y,
                                          z: motion.userAcceleration.z),
                rotationRate: Vector3(x: motion.rotationRate.x,
                                      y: motion.rotationRate.y,
                                      z: motion.rotationRate.z),
                pitch: motion.attitude.pitch)
            self.onSample?(sample)
        }
        Log.motion.info("Device motion started at \(GameTuning.motionUpdateHz, privacy: .public) Hz")
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        manager.stopDeviceMotionUpdates()
        Log.motion.info("Device motion stopped")
    }
}
