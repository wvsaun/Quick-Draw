//
//  ClockSyncEstimator.swift
//  QuickDraw
//
//  Estimates the offset between the HOST's monotonic clock and the local
//  monotonic clock using a burst of ping/pong exchanges (a tiny NTP):
//
//      joiner sends ping at t0 (local)
//      host stamps hostTime tH and replies
//      joiner receives at t1 (local)
//      offset ≈ tH − (t0 + t1) / 2        (error ≤ RTT / 2)
//
//  The sample with the smallest RTT is the most trustworthy (least queueing),
//  so we use it and report RTT/2 as the error bound. Limitations are
//  documented in README.md ("Timing limitations").
//

import Foundation

final class ClockSyncEstimator {

    struct Exchange: Equatable {
        let offset: TimeInterval   // hostClock − localClock
        let rtt: TimeInterval
    }

    private(set) var exchanges: [Exchange] = []

    /// hostClock − localClock of the best (min-RTT) exchange. 0 until any
    /// exchange lands — and permanently 0 on the host itself.
    var offset: TimeInterval { best?.offset ?? 0 }

    /// Upper bound on the sync error (half the best round-trip).
    var estimatedError: TimeInterval? { best.map { $0.rtt / 2 } }

    var hasEstimate: Bool { !exchanges.isEmpty }

    private var best: Exchange? {
        exchanges.min(by: { $0.rtt < $1.rtt })
    }

    /// Record one completed ping/pong.
    func addExchange(pingSentAt t0: TimeInterval,
                     hostTime: TimeInterval,
                     pongReceivedAt t1: TimeInterval) {
        guard t1 >= t0 else { return } // clock went backwards? drop it
        let rtt = t1 - t0
        let offset = hostTime - (t0 + t1) / 2
        exchanges.append(Exchange(offset: offset, rtt: rtt))
        // Keep the burst bounded.
        if exchanges.count > 32 { exchanges.removeFirst() }
    }

    /// Convert a host-clock instant into the local clock.
    func localTime(forHostTime hostTime: TimeInterval) -> TimeInterval {
        hostTime - offset
    }

    func reset() { exchanges.removeAll() }
}
