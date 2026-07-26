//
//  DiagnosticsModel.swift
//  QuickDraw
//
//  Live values for the developer diagnostics overlay (DEBUG builds only —
//  see DiagnosticsOverlay). Updated by GameViewModel, throttled to a UI-
//  friendly rate so it never affects gameplay timing.
//

import Foundation

final class DiagnosticsModel: ObservableObject {
    @Published var phase = "home"
    @Published var connection = "—"
    @Published var roundID = "—"
    @Published var samplingHz = 0.0
    @Published var tilt = 0.0                 // rad from calibrated rest
    @Published var rotationMagnitude = 0.0    // rad/s
    @Published var accelerationMagnitude = 0.0 // g
    @Published var pitchDelta = 0.0           // rad from resting pitch
    @Published var detectorState = "idle"
    @Published var thresholds = "—"
    @Published var lastDetection = "—"
    @Published var syncOffsetMs: Double?
    @Published var syncErrorMs: Double?
    @Published var opponentReport = "—"
}
