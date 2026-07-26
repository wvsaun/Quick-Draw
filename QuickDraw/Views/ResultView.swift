//
//  ResultView.swift
//  QuickDraw
//
//  Win = green + "YOU WIN", loss = red + "YOU LOSE", void = amber + reason.
//  Outcomes are always stated in words (never color alone).
//

import SwiftUI

struct ResultView: View {
    @EnvironmentObject var game: GameViewModel
    @EnvironmentObject var settings: SettingsStore

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()

                Text(headline)
                    .font(.system(size: 56, weight: .black, design: .serif))
                    .kerning(2)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .foregroundStyle(.white)

                if let subtitle {
                    Text(subtitle)
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                if let result = game.latestResult, !result.isVoid {
                    ParchmentCard {
                        VStack(spacing: 8) {
                            if let myTime = result.times[settings.playerID] {
                                statRow("Your draw", myTime.reactionString)
                            }
                            if let opponent = game.opponentProfile,
                               let theirTime = result.times[opponent.id] {
                                statRow("\(opponent.displayName)'s draw", theirTime.reactionString)
                            }
                            if let margin = result.margin {
                                statRow("Difference", margin.marginString)
                            }
                            if result.photoFinish {
                                Text("PHOTO FINISH")
                                    .font(.caption.weight(.black))
                                    .kerning(2)
                                    .foregroundStyle(Color.qdCopper)
                            }
                        }
                    }
                    .padding(.horizontal, 40)
                }

                Spacer()

                VStack(spacing: 12) {
                    Button(rematchLabel) { game.requestRematch() }
                        .buttonStyle(WesternButtonStyle())
                        .disabled(game.rematchVotedLocally)
                        .accessibilityHint("Both players must agree to a rematch")
                    if game.opponentWantsRematch && !game.rematchVotedLocally {
                        Text("Your opponent wants a rematch!")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                    Button("Return to Lobby") { game.returnToLobby() }
                        .buttonStyle(WesternButtonStyle(prominent: false))
                    Button("Leave Game") { game.leaveGame() }
                        .buttonStyle(WesternButtonStyle(prominent: false))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(headline). \(subtitle ?? "")")
    }

    private var result: ResolvedRound? { game.latestResult }
    private var didWin: Bool { result?.winnerID == settings.playerID }

    private var backgroundColor: Color {
        guard let result else { return .qdBackground }
        if result.isVoid { return .qdAmber }
        return didWin ? .qdWin : .qdLose
    }

    private var headline: String {
        guard let result else { return "…" }
        if result.isVoid { return "NO CONTEST" }
        return didWin ? "YOU WIN" : "YOU LOSE"
    }

    private var subtitle: String? {
        guard let result else { return nil }
        switch result.reason {
        case .fasterDraw:
            return didWin ? "Fastest hand in the West." : "Outdrawn, partner."
        case .opponentFalseStart:
            return didWin ? "Your opponent false-started." : "You false-started."
        case .opponentNoDraw:
            return didWin ? "Your opponent never drew." : "You never drew."
        case .bothFalseStart:
            return "Both duelists moved early. The round is void — try again."
        case .noDraws:
            return "Neither duelist drew. The round is void — try again."
        case .invalidData:
            return "The timing data couldn't be trusted. The round is void — try again."
        case .disconnected:
            return "The connection dropped mid-round."
        }
    }

    private var rematchLabel: String {
        if game.rematchVotedLocally { return "Waiting for opponent…" }
        return result?.isVoid == true ? "Retry Round" : "Rematch"
    }

    private func statRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color.qdInk.opacity(0.7))
            Spacer()
            Text(value)
                .font(.system(.subheadline, design: .monospaced).weight(.bold))
                .foregroundStyle(Color.qdInk)
        }
        .accessibilityElement(children: .combine)
    }
}
