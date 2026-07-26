//
//  Extensions.swift
//  QuickDraw
//

import Foundation

/// Monotonic clock in the same timebase as `CMDeviceMotion.timestamp`
/// (seconds since boot, not counting deep sleep). Used for all round timing so
/// wall-clock adjustments (NTP, user changes) can never skew a duel.
enum MonotonicClock {
    static var now: TimeInterval { ProcessInfo.processInfo.systemUptime }
}

extension TimeInterval {
    /// "0.312 s" style formatting for reaction times.
    var reactionString: String {
        String(format: "%.3f s", self)
    }

    /// "+0.041 s" style formatting for margins.
    var marginString: String {
        String(format: "%.3f s", abs(self))
    }
}

extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
