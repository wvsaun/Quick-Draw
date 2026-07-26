//
//  SafetyView.swift
//  QuickDraw
//
//  Shown on first launch; the player must acknowledge before playing.
//

import SwiftUI

struct SafetyView: View {
    @EnvironmentObject var settings: SettingsStore

    var body: some View {
        ZStack {
            WesternBackground()
            VStack(spacing: 20) {
                Spacer(minLength: 30)
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.qdGold)
                    .accessibilityHidden(true)
                Text("PLAY SAFE,\nPARTNER")
                    .westernTitle(size: 32)
                    .foregroundStyle(Color.qdSurface)

                ScrollView {
                    ParchmentCard {
                        VStack(alignment: .leading, spacing: 12) {
                            rule("Keep a secure grip on your phone at all times.")
                            rule("Stand several feet apart from your opponent.")
                            rule("Clear the area around you before playing.")
                            rule("Never throw, swing wildly, or release the phone — the game detects a quick, controlled raise.")
                            rule("Don't play near people, pets, stairs, traffic, fragile objects, or water.")
                            rule("Use a wrist strap or a secure case if you have one.")
                        }
                    }
                    .padding(.horizontal, 28)

                    Text("Privacy: Quick Draw runs entirely on your devices. Nearby connectivity and motion data are used only to run the game and are never stored afterward or sent anywhere else.")
                        .font(.footnote)
                        .foregroundStyle(Color.qdSurface.opacity(0.6))
                        .padding(.horizontal, 32)
                        .padding(.top, 12)
                }

                Button("I Understand — Let's Duel") {
                    settings.safetyAcknowledged = true
                }
                .buttonStyle(WesternButtonStyle())
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
                .accessibilityHint("Acknowledges the safety instructions and opens the game")
            }
        }
    }

    private func rule(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.qdCopper)
                .accessibilityHidden(true)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Color.qdInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
