//
//  SimulatedPeerLink.swift
//  QuickDraw
//
//  Development-only fake transport with a scripted opponent ("Tin Can Tex")
//  so the entire game flow — lobby, calibration, positioning, countdown,
//  resolution, rematch — can be exercised without a second device. Compiled
//  in DEBUG builds and in CI TestFlight builds (TESTFLIGHT_TOOLS condition);
//  never in App Store release builds.
//

#if DEBUG || TESTFLIGHT_TOOLS
import Foundation

/// Knobs for the simulated opponent, adjustable from the debug menu.
final class DebugSimulationOptions: ObservableObject {
    static let shared = DebugSimulationOptions()

    enum OpponentScript: String, CaseIterable {
        case random        // reaction uniformly in 0.25–0.60 s
        case alwaysFast    // 0.15 s — opponent nearly always wins
        case alwaysSlow    // 1.20 s — opponent nearly always loses
        case falseStart    // opponent moves before DRAW
        case noDraw        // opponent never draws
    }

    @Published var script: OpponentScript = .random
    /// One-way artificial latency applied to every simulated message.
    @Published var latency: TimeInterval = 0.05
}

final class SimulatedPeerLink: PeerLink {

    var onEvent: ((PeerLinkEvent) -> Void)?
    private(set) var isConnected = false

    private let options = DebugSimulationOptions.shared
    private let opponentProfile = PlayerProfile(id: UUID(), displayName: "Tin Can Tex")
    private var currentRoundID: UUID?

    // MARK: PeerLink

    func startHosting(displayName: String) {
        // Tex "joins" shortly after hosting starts.
        after(1.0) {
            self.isConnected = true
            self.onEvent?(.connected(peerName: self.opponentProfile.displayName))
            self.deliver(.hello(profile: self.opponentProfile))
            self.after(0.8) {
                self.deliver(.readyChanged(playerID: self.opponentProfile.id, isReady: true))
            }
        }
    }

    func startBrowsing(displayName: String) {
        after(0.7) {
            self.onEvent?(.discoveredPeers([
                DiscoveredPeer(id: "sim-tex", displayName: self.opponentProfile.displayName)
            ]))
        }
    }

    func invite(_ peer: DiscoveredPeer) {
        onEvent?(.connecting(peerName: peer.displayName))
        after(0.8) {
            self.isConnected = true
            self.onEvent?(.connected(peerName: self.opponentProfile.displayName))
            self.deliver(.hello(profile: self.opponentProfile))
        }
    }

    func send(_ message: NetworkMessage) {
        guard isConnected else { return }
        // React to the local player's messages the way a remote peer would.
        switch message {
        case .hello:
            break
        case .beginCalibration:
            after(1.5) {
                self.deliver(.calibrationDone(playerID: self.opponentProfile.id))
            }
        case .beginPositioning(let roundID):
            currentRoundID = roundID
            after(1.2) {
                self.deliver(.positionConfirmed(playerID: self.opponentProfile.id,
                                                roundID: roundID))
            }
        case .roundScheduled(let plan):
            scheduleOpponentReport(for: plan)
        case .roundResult:
            break
        case .rematchRequest(_, let afterRoundID):
            after(0.9) {
                self.deliver(.rematchRequest(playerID: self.opponentProfile.id,
                                             afterRoundID: afterRoundID))
            }
        case .syncPing(let id, let senderTime):
            // Same physical clock, so echo with a perfect timestamp.
            deliver(.syncPong(id: id, senderTime: senderTime, hostTime: MonotonicClock.now))
        case .leaveGame:
            forceDisconnect()
        default:
            break
        }
    }

    func disconnect() {
        isConnected = false
        currentRoundID = nil
    }

    /// Debug control: simulate the opponent dropping mid-game.
    func forceDisconnect() {
        guard isConnected else { return }
        isConnected = false
        onEvent?(.disconnected)
    }

    // MARK: Opponent behaviour

    private func scheduleOpponentReport(for plan: RoundPlan) {
        let roundID = plan.roundID
        // The simulated opponent shares this device's clock, so plan times
        // are already local.
        let drawDelay = max(0, plan.drawAt - MonotonicClock.now)

        switch options.script {
        case .falseStart:
            // Move ~0.4 s before DRAW (but never before STEADY).
            let early = max(0.05, drawDelay - 0.4)
            after(early) {
                self.deliver(.report(.falseStart(playerID: self.opponentProfile.id,
                                                 roundID: roundID)))
            }
        case .noDraw:
            after(drawDelay + GameTuning.maxDrawWindow) {
                self.deliver(.report(.noDraw(playerID: self.opponentProfile.id,
                                             roundID: roundID)))
            }
        case .random, .alwaysFast, .alwaysSlow:
            let reaction: TimeInterval
            switch options.script {
            case .alwaysFast: reaction = 0.15
            case .alwaysSlow: reaction = 1.20
            default: reaction = TimeInterval.random(in: 0.25...0.60)
            }
            after(drawDelay + reaction) {
                self.deliver(.report(.draw(playerID: self.opponentProfile.id,
                                           roundID: roundID,
                                           elapsed: reaction)))
            }
        }
    }

    // MARK: Plumbing

    /// Deliver a message from "Tex" to the local player with artificial latency.
    private func deliver(_ message: NetworkMessage) {
        after(options.latency) {
            guard self.isConnected else { return }
            self.onEvent?(.received(message))
        }
    }

    private func after(_ delay: TimeInterval, _ block: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard self != nil else { return }
            block()
        }
    }
}
#endif
