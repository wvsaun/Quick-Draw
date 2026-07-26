# Quick Draw — Wild West Reaction Duel

A two-player, motion-based reaction game for iPhone. Each player holsters their
phone at the hip; after a synchronized, suspenseful countdown both players
*draw* — quickly raising the phone — and the first valid draw wins. The winner
sees a green **YOU WIN** screen, the loser a red **YOU LOSE** screen, and the
host device is the single authority on the outcome.

Runs entirely on-device: peer-to-peer over Multipeer Connectivity, motion
detection with Core Motion, no accounts, no internet, no analytics.

> Quick Draw is a playful reaction game, not a weapon simulator. The visual
> treatment is stylized Western typography and color — no gun imagery.

---

## Architecture

MVVM plus a service layer, with all game-critical logic kept **pure**
(Foundation-only) so it is fully unit-testable off-device:

```
QuickDraw/
├── App/            QuickDrawApp (entry) · RootView (GamePhase → screen router)
├── Models/         PlayerProfile · GamePhase · RoundPlan · PlayerRoundReport /
│                   ResolvedRound · MotionSample/Vector3 · NetworkMessage (+envelope)
├── Services/
│   ├── PeerConnectionService   MultipeerConnectivity behind the PeerLink protocol
│   ├── SimulatedPeerLink       DEBUG-only scripted opponent for the simulator
│   ├── MotionService           CMMotionManager (100 Hz) behind MotionSource
│   ├── DrawDetector            pure draw/false-start state machine
│   ├── CalibrationSession      pure resting-pose capture + noise estimation
│   ├── ClockSyncEstimator      pure ping/pong clock-offset estimation
│   ├── RoundResolver           pure host-authoritative winner resolution
│   ├── GameStateGates          pure Readiness/Round/Rematch/Calibration gates
│   ├── AudioService            AVAudioEngine synthesized tones (no assets)
│   ├── HapticService           UIKit feedback generators
│   ├── SettingsStore           UserDefaults-backed preferences
│   └── StatsStore              optional local match statistics
├── ViewModels/     GameViewModel (central coordinator) · DiagnosticsModel
├── Views/          Home · Host · Join · Lobby · Safety · HowToPlay · Calibration ·
│                   Positioning · Countdown(+armed/resolving) · Result · Settings ·
│                   DiagnosticsOverlay (DEBUG) · DebugMenu (DEBUG) · Theme
└── Utilities/      Constants (ALL tunables) · Logger · Extensions
QuickDrawTests/     DrawDetector · RoundResolver · GameState · NetworkMessage tests
```

`GameViewModel` owns the `GamePhase` machine
(`home → hosting/browsing/connecting → lobby → calibrating → positioning →
countdown → armed → resolving → result`, plus `disconnected`/`error`) and is the
only mutator of UI state; services report in via main-thread callbacks.

**Deviation from the suggested layout:** there are no separate
Lobby/Calibration/Settings view models — the lobby and calibration are thin
views over `GameViewModel` (they share round state), and `SettingsStore` *is*
the settings view model. `AppCoordinator`'s job is done by `RootView`.
`RoundSynchronizationService` is named `ClockSyncEstimator`.

## Requirements

- Xcode 16 or newer (project uses the synchronized-folder format)
- iOS 17.0+ deployment target
- Two physical iPhones for real gameplay (the simulator has neither usable
  Core Motion nor real Multipeer radios — see Simulator testing below)
- Frameworks: SwiftUI, CoreMotion, MultipeerConnectivity, AVFoundation, UIKit,
  XCTest. **No third-party dependencies.**

**No Mac?** This repo ships a complete Mac-free workflow: GitHub Actions
builds, tests, signs (Apple cloud-managed certificates), and uploads to
TestFlight; iPhones install builds from the TestFlight app. See
[`docs/TESTFLIGHT_SETUP.md`](docs/TESTFLIGHT_SETUP.md). CI TestFlight builds
compile with the `TESTFLIGHT_TOOLS` condition so the diagnostics overlay,
debug menu, and simulated opponent stay available for on-phone tuning; a
manual dispatch with `include_tools` off produces a clean App Store build.

## Xcode setup

1. Open `QuickDraw.xcodeproj`.
2. Select the **QuickDraw** target → *Signing & Capabilities* → choose your
   development **Team** (signing is `Automatic`; do the same for
   **QuickDrawTests** if you run tests on device).
3. Optionally change the bundle identifier (`com.quickdraw.app`) to something
   in your namespace.
4. Build & run (`⌘R`), or test (`⌘U`).

### Info.plist / capabilities (already configured)

`QuickDraw/Info.plist` merges into the generated Info.plist and contains the
entries Multipeer Connectivity requires on iOS 14+:

- `NSLocalNetworkUsageDescription` — local-network permission prompt text
- `NSBonjourServices` — `_quickdraw-duel._tcp`, `_quickdraw-duel._udp`
- `NSMotionUsageDescription` — motion prompt text (defensive; CMMotionManager
  device motion does not currently prompt)
- `UIRequiredDeviceCapabilities` — accelerometer + gyroscope

No entitlements are needed. Each user must accept the **Local Network**
permission prompt on first host/join.

## Running on two physical iPhones

1. Build and install the app on both iPhones (same Xcode, one at a time, or
   via TestFlight).
2. Enable **Wi-Fi and Bluetooth** on both phones (same Wi-Fi network helps but
   isn't required; Multipeer uses peer-to-peer Wi-Fi/Bluetooth).
3. Phone A: **Host Game**. Phone B: **Join Game** → tap Phone A's name.
   Accept the Local Network permission prompt on both phones the first time.
4. In the lobby, both players tap **I'm Ready**.
5. Each player calibrates: hold the phone vertically at the hip, screen facing
   outward, tap **Hold Still — Start**, and keep still ~2 s.
6. **HOLSTER YOUR PHONE**: return to the hip and tap **I'm in Position**.
7. READY… STEADY… *(secret random 1.0–3.5 s pause)* … **DRAW!** — raise the
   phone quickly and smoothly to point forward.
8. Both screens show the host-resolved result with both times and the margin.
   **Rematch** starts a new round once *both* players request it.

## How calibration works

`CalibrationSession` records ~2 s of device motion and computes the mean
gravity vector (the *resting orientation*), the maximum angular wobble of
gravity around that mean (sensor + hand-tremor noise), and the mean user
acceleration. Capture fails with a retry prompt when there is too much
movement or the phone isn't roughly vertical. The result feeds `DrawDetector`
and lives only for the current session (by design — grip and stance change
between sessions).

## How draw detection works

`DrawDetector` is a pure state machine
(`holstered → movementStarted → drawConfirmed | falseStart | invalidMovement →
resetting`) fed 100 Hz samples. A draw confirms only when **all** of these
hold:

| Signal | Why |
|---|---|
| Gravity tilt ≥ ~52° from the calibrated resting gravity | The phone genuinely left the holster pose; can't be faked by shaking |
| Long-axis gravity component moved toward zero (≥ 0.40 g) | Direction check: raising toward aiming, not scooping/rolling |
| Rotation-rate peak ≥ 2.0 rad/s during the movement | A draw is a deliberate rotation; rejects slow drifts |
| 3 consecutive above-threshold samples to start movement | One noisy sample can never trigger anything |
| Tilt crossed between 0.05 s and 1.5 s after movement start | Rejects implausible spikes and non-draw wandering |

Before the DRAW signal the same machine watches for false starts: a completed
draw shape, or a sustained (> 0.25 s) tilt beyond a ~20° grace tolerance, ends
the round as a **FALSE START**. Tremor, walking vibration, and small wrist
adjustments stay inside the grace band and quietly return the machine to
`holstered`. After one detection the machine latches until re-armed, so
duplicate detections are impossible.

Detection timestamps come from `CMDeviceMotion.timestamp` (the sample's own
clock), so processing latency does not affect measured reaction times.

## Tuning motion thresholds

All tunables live in two places:

- `Utilities/Constants.swift` (`GameTuning`) — timeline, resolver, calibration
- `Services/DrawDetector.swift` (`DrawDetectorConfiguration`) — detection

Recommended procedure on a physical iPhone (debug build):

1. Settings → enable **Developer diagnostics**.
2. Play rounds while watching the overlay: live tilt (rad), rotation (rad/s),
   acceleration (g), detector state, and thresholds.
3. Draws not registering → lower `confirmTiltAngle` or
   `confirmMinRotationPeak` (or set sensitivity **High**, which scales
   confirmation thresholds ×0.75).
4. Casual movements registering → raise the same values (or sensitivity
   **Low**, ×1.25).
5. False starts from tremor → raise `preSignalTiltTolerance` or
   `preSignalSustain`.
6. The `hit` row shows the exact detection; `opp` shows the opponent's report
   on the host.

The user-facing **Motion sensitivity** setting (Low/Standard/High) scales the
start/confirm thresholds without code changes.

## Synchronization & winner resolution

- All round timing uses the **monotonic** system-uptime clock (same timebase
  as Core Motion timestamps). Wall clocks are never used.
- Before each round the joiner runs a ping/pong burst; each exchange estimates
  `hostClock − localClock` with error ≤ RTT/2, and the minimum-RTT exchange
  wins (`ClockSyncEstimator`).
- The host schedules `RoundPlan {roundID, readyAt, steadyAt, drawAt}` in host
  time with a 1.5 s lead; the joiner converts to local time using its offset.
  The STEADY→DRAW delay is random (1.0–3.5 s), chosen by the host, and never
  shown to either player.
- Each device measures its reaction locally (detection timestamp − local DRAW
  time) and sends a `PlayerRoundReport` (draw / false start / no draw) to the
  host.
- `RoundResolver` (host-only, pure) applies the rules: earliest valid draw
  wins; a false start loses automatically (both → void + replay); a missing
  report times out as "no draw"; a reaction faster than humanly possible
  (< 50 ms) is reclassified as a false start (the player must have begun
  moving before the signal); margins ≤ 30 ms are labelled **PHOTO FINISH**
  but still produce the measured winner; exact ties break
  deterministically; negative or absurd timings void the round. The host
  broadcasts one official `ResolvedRound`; devices never decide locally.
- Every round message carries a `roundID`; `RoundGate` drops stale packets,
  and a per-sender sequence number drops duplicates.

### Known timing limitations

- The clock offset is estimated, not perfect: expect a few ms of error on a
  quiet link (error bound = best RTT/2, visible in diagnostics). Both devices
  could fire DRAW up to that many ms apart, which is far below human reaction
  variance (~±20 ms between attempts) but not zero. Margins inside the photo-
  finish threshold should be read as "effectively simultaneous."
- `DispatchQueue.asyncAfter` drives the countdown UI/audio with ~1–5 ms jitter;
  *measurement* is immune because it uses sample timestamps, not callback time.
- Detection granularity is one motion sample (~10 ms at 100 Hz).
- Multipeer latency spikes only delay message *delivery* (results), never the
  measured reaction times.

## Continuous integration

`.github/workflows/ios.yml` runs on every push: the `test` job executes the
full unit-test suite on an iOS simulator (macOS runner), and the `deploy` job
(pushes to `main`, or manual dispatch) archives a cloud-signed Release build
and uploads it to TestFlight. Setup, secrets, costs, and troubleshooting are
documented in `docs/TESTFLIGHT_SETUP.md`.

## Simulator testing

Core Motion and Multipeer radios don't work in the simulator, so DEBUG builds
(and `TESTFLIGHT_TOOLS` CI builds) include tools that are fully compiled out
of App Store release builds:

- **Home → Practice vs. Tin Can Tex (Debug)** — a `SimulatedPeerLink` opponent
  that runs the entire real message protocol (lobby, calibration, positioning,
  scheduling, reports, rematch) with configurable one-way latency and a
  behaviour script: random reaction, always fast (you lose), always slow (you
  win), false start, or never draws.
- During the countdown, debug buttons **Sim Draw**, **Sim False Start**, and
  **Drop Link** stand in for real motion and disconnects.
- Calibration auto-completes in simulated matches.
- Settings → **Developer diagnostics** shows phase, connection, round ID,
  sampling rate, live motion values, detector state, thresholds, detection,
  sync offset/error, and the opponent's report.

Unit tests (`⌘U`) cover the detector against synthetic 100 Hz gesture
recordings (still, glitch, wrist adjustment, shake, fast draw, slow draw,
early draw, slow pre-signal lift, wrong direction, reset, duplicates), the
resolver (all outcome permutations, timeouts, stale/duplicate/invalid data),
the state gates, calibration, clock sync, and full wire-format round-trips.

## Safety

Players physically move their phones, so the app requires acknowledging on
first launch: keep a secure grip · stand several feet apart · clear the area ·
never throw or release the phone · avoid people, pets, stairs, traffic,
fragile objects, and water · use a wrist strap or secure case when available.
The detector rewards a quick *controlled* raise — violent swinging is not
better, and the tutorial says so.

## Privacy

Everything runs locally. The app stores only: display name, settings, the
safety acknowledgment, and optional local match statistics. Nearby
connectivity and motion data are used solely to operate the game; motion data
is never persisted. No location, contacts, advertising identifiers, analytics,
accounts, or internet connection.

## Assumptions of note

- Calibration is per-session (not persisted) — stance and grip vary.
- Returning to the lobby re-runs calibration for the next match; a rematch
  from the result screen does not.
- The winner of an exact measured tie is chosen deterministically (lowest
  UUID) and labelled PHOTO FINISH; a visible "dead heat" tie state was traded
  for guaranteed screen consistency.
- iPhone-only, portrait-only.

## Future improvements

- Persist calibration with a quick-revalidate step
- CoreHaptics custom transient patterns; richer Western sound design
- Best-of-N match series with a scoreboard
- Game Center / online play (architecture keeps transport behind `PeerLink`)
- On-device recording of real draw sample traces to refine thresholds
- Localization; iPad support
