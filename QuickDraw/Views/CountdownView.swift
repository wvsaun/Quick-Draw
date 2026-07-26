//
//  CountdownView.swift
//  QuickDraw
//
//  Covers .countdown, .armed and .resolving. The DRAW state is communicated
//  by text + color + sound + haptic simultaneously, never color alone.
//

import SwiftUI

struct CountdownView: View {
    @EnvironmentObject var game: GameViewModel
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @EnvironmentObject var settings: SettingsStore

    private var reduceMotion: Bool { systemReduceMotion || settings.reduceMotion }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()
            VStack(spacing: 30) {
                Spacer()
                if game.localFalseStarted {
                    bigText("FALSE START", color: .white)
                    Text("You moved before the signal.")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.85))
                } else {
                    switch stage {
                    case .waiting:
                        bigText("…", color: Color.qdSurface)
                    case .ready:
                        bigText("READY", color: Color.qdSurface)
                    case .steady:
                        bigText("STEADY", color: Color.qdGold)
                    case .draw:
                        bigText("DRAW!", color: .white)
                            .scaleEffect(reduceMotion ? 1.0 : 1.08)
                            .animation(reduceMotion ? nil
                                       : .spring(duration: 0.2), value: stage)
                    }
                    if game.phase == .resolving {
                        VStack(spacing: 8) {
                            if let elapsed = game.localDrawElapsed {
                                Text("Your draw: \(elapsed.reactionString)")
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(.white)
                            }
                            ProgressView().tint(.white)
                            Text("Waiting for the verdict…")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    } else if stage != .draw {
                        Text("Hold at your hip. Draw on the signal.")
                            .font(.subheadline)
                            .foregroundStyle(Color.qdSurface.opacity(0.6))
                    }
                }
                Spacer()

                #if DEBUG
                debugControls
                #endif
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityStageLabel)
    }

    private var stage: CountdownStage { game.countdownStage }

    private var backgroundColor: Color {
        if game.localFalseStarted { return .qdLose }
        switch stage {
        case .draw: return .qdCopper
        default: return .qdBackground
        }
    }

    private func bigText(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 64, weight: .black, design: .serif))
            .kerning(3)
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .foregroundStyle(color)
            .padding(.horizontal, 16)
    }

    private var accessibilityStageLabel: String {
        if game.localFalseStarted { return "False start. You moved before the signal." }
        switch stage {
        case .waiting: return "Get ready"
        case .ready: return "Ready"
        case .steady: return "Steady"
        case .draw: return "Draw now!"
        }
    }

    #if DEBUG
    @ViewBuilder
    private var debugControls: some View {
        if game.phase == .countdown || game.phase == .armed {
            HStack(spacing: 10) {
                Button("Sim Draw") { game.debugTriggerDraw() }
                Button("Sim False Start") { game.debugTriggerFalseStart() }
                Button("Drop Link") { game.debugForceDisconnect() }
            }
            .font(.caption.weight(.bold))
            .buttonStyle(.bordered)
            .tint(Color.qdGold)
            .padding(.bottom, 12)
        }
    }
    #endif
}
