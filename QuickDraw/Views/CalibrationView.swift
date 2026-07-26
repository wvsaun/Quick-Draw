//
//  CalibrationView.swift
//  QuickDraw
//

import SwiftUI

struct CalibrationView: View {
    @EnvironmentObject var game: GameViewModel

    var body: some View {
        ZStack {
            WesternBackground()
            VStack(spacing: 22) {
                Spacer(minLength: 24)
                Text("CALIBRATION")
                    .westernTitle(size: 32)
                    .foregroundStyle(Color.qdSurface)

                if game.localCalibrated {
                    ParchmentCard {
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(Color.qdWin)
                                .accessibilityHidden(true)
                            Text("Calibration complete")
                                .font(.headline)
                                .foregroundStyle(Color.qdInk)
                            Text(game.opponentCalibrated
                                 ? "Opponent ready — starting…"
                                 : "Waiting for your opponent to finish calibrating…")
                                .font(.subheadline)
                                .foregroundStyle(Color.qdInk.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.horizontal, 32)
                } else {
                    ParchmentCard {
                        VStack(alignment: .leading, spacing: 10) {
                            instruction(1, "Hold the phone securely in one hand.")
                            instruction(2, "Place it vertically near your hip, like a holster.")
                            instruction(3, "Keep the screen facing outward, away from your body.")
                            instruction(4, "Hold still while we learn your resting stance.")
                            instruction(5, "You'll raise the phone forward when the duel starts — practice the motion once, gently.")
                        }
                    }
                    .padding(.horizontal, 32)

                    if game.calibrationRunning {
                        VStack(spacing: 10) {
                            ProgressView(value: game.calibrationProgress)
                                .tint(Color.qdGold)
                                .padding(.horizontal, 48)
                            Text("Hold still…")
                                .font(.headline)
                                .foregroundStyle(Color.qdGold)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Calibrating, hold still")
                    } else {
                        if let failure = game.calibrationFailure {
                            Text(failure)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.qdAmber)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        Button(game.calibrationFailure == nil ? "Hold Still — Start" : "Try Again") {
                            game.startCalibrationCapture()
                        }
                        .buttonStyle(WesternButtonStyle())
                        .padding(.horizontal, 32)
                        .accessibilityHint("Captures your resting stance for about two seconds")
                    }
                }

                Spacer()
                Button("Leave Game") { game.leaveGame() }
                    .buttonStyle(WesternButtonStyle(prominent: false))
                    .padding(.horizontal, 32)
                    .padding(.bottom, 20)
            }
        }
    }

    private func instruction(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(n).")
                .font(.system(.body, design: .serif).weight(.black))
                .foregroundStyle(Color.qdCopper)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Color.qdInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
