//
//  HomeView.swift
//  QuickDraw
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var game: GameViewModel
    @EnvironmentObject var settings: SettingsStore
    @State private var showHowToPlay = false
    @State private var showSettings = false
    #if DEBUG
    @State private var showDebugMenu = false
    #endif

    var body: some View {
        ZStack {
            WesternBackground()
            VStack(spacing: 28) {
                Spacer()

                VStack(spacing: 10) {
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Color.qdGold)
                        .accessibilityHidden(true)
                    Text("QUICK DRAW")
                        .westernTitle(size: 46)
                        .foregroundStyle(Color.qdSurface)
                    Text("Wild West Reaction Duel")
                        .font(.system(.headline, design: .serif).italic())
                        .foregroundStyle(Color.qdGold)
                }
                .accessibilityElement(children: .combine)

                Spacer()

                VStack(spacing: 14) {
                    Button("Host Game") { game.hostGame() }
                        .buttonStyle(WesternButtonStyle())
                        .accessibilityHint("Start a game and wait for a nearby opponent")
                    Button("Join Game") { game.joinGame() }
                        .buttonStyle(WesternButtonStyle())
                        .accessibilityHint("Search for a nearby game to join")
                    Button("How to Play") { showHowToPlay = true }
                        .buttonStyle(WesternButtonStyle(prominent: false))
                    Button("Settings") { showSettings = true }
                        .buttonStyle(WesternButtonStyle(prominent: false))
                    #if DEBUG
                    Button("Practice vs. Tin Can Tex (Debug)") { showDebugMenu = true }
                        .buttonStyle(WesternButtonStyle(prominent: false))
                        .font(.footnote)
                    #endif
                }
                .padding(.horizontal, 32)

                Spacer()

                Text("Two iPhones · Nearby connection · No internet needed")
                    .font(.footnote)
                    .foregroundStyle(Color.qdSurface.opacity(0.55))
                    .padding(.bottom, 8)
            }
        }
        .sheet(isPresented: $showHowToPlay) { HowToPlayView() }
        .sheet(isPresented: $showSettings) { SettingsView() }
        #if DEBUG
        .sheet(isPresented: $showDebugMenu) { DebugMenuView() }
        #endif
    }
}
