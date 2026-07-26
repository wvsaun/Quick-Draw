//
//  HapticService.swift
//  QuickDraw
//
//  Restrained haptic cues built on the UIKit feedback generators.
//

import Foundation
import UIKit

final class HapticService {

    /// Set from SettingsStore; when false every call is a no-op.
    var isEnabled = true

    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notification = UINotificationFeedbackGenerator()

    /// Warm up the taptic engine right before the countdown so the DRAW
    /// haptic fires with minimal latency.
    func prepareForRound() {
        guard isEnabled else { return }
        impactHeavy.prepare()
        impactLight.prepare()
        notification.prepare()
    }

    func buttonTap() { guard isEnabled else { return }; impactLight.impactOccurred(intensity: 0.6) }
    func playerConnected() { guard isEnabled else { return }; notification.notificationOccurred(.success) }
    func readyCue() { guard isEnabled else { return }; impactLight.impactOccurred() }
    func countdownTick() { guard isEnabled else { return }; impactLight.impactOccurred() }
    func drawSignal() { guard isEnabled else { return }; impactHeavy.impactOccurred(intensity: 1.0) }
    func falseStart() { guard isEnabled else { return }; notification.notificationOccurred(.error) }
    func win() { guard isEnabled else { return }; notification.notificationOccurred(.success) }
    func lose() { guard isEnabled else { return }; notification.notificationOccurred(.warning) }
}
