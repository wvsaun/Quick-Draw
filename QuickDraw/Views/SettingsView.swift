//
//  SettingsView.swift
//  QuickDraw
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var stats: StatsStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Player") {
                    TextField("Display name", text: $settings.displayName)
                        .textInputAutocapitalization(.words)
                        .accessibilityLabel("Player display name")
                }

                Section("Feedback") {
                    Toggle("Sound effects", isOn: $settings.soundEnabled)
                    Toggle("Haptics", isOn: $settings.hapticsEnabled)
                    Toggle("Reduce motion", isOn: $settings.reduceMotion)
                }

                Section {
                    Picker("Motion sensitivity", selection: $settings.sensitivity) {
                        Text("Low").tag(MotionSensitivity.low)
                        Text("Standard").tag(MotionSensitivity.standard)
                        Text("High").tag(MotionSensitivity.high)
                    }
                } header: {
                    Text("Draw Detection")
                } footer: {
                    Text("High makes draws easier to trigger; Low requires a more decisive motion. Standard suits most players.")
                }

                Section("Your Record") {
                    LabeledContent("Matches", value: "\(stats.stats.matchesPlayed)")
                    LabeledContent("Wins", value: "\(stats.stats.wins)")
                    LabeledContent("Losses", value: "\(stats.stats.losses)")
                    LabeledContent("False starts", value: "\(stats.stats.falseStarts)")
                    if let fastest = stats.stats.fastestDraw {
                        LabeledContent("Fastest draw", value: fastest.reactionString)
                    }
                    if let average = stats.stats.averageDraw {
                        LabeledContent("Average draw", value: average.reactionString)
                    }
                    Button("Reset statistics", role: .destructive) {
                        stats.resetStats()
                    }
                }

                #if DEBUG || TESTFLIGHT_TOOLS
                Section {
                    Toggle("Developer diagnostics", isOn: $settings.diagnosticsEnabled)
                } footer: {
                    Text("Shows a live overlay with motion values, detector state, and sync data. Development builds only.")
                }
                #endif

                Section("Privacy") {
                    Text("Quick Draw runs entirely on your devices. Nearby connectivity and motion data are used only to operate the game — nothing is collected, stored beyond your settings and match record, or sent anywhere else.")
                        .font(.footnote)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
