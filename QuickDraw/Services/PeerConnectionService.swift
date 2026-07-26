//
//  PeerConnectionService.swift
//  QuickDraw
//
//  MultipeerConnectivity transport. Responsibilities:
//    • host advertising / joiner browsing / invitations
//    • enforcing the two-player limit (extra invitations are declined and
//      advertising stops once an opponent connects)
//    • reliable, ordered delivery of MessageEnvelopes with duplicate dropping
//    • surfacing every state change on the main thread
//    • full teardown so the app can safely return to the lobby or home
//

import Foundation
import MultipeerConnectivity

final class PeerConnectionService: NSObject, PeerLink {

    var onEvent: ((PeerLinkEvent) -> Void)?

    private var myPeerID: MCPeerID?
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?

    /// The one connected (or connecting) opponent.
    private var opponentPeerID: MCPeerID?
    /// Distinguishes "connection lost" from "invitation declined/failed".
    private var everConnected = false
    /// Browser-side directory of discovered hosts.
    private var foundPeers: [String: MCPeerID] = [:]

    private var outgoingSeq = 0
    private var duplicateFilter = DuplicateFilter()

    var isConnected: Bool {
        guard let session, let opponentPeerID else { return false }
        return session.connectedPeers.contains(opponentPeerID)
    }

    // MARK: - Lifecycle

    private func makeSession(displayName: String) -> MCSession {
        // A short random suffix keeps MCPeerID unique even when both players
        // picked the same display name.
        let suffix = String(UUID().uuidString.prefix(4))
        let name = String(displayName.prefix(20)) + "·" + suffix
        let peerID = MCPeerID(displayName: name)
        myPeerID = peerID
        let session = MCSession(peer: peerID,
                                securityIdentity: nil,
                                encryptionPreference: .required)
        session.delegate = self
        return session
    }

    func startHosting(displayName: String) {
        disconnect()
        let session = makeSession(displayName: displayName)
        self.session = session
        guard let myPeerID else { return }
        let advertiser = MCNearbyServiceAdvertiser(peer: myPeerID,
                                                   discoveryInfo: ["name": displayName],
                                                   serviceType: GameTuning.serviceType)
        advertiser.delegate = self
        self.advertiser = advertiser
        advertiser.startAdvertisingPeer()
        Log.network.info("Started advertising as \(displayName, privacy: .public)")
    }

    func startBrowsing(displayName: String) {
        disconnect()
        let session = makeSession(displayName: displayName)
        self.session = session
        guard let myPeerID else { return }
        let browser = MCNearbyServiceBrowser(peer: myPeerID,
                                             serviceType: GameTuning.serviceType)
        browser.delegate = self
        self.browser = browser
        browser.startBrowsingForPeers()
        Log.network.info("Started browsing")
    }

    func invite(_ peer: DiscoveredPeer) {
        guard let browser, let session, let target = foundPeers[peer.id] else { return }
        opponentPeerID = target
        emit(.connecting(peerName: peer.displayName))
        browser.invitePeer(target, to: session, withContext: nil, timeout: 15)
    }

    func send(_ message: NetworkMessage) {
        guard let session, let opponentPeerID,
              session.connectedPeers.contains(opponentPeerID) else { return }
        outgoingSeq += 1
        let envelope = MessageEnvelope(seq: outgoingSeq, message: message)
        do {
            let data = try envelope.encoded()
            // Reliable + ordered: gameplay control and results must arrive.
            try session.send(data, toPeers: [opponentPeerID], with: .reliable)
        } catch {
            Log.network.error("Send failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func disconnect() {
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
        browser?.stopBrowsingForPeers()
        browser = nil
        session?.disconnect()
        session?.delegate = nil
        session = nil
        opponentPeerID = nil
        everConnected = false
        foundPeers.removeAll()
        outgoingSeq = 0
        duplicateFilter.reset()
    }

    // MARK: - Helpers

    private func emit(_ event: PeerLinkEvent) {
        DispatchQueue.main.async { [weak self] in
            self?.onEvent?(event)
        }
    }

    private func emitDiscoveredPeers() {
        let peers = foundPeers.map { key, value in
            DiscoveredPeer(id: key, displayName: prettyName(value.displayName))
        }.sorted { $0.displayName < $1.displayName }
        emit(.discoveredPeers(peers))
    }

    /// Strip the uniqueness suffix for display.
    private func prettyName(_ raw: String) -> String {
        raw.components(separatedBy: "·").first ?? raw
    }
}

// MARK: - MCSessionDelegate

extension PeerConnectionService: MCSessionDelegate {

    func session(_ session: MCSession, peer peerID: MCPeerID,
                 didChange state: MCSessionState) {
        // MCSession calls this on an arbitrary queue; all service state is
        // owned by the main queue, so hop before touching anything.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            switch state {
            case .connecting:
                self.onEvent?(.connecting(peerName: self.prettyName(peerID.displayName)))
            case .connected:
                // First connected peer becomes THE opponent; stop discovery so
                // a third player can never join mid-game.
                if self.opponentPeerID == nil || self.opponentPeerID == peerID {
                    self.opponentPeerID = peerID
                    self.everConnected = true
                    self.advertiser?.stopAdvertisingPeer()
                    self.browser?.stopBrowsingForPeers()
                    self.duplicateFilter.reset()
                    self.onEvent?(.connected(peerName: self.prettyName(peerID.displayName)))
                } else {
                    Log.network.warning("Rejecting extra peer \(peerID.displayName, privacy: .public)")
                }
            case .notConnected:
                if peerID == self.opponentPeerID {
                    self.opponentPeerID = nil
                    if self.everConnected {
                        self.onEvent?(.disconnected)
                    } else {
                        // Our invitation was declined, timed out, or the
                        // handshake failed before ever connecting.
                        self.onEvent?(.failed("Could not connect. Try again."))
                    }
                }
            @unknown default:
                break
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        do {
            let envelope = try MessageEnvelope.decode(data)
            // MCSession delivers on an arbitrary queue; validate, filter and
            // forward on main so all state stays single-threaded.
            DispatchQueue.main.async { [weak self] in
                guard let self, peerID == self.opponentPeerID else { return }
                guard self.duplicateFilter.accept(envelope) else {
                    Log.network.debug("Dropped duplicate/stale seq \(envelope.seq)")
                    return
                }
                self.onEvent?(.received(envelope.message))
            }
        } catch {
            Log.network.error("Undecodable message: \(error.localizedDescription, privacy: .public)")
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream,
                 withName streamName: String, fromPeer peerID: MCPeerID) {}

    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID, with progress: Progress) {}

    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate (host)

extension PeerConnectionService: MCNearbyServiceAdvertiserDelegate {

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                    didReceiveInvitationFromPeer peerID: MCPeerID,
                    withContext context: Data?,
                    invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        DispatchQueue.main.async { [weak self] in
            // Two-player limit: accept only while no opponent is attached.
            guard let self, self.opponentPeerID == nil, let session = self.session else {
                invitationHandler(false, nil)
                return
            }
            self.opponentPeerID = peerID
            invitationHandler(true, session)
        }
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                    didNotStartAdvertisingPeer error: Error) {
        emit(.failed("Could not start hosting: \(error.localizedDescription)"))
    }
}

// MARK: - MCNearbyServiceBrowserDelegate (joiner)

extension PeerConnectionService: MCNearbyServiceBrowserDelegate {

    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID,
                 withDiscoveryInfo info: [String: String]?) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.foundPeers[peerID.displayName] = peerID
            self.emitDiscoveredPeers()
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.foundPeers.removeValue(forKey: peerID.displayName)
            self.emitDiscoveredPeers()
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser,
                 didNotStartBrowsingForPeers error: Error) {
        emit(.failed("Could not search for games: \(error.localizedDescription)"))
    }
}
