//
//  GamePhase.swift
//  QuickDraw
//

import Foundation

/// Top-level phase machine. `GameViewModel` owns all transitions.
enum GamePhase: Equatable {
    case home
    case hosting
    case browsing
    case connecting
    case lobby
    case calibrating
    case positioning
    case countdown
    case armed          // DRAW has fired; waiting for local detection
    case resolving      // report sent; waiting for the host's official result
    case result
    case disconnected
    case error(String)

    /// Phases in which losing the peer connection must abort an active round.
    var isRoundActive: Bool {
        switch self {
        case .positioning, .countdown, .armed, .resolving: return true
        default: return false
        }
    }
}

/// What the countdown screen is currently showing.
enum CountdownStage: Equatable {
    case waiting   // plan received, READY not yet shown
    case ready
    case steady
    case draw
}
