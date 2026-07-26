//
//  LobbyView.swift
//  QuickDraw
//

import SwiftUI

struct LobbyView: View {
    @EnvironmentObject var game: GameViewModel
    @EnvironmentObject var settings: SettingsStore

    var body: some View {
        ZStack {
            WesternBackground()
            VStack(spacing: 24) {
                Spacer(minLength: 30)
                Text("THE LOBBY")
                    .westernTitle(size: 34)
                    .foregroundStyle(Color.qdSurface)

                ParchmentCard {
                    VStack(spacing: 16) {
                        playerRow(name: settings.displayName,
                                  subtitle: "You",
                                  ready: game.localReady)
                        Divider().overlay(Color.qdCopper.opacity(0.4))
                        playerRow(name: game.opponentProfile?.displayName ?? "Opponent",
                                  subtitle: "Connected",
                                  ready: game.opponentReady)
                    }
                }
                .padding(.horizontal, 32)

                Text("When both duelists are ready, you'll each calibrate your draw stance.")
                    .font(.footnote)
                    .foregroundStyle(Color.qdSurface.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Spacer()

                VStack(spacing: 14) {
                    Button(game.localReady ? "Not Ready" : "I'm Ready") {
                        game.toggleReady()
                    }
                    .buttonStyle(WesternButtonStyle())
                    .accessibilityHint(game.localReady
                        ? "Mark yourself as not ready"
                        : "Mark yourself as ready to duel")

                    Button("Leave Game") { game.leaveGame() }
                        .buttonStyle(WesternButtonStyle(prominent: false))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 20)
            }
        }
    }

    private func playerRow(name: String, subtitle: String, ready: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(.title3, design: .serif).weight(.bold))
                    .foregroundStyle(Color.qdInk)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Color.qdInk.opacity(0.6))
            }
            Spacer()
            StatusChip(text: ready ? "READY" : "WAITING", active: ready)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), \(subtitle), \(ready ? "ready" : "not ready")")
    }
}
