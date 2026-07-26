//
//  Player.swift
//  QuickDraw
//

import Foundation

/// Identity shared between peers during the handshake.
struct PlayerProfile: Codable, Equatable, Identifiable {
    let id: UUID
    var displayName: String
}

/// A nearby host discovered while browsing.
struct DiscoveredPeer: Identifiable, Equatable {
    /// Stable identifier for SwiftUI lists (the MCPeerID display name is
    /// unique enough for a room; the service layer keeps the real MCPeerID).
    let id: String
    let displayName: String
}
