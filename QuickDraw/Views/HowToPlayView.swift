//
//  HowToPlayView.swift
//  QuickDraw
//

import SwiftUI

struct HowToPlayView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            WesternBackground()
            VStack(spacing: 16) {
                Text("HOW TO PLAY")
                    .westernTitle(size: 30)
                    .foregroundStyle(Color.qdSurface)
                    .padding(.top, 24)

                ScrollView {
                    ParchmentCard {
                        VStack(alignment: .leading, spacing: 14) {
                            step("1", "Connect", "One player hosts, the other joins. Both phones must be near each other — no internet needed.")
                            step("2", "Ready up", "Both duelists mark themselves ready in the lobby.")
                            step("3", "Calibrate", "Hold your phone vertically at your hip, screen facing outward, and hold still for a moment.")
                            step("4", "Holster", "Return the phone to your hip and confirm you're in position.")
                            step("5", "The countdown", "READY… STEADY… then, after a suspenseful pause — DRAW!")
                            step("6", "Draw!", "On the signal, quickly raise your phone to point forward. First valid draw wins. Move before the signal and you false-start — and lose the round.")
                        }
                    }
                    .padding(.horizontal, 24)

                    Text("The suspense pause is random every round — don't guess, react.")
                        .font(.footnote.italic())
                        .foregroundStyle(Color.qdGold)
                        .padding(.top, 10)
                }

                Button("Got It") { dismiss() }
                    .buttonStyle(WesternButtonStyle())
                    .padding(.horizontal, 32)
                    .padding(.bottom, 24)
            }
        }
    }

    private func step(_ n: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(n)
                .font(.system(.title2, design: .serif).weight(.black))
                .foregroundStyle(Color.qdCopper)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.qdInk)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(Color.qdInk.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
