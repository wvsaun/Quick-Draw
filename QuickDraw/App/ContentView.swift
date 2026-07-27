//
//  ContentView.swift
//  QuickDraw
//
//  The app's content root: builds the shared stores and game view model,
//  publishes them to the environment, and hands off to RootView for phase
//  routing. Keeping the wiring in one place lets Xcode previews stand the
//  whole app up on an iPhone canvas with fake dependencies.
//

import SwiftUI

/// The object graph ContentView renders. `live()` builds the real thing;
/// previews substitute stubs (see `preview(...)` below).
final class GameEnvironment: ObservableObject {
    let settings: SettingsStore
    let stats: StatsStore
    let game: GameViewModel

    init(settings: SettingsStore, stats: StatsStore, game: GameViewModel) {
        self.settings = settings
        self.stats = stats
        self.game = game
    }

    static func live() -> GameEnvironment {
        let settings = SettingsStore()
        let stats = StatsStore()
        return GameEnvironment(settings: settings,
                               stats: stats,
                               game: GameViewModel(settings: settings, stats: stats))
    }
}

struct ContentView: View {
    @StateObject private var environment: GameEnvironment

    /// The graph is built lazily — SwiftUI only evaluates the autoclosure the
    /// first time this view is installed, so rebuilds never spin up a second
    /// motion pipeline or transport.
    init(environment: @autoclosure @escaping () -> GameEnvironment = .live()) {
        _environment = StateObject(wrappedValue: environment())
    }

    var body: some View {
        RootView()
            .environmentObject(environment.settings)
            .environmentObject(environment.stats)
            .environmentObject(environment.game)
    }
}

// MARK: - Previews

#if DEBUG
extension GameEnvironment {
    /// A throwaway graph for previews: in-memory defaults (the real
    /// UserDefaults is never touched), the scripted opponent transport, and a
    /// motion source that stays silent — the canvas has no sensors.
    static func preview(safetyAcknowledged: Bool = true) -> GameEnvironment {
        let defaults = UserDefaults(suiteName: "preview.\(UUID().uuidString)") ?? .standard
        let settings = SettingsStore(defaults: defaults)
        let stats = StatsStore(defaults: defaults)
        settings.safetyAcknowledged = safetyAcknowledged
        return GameEnvironment(settings: settings,
                               stats: stats,
                               game: GameViewModel(settings: settings,
                                                   stats: stats,
                                                   link: SimulatedPeerLink(),
                                                   motion: InertMotionSource()))
    }
}

/// Stand-in for `MotionService` in previews: reports itself available so the
/// UI renders its normal state instead of the no-sensor error, but never
/// produces a sample.
final class InertMotionSource: MotionSource {
    let isAvailable = true
    let updateInterval: TimeInterval = 1.0 / 100.0
    var onSample: ((MotionSample) -> Void)?
    func start() {}
    func stop() {}
}

#Preview("Home") {
    ContentView(environment: .preview())
}

#Preview("First launch — safety notice") {
    ContentView(environment: .preview(safetyAcknowledged: false))
}
#endif
