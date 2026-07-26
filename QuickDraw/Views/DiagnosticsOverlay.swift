//
//  DiagnosticsOverlay.swift
//  QuickDraw
//
//  Live tuning overlay. Attach at the root; visible only when the Developer
//  diagnostics setting is on. Compiled only in DEBUG builds and in CI
//  TestFlight builds that opt in via the TESTFLIGHT_TOOLS condition — never
//  in App Store release builds.
//

#if DEBUG || TESTFLIGHT_TOOLS
import SwiftUI

struct DiagnosticsOverlay: View {
    @ObservedObject var model: DiagnosticsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            row("phase", model.phase)
            row("conn", model.connection)
            row("round", model.roundID)
            row("rate", String(format: "%.0f Hz", model.samplingHz))
            row("tilt", String(format: "%.2f rad", model.tilt))
            row("rot", String(format: "%.2f rad/s", model.rotationMagnitude))
            row("acc", String(format: "%.2f g", model.accelerationMagnitude))
            row("pitchΔ", String(format: "%.2f rad", model.pitchDelta))
            row("det", model.detectorState)
            row("thr", model.thresholds)
            row("hit", model.lastDetection)
            row("offset", model.syncOffsetMs.map { String(format: "%.1f ms", $0) } ?? "—")
            row("±err", model.syncErrorMs.map { String(format: "%.1f ms", $0) } ?? "—")
            row("opp", model.opponentReport)
        }
        .font(.system(size: 10, design: .monospaced))
        .foregroundStyle(.green)
        .padding(6)
        .background(Color.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 6))
        .padding(.leading, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Text(label).foregroundStyle(.green.opacity(0.6))
            Text(value)
        }
    }
}
#endif
