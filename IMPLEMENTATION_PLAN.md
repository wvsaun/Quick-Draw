# Quick Draw — Implementation Plan

## Goal
A functional two-player Wild West reaction duel for iOS 17+. Two iPhones connect
over Multipeer Connectivity, run a synchronized countdown, detect a "draw"
motion with Core Motion, and the host authoritatively resolves one winner.

## Architecture (MVVM + services)

```
QuickDraw.xcodeproj          Xcode 16 project (synchronized folders, app + unit-test targets)
QuickDraw/
├── App/          QuickDrawApp (entry), RootView (phase router)
├── Models/       PlayerProfile, GamePhase, RoundPlan, RoundResult, MotionSample,
│                 NetworkMessage (typed Codable enum + envelope)
├── Services/
│   ├── PeerConnectionService   MultipeerConnectivity behind a PeerLink protocol
│   ├── SimulatedPeerLink       DEBUG-only fake opponent (simulator support)
│   ├── MotionService           CMMotionManager wrapper behind MotionSource protocol
│   ├── DrawDetector            pure state machine: holstered → movementStarted →
│   │                           drawConfirmed / falseStart / invalidMovement → resetting
│   ├── CalibrationSession      pure resting-orientation capture + noise estimation
│   ├── ClockSyncEstimator      ping/pong monotonic-clock offset estimation (min-RTT)
│   ├── RoundResolver           pure, host-authoritative winner resolution
│   ├── AudioService            AVAudioEngine generated tones (no assets)
│   ├── HapticService           UIKit feedback generators
│   ├── SettingsStore           UserDefaults-backed observable settings
│   └── StatsStore              optional local match statistics
├── ViewModels/   GameViewModel (central coordinator + phase machine),
│                 DiagnosticsModel (debug overlay data)
├── Views/        Home, Host, Join, Lobby, Safety, HowToPlay, Calibration,
│                 Positioning, Countdown (+armed), Result, Settings, Diagnostics, Theme
└── Utilities/    Constants (ALL tunable thresholds), Logger, Extensions
QuickDrawTests/   DrawDetector, RoundResolver, GameState gates, NetworkMessage coding
```

## Key design decisions

1. **Host is authoritative.** Only the host runs `RoundResolver`; both screens
   render the broadcast `ResolvedRound`. Devices never decide independently.
2. **Monotonic time everywhere.** All round timing uses the system-uptime
   timebase (`ProcessInfo.systemUptime`), which matches `CMDeviceMotion.timestamp`.
   The joiner estimates the host-clock offset with a ping/pong burst (min-RTT
   sample wins). Wall clocks are never used for gameplay.
3. **Draw = calibrated gravity-tilt + rotation + acceleration + direction +
   duration.** A draw confirms only when the phone tilts far enough away from
   the calibrated resting gravity, in the *raising* direction, with a real
   rotation peak, inside a duration window, after several consecutive
   above-threshold samples. This rejects tremor, walking vibration, slow lifts,
   and single noisy samples.
4. **Round IDs on every round message.** Stale packets are dropped by a
   `RoundGate` check before they can touch current state.
5. **Pure logic is platform-free.** Detector, resolver, calibration, clock
   estimator, gates, and messages import only Foundation so unit tests cover
   them fully without device hardware.
6. **Simulator support.** DEBUG builds include a simulated opponent (full
   message loop with configurable latency/outcome) plus buttons to fake a local
   draw, false start, or disconnect.

## Round protocol (happy path)

```
lobby: both readyChanged(true)         → host sends beginCalibration
both calibrationDone                   → host sends beginPositioning(roundID)
both positionConfirmed(roundID)        → host sends roundScheduled(plan)
plan = {roundID, readyAt, steadyAt, drawAt}   (host-monotonic; joiner converts)
READY → STEADY → random 1.0–3.5 s → DRAW!
each device sends report {roundID, elapsed | falseStart | noDraw}
host resolves → broadcasts roundResult → both render it
rematchRequest from both → host sends beginPositioning(new roundID)
```

## Build order
models → utilities → pure services → networking → motion → view model → views →
audio/haptics → debug tools → tests → project file → README.

## Environment note
This container has no Swift toolchain (network policy blocks the download), so
compilation and test execution must be done in Xcode on a Mac. Code is written
conservatively (Swift 5 language mode, no strict-concurrency features) and the
core logic is pure Foundation to minimize build risk.
