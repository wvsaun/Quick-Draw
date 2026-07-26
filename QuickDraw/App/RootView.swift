//
//  RootView.swift
//  QuickDraw
//
//  Routes GamePhase → screen, gates first launch behind the safety notice,
//  and hosts the DEBUG diagnostics overlay.
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject var game: GameViewModel
    @EnvironmentObject var settings: SettingsStore

    var body: some View {
        ZStack {
            if !settings.safetyAcknowledged {
                SafetyView()
            } else {
                phaseView
            }

            #if DEBUG || TESTFLIGHT_TOOLS
            if settings.diagnosticsEnabled {
                DiagnosticsOverlay(model: game.diagnostics)
            }
            #endif
        }
        .onChange(of: settings.soundEnabled) { game.syncFeedbackSettings() }
        .onChange(of: settings.hapticsEnabled) { game.syncFeedbackSettings() }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var phaseView: some View {
        switch game.phase {
        case .home:
            HomeView()
        case .hosting:
            HostView()
        case .browsing:
            JoinView(connecting: false)
        case .connecting:
            JoinView(connecting: true)
        case .lobby:
            LobbyView()
        case .calibrating:
            CalibrationView()
        case .positioning:
            PositioningView()
        case .countdown, .armed, .resolving:
            CountdownView()
        case .result:
            ResultView()
        case .disconnected:
            InterruptionView(title: "CONNECTION LOST",
                             message: game.disconnectReason
                                 ?? "The connection to your opponent was lost.")
        case .error(let message):
            InterruptionView(title: "TROUBLE",
                             message: message)
        }
    }
}

/// Shared full-screen notice for disconnects and errors.
struct InterruptionView: View {
    @EnvironmentObject var game: GameViewModel
    let title: String
    let message: String

    var body: some View {
        ZStack {
            WesternBackground()
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "antenna.radiowaves.left.and.right.slash")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.qdAmber)
                    .accessibilityHidden(true)
                Text(title)
                    .westernTitle(size: 32)
                    .foregroundStyle(Color.qdSurface)
                Text(message)
                    .font(.headline)
                    .foregroundStyle(Color.qdSurface.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                Spacer()
                Button("Back to Home") { game.returnHome() }
                    .buttonStyle(WesternButtonStyle())
                    .padding(.horizontal, 32)
                    .padding(.bottom, 24)
            }
        }
    }
}
