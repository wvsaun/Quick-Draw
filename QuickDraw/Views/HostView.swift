//
//  HostView.swift
//  QuickDraw
//

import SwiftUI

struct HostView: View {
    @EnvironmentObject var game: GameViewModel
    @EnvironmentObject var settings: SettingsStore

    var body: some View {
        ZStack {
            WesternBackground()
            VStack(spacing: 30) {
                Spacer()
                Text("HOSTING")
                    .westernTitle(size: 34)
                    .foregroundStyle(Color.qdSurface)

                ParchmentCard {
                    VStack(spacing: 12) {
                        Text(settings.displayName)
                            .font(.system(.title2, design: .serif).weight(.bold))
                            .foregroundStyle(Color.qdInk)
                        ProgressView()
                            .tint(Color.qdCopper)
                        Text("Waiting for an opponent to join…")
                            .font(.subheadline)
                            .foregroundStyle(Color.qdInk.opacity(0.75))
                        if let name = game.connectingPeerName {
                            Text("\(name) is connecting…")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.qdCopper)
                        }
                    }
                }
                .padding(.horizontal, 32)
                .accessibilityElement(children: .combine)

                Text("Your opponent should tap Join Game on their iPhone. Keep both phones within a few yards of each other.")
                    .font(.footnote)
                    .foregroundStyle(Color.qdSurface.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Spacer()
                Button("Cancel") { game.cancelConnection() }
                    .buttonStyle(WesternButtonStyle(prominent: false))
                    .padding(.horizontal, 32)
                    .padding(.bottom, 20)
            }
        }
    }
}
