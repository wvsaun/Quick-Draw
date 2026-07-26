//
//  PeerLink.swift
//  QuickDraw
//
//  Transport abstraction. GameViewModel talks only to this protocol, so the
//  real MultipeerConnectivity service and the DEBUG simulated opponent are
//  interchangeable.
//

import Foundation

enum PeerLinkEvent {
    /// Browser: the visible set of nearby hosts changed.
    case discoveredPeers([DiscoveredPeer])
    /// Connection handshake in progress.
    case connecting(peerName: String)
    /// Transport-level connection established (hello exchange comes next).
    case connected(peerName: String)
    /// The peer went away (any phase).
    case disconnected
    /// A fresh, deduplicated message arrived.
    case received(NetworkMessage)
    /// Hosting/browsing/connection failed with a user-displayable reason.
    case failed(String)
}

protocol PeerLink: AnyObject {
    /// Event sink. The implementation MUST invoke this on the main thread.
    var onEvent: ((PeerLinkEvent) -> Void)? { get set }

    var isConnected: Bool { get }

    /// Start advertising as a host.
    func startHosting(displayName: String)
    /// Start browsing for nearby hosts.
    func startBrowsing(displayName: String)
    /// Invite a discovered host (joiner side).
    func invite(_ peer: DiscoveredPeer)
    /// Send a message. Control/result traffic must use reliable delivery.
    func send(_ message: NetworkMessage)
    /// Tear down everything and stop radios.
    func disconnect()
}
