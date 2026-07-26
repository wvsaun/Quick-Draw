//
//  DebugMenuView.swift
//  QuickDraw
//
//  Development-only tools: configure the scripted opponent and start a
//  practice match that exercises the full game flow without a second device.
//  Compiled in DEBUG and TESTFLIGHT_TOOLS builds only.
//

#if DEBUG || TESTFLIGHT_TOOLS
import SwiftUI

struct DebugMenuView: View {
    @EnvironmentObject var game: GameViewModel
    @ObservedObject var options = DebugSimulationOptions.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Opponent behaviour", selection: $options.script) {
                        Text("Random (0.25–0.60 s)").tag(DebugSimulationOptions.OpponentScript.random)
                        Text("Always fast — you lose").tag(DebugSimulationOptions.OpponentScript.alwaysFast)
                        Text("Always slow — you win").tag(DebugSimulationOptions.OpponentScript.alwaysSlow)
                        Text("False starts").tag(DebugSimulationOptions.OpponentScript.falseStart)
                        Text("Never draws").tag(DebugSimulationOptions.OpponentScript.noDraw)
                    }
                    .pickerStyle(.inline)
                } header: {
                    Text("Simulated Opponent")
                } footer: {
                    Text("\"Tin Can Tex\" runs the full message protocol through the same code paths as a real peer.")
                }

                Section("Artificial latency") {
                    Slider(value: $options.latency, in: 0...0.5, step: 0.025)
                    LabeledContent("One-way delay",
                                   value: String(format: "%.0f ms", options.latency * 1000))
                }

                Section {
                    Button("Start Practice Match") {
                        dismiss()
                        game.startPracticeVsSimulatedOpponent()
                    }
                } footer: {
                    Text("During the countdown you'll get buttons to simulate your own draw, a false start, or a dropped connection — needed in the simulator, where Core Motion is unavailable.")
                }
            }
            .navigationTitle("Debug Tools")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
#endif
