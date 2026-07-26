//
//  QuickDrawApp.swift
//  QuickDraw
//

import SwiftUI

@main
struct QuickDrawApp: App {
    @StateObject private var settings: SettingsStore
    @StateObject private var stats: StatsStore
    @StateObject private var game: GameViewModel

    init() {
        let settings = SettingsStore()
        let stats = StatsStore()
        _settings = StateObject(wrappedValue: settings)
        _stats = StateObject(wrappedValue: stats)
        _game = StateObject(wrappedValue: GameViewModel(settings: settings, stats: stats))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(settings)
                .environmentObject(stats)
                .environmentObject(game)
        }
    }
}
