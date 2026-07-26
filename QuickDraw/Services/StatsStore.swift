//
//  StatsStore.swift
//  QuickDraw
//
//  Optional local match statistics. Stored only on this device; never
//  transmitted anywhere.
//

import Foundation

struct MatchStats: Codable, Equatable {
    var matchesPlayed = 0
    var wins = 0
    var losses = 0
    var falseStarts = 0
    var fastestDraw: TimeInterval?
    var totalValidDrawTime: TimeInterval = 0
    var validDrawCount = 0

    var averageDraw: TimeInterval? {
        validDrawCount > 0 ? totalValidDrawTime / Double(validDrawCount) : nil
    }
}

final class StatsStore: ObservableObject {

    private static let key = "stats.match"
    private let defaults: UserDefaults

    @Published private(set) var stats: MatchStats

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode(MatchStats.self, from: data) {
            stats = decoded
        } else {
            stats = MatchStats()
        }
    }

    /// Record a finished round from the LOCAL player's perspective.
    func record(result: ResolvedRound, localPlayerID: UUID) {
        guard !result.isVoid else { return }
        stats.matchesPlayed += 1
        if result.winnerID == localPlayerID {
            stats.wins += 1
        } else {
            stats.losses += 1
        }
        if result.falseStarters.contains(localPlayerID) {
            stats.falseStarts += 1
        }
        if let myTime = result.times[localPlayerID] {
            stats.totalValidDrawTime += myTime
            stats.validDrawCount += 1
            if stats.fastestDraw.map({ myTime < $0 }) ?? true {
                stats.fastestDraw = myTime
            }
        }
        save()
    }

    func resetStats() {
        stats = MatchStats()
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(stats) {
            defaults.set(data, forKey: Self.key)
        }
    }
}
