//
//  PositioningView.swift
//  QuickDraw
//

import SwiftUI

struct PositioningView: View {
    @EnvironmentObject var game: GameViewModel

    var body: some View {
        ZStack {
            WesternBackground()
            VStack(spacing: 26) {
                Spacer(minLength: 30)
                Text("HOLSTER\nYOUR PHONE")
                    .westernTitle(size: 36)
                    .foregroundStyle(Color.qdSurface)

                ParchmentCard {
                    VStack(spacing: 14) {
                        Image(systemName: "iphone.gen3")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.qdCopper)
                            .accessibilityHidden(true)
                        Text("Hold the phone at your hip, just like during calibration. Grip it firmly.")
                            .font(.subheadline)
                            .foregroundStyle(Color.qdInk)
                            .multilineTextAlignment(.center)
                        HStack(spacing: 12) {
                            StatusChip(text: game.localPositionConfirmed ? "YOU: SET" : "YOU: NOT SET",
                                       active: game.localPositionConfirmed)
                            StatusChip(text: game.opponentPositionConfirmed ? "THEM: SET" : "THEM: NOT SET",
                                       active: game.opponentPositionConfirmed)
                        }
                    }
                }
                .padding(.horizontal, 32)

                Text("Stand several feet apart with clear space around you. Don't swing the phone — a quick, controlled raise wins.")
                    .font(.footnote)
                    .foregroundStyle(Color.qdSurface.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)

                Spacer()

                if !game.localPositionConfirmed {
                    Button("I'm in Position") { game.confirmPosition() }
                        .buttonStyle(WesternButtonStyle())
                        .padding(.horizontal, 32)
                        .accessibilityHint("Confirms you are holding the phone at your hip and ready for the countdown")
                } else {
                    Text(game.opponentPositionConfirmed
                         ? "Both set — get ready…"
                         : "Waiting for your opponent…")
                        .font(.headline)
                        .foregroundStyle(Color.qdGold)
                }

                Button("Leave Game") { game.leaveGame() }
                    .buttonStyle(WesternButtonStyle(prominent: false))
                    .padding(.horizontal, 32)
                    .padding(.bottom, 20)
            }
        }
    }
}
