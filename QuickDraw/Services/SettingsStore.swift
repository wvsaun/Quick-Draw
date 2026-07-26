//
//  SettingsStore.swift
//  QuickDraw
//
//  UserDefaults-backed user preferences. Only lightweight, local,
//  non-personal data is ever persisted (see the in-app privacy note).
//

import Foundation

final class SettingsStore: ObservableObject {

    private enum Keys {
        static let displayName = "settings.displayName"
        static let soundEnabled = "settings.soundEnabled"
        static let hapticsEnabled = "settings.hapticsEnabled"
        static let reduceMotion = "settings.reduceMotion"
        static let sensitivity = "settings.sensitivity"
        static let diagnostics = "settings.diagnostics"
        static let safetyAcknowledged = "settings.safetyAcknowledged"
        static let playerID = "settings.playerID"
    }

    private let defaults: UserDefaults

    /// Stable per-install player identity (a random UUID — no personal data).
    let playerID: UUID

    @Published var displayName: String {
        didSet { defaults.set(displayName, forKey: Keys.displayName) }
    }
    @Published var soundEnabled: Bool {
        didSet { defaults.set(soundEnabled, forKey: Keys.soundEnabled) }
    }
    @Published var hapticsEnabled: Bool {
        didSet { defaults.set(hapticsEnabled, forKey: Keys.hapticsEnabled) }
    }
    /// App-level "reduce motion" preference; the system accessibility setting
    /// is additionally respected wherever animations run.
    @Published var reduceMotion: Bool {
        didSet { defaults.set(reduceMotion, forKey: Keys.reduceMotion) }
    }
    @Published var sensitivity: MotionSensitivity {
        didSet { defaults.set(sensitivity.rawValue, forKey: Keys.sensitivity) }
    }
    /// Debug-build diagnostics overlay toggle.
    @Published var diagnosticsEnabled: Bool {
        didSet { defaults.set(diagnosticsEnabled, forKey: Keys.diagnostics) }
    }
    @Published var safetyAcknowledged: Bool {
        didSet { defaults.set(safetyAcknowledged, forKey: Keys.safetyAcknowledged) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let stored = defaults.string(forKey: Keys.playerID),
           let id = UUID(uuidString: stored) {
            playerID = id
        } else {
            let id = UUID()
            defaults.set(id.uuidString, forKey: Keys.playerID)
            playerID = id
        }

        let storedName = defaults.string(forKey: Keys.displayName)
        displayName = storedName?.isEmpty == false
            ? storedName!
            : "Gunslinger \(Int.random(in: 10...99))"
        soundEnabled = defaults.object(forKey: Keys.soundEnabled) as? Bool ?? true
        hapticsEnabled = defaults.object(forKey: Keys.hapticsEnabled) as? Bool ?? true
        reduceMotion = defaults.bool(forKey: Keys.reduceMotion)
        sensitivity = MotionSensitivity(rawValue: defaults.string(forKey: Keys.sensitivity) ?? "")
            ?? .standard
        diagnosticsEnabled = defaults.bool(forKey: Keys.diagnostics)
        safetyAcknowledged = defaults.bool(forKey: Keys.safetyAcknowledged)
    }

    var profile: PlayerProfile {
        PlayerProfile(id: playerID, displayName: displayName)
    }
}
