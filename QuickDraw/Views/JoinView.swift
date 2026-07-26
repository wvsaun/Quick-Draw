//
//  JoinView.swift
//  QuickDraw
//
//  Covers both the .browsing and .connecting phases.
//

import SwiftUI

struct JoinView: View {
    @EnvironmentObject var game: GameViewModel
    let connecting: Bool

    var body: some View {
        ZStack {
            WesternBackground()
            VStack(spacing: 24) {
                Spacer(minLength: 40)
                Text(connecting ? "CONNECTING" : "JOIN GAME")
                    .westernTitle(size: 34)
                    .foregroundStyle(Color.qdSurface)

                if connecting {
                    ParchmentCard {
                        VStack(spacing: 12) {
                            ProgressView().tint(Color.qdCopper)
                            Text("Connecting to \(game.connectingPeerName ?? "opponent")…")
                                .font(.headline)
                                .foregroundStyle(Color.qdInk)
                        }
                    }
                    .padding(.horizontal, 32)
                } else if game.discoveredPeers.isEmpty {
                    ParchmentCard {
                        VStack(spacing: 12) {
                            ProgressView().tint(Color.qdCopper)
                            Text("Searching for nearby games…")
                                .font(.headline)
                                .foregroundStyle(Color.qdInk)
                            Text("Ask your opponent to tap Host Game.")
                                .font(.subheadline)
                                .foregroundStyle(Color.qdInk.opacity(0.7))
                        }
                    }
                    .padding(.horizontal, 32)
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(game.discoveredPeers) { peer in
                                Button {
                                    game.selectPeer(peer)
                                } label: {
                                    HStack {
                                        Image(systemName: "person.fill")
                                            .accessibilityHidden(true)
                                        Text(peer.displayName)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .accessibilityHidden(true)
                                    }
                                }
                                .buttonStyle(WesternButtonStyle())
                                .accessibilityHint("Join \(peer.displayName)'s game")
                            }
                        }
                        .padding(.horizontal, 32)
                    }
                }

                Spacer()
                Button("Cancel") { game.cancelConnection() }
                    .buttonStyle(WesternButtonStyle(prominent: false))
                    .padding(.horizontal, 32)
                    .padding(.bottom, 20)
            }
        }
        .alert("Connection Problem", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(game.errorMessage ?? "")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { game.errorMessage != nil },
                set: { if !$0 { game.errorMessage = nil } })
    }
}
