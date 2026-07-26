//
//  GameViewModel.swift
//  QuickDraw
//
//  Central coordinator: owns the phase machine, wires the transport, motion
//  pipeline, calibration, round timeline, and (on the host) authoritative
//  resolution. Everything runs on the main queue — service callbacks hop to
//  main before touching this object. Detection accuracy does not depend on
//  callback latency because all round timing uses motion-sample timestamps.
//

import Foundation
import UIKit

final class GameViewModel: ObservableObject {

    enum Role { case host, joiner }

    // MARK: - Published UI state

    @Published private(set) var phase: GamePhase = .home
    @Published private(set) var countdownStage: CountdownStage = .waiting
    @Published private(set) var discoveredPeers: [DiscoveredPeer] = []
    @Published private(set) var opponentProfile: PlayerProfile?
    @Published private(set) var connectingPeerName: String?
    @Published private(set) var localReady = false
    @Published private(set) var opponentReady = false
    @Published private(set) var localCalibrated = false
    @Published private(set) var opponentCalibrated = false
    @Published private(set) var localPositionConfirmed = false
    @Published private(set) var opponentPositionConfirmed = false
    @Published private(set) var latestResult: ResolvedRound?
    @Published private(set) var localFalseStarted = false
    @Published private(set) var localDrawElapsed: TimeInterval?
    @Published private(set) var calibrationRunning = false
    @Published private(set) var calibrationProgress: Double = 0
    @Published private(set) var calibrationFailure: String?
    @Published private(set) var rematchVotedLocally = false
    @Published private(set) var opponentWantsRematch = false
    @Published private(set) var disconnectReason: String?
    @Published var errorMessage: String?

    let diagnostics = DiagnosticsModel()

    // MARK: - Dependencies

    let settings: SettingsStore
    let stats: StatsStore
    private let audio = AudioService()
    private let haptics = HapticService()
    private var link: PeerLink
    private var motion: MotionSource
    private let detector: DrawDetector
    private let clockSync = ClockSyncEstimator()
    private let resolver = RoundResolver()

    private(set) var role: Role = .host
    private var isSimulated = false

    // MARK: - Round state

    private var roundGate = RoundGate()
    private var rematch = RematchCoordinator()
    private var calibrationGate = CalibrationGate()
    private var positionVotes: Set<UUID> = []
    private var calibrationSession: CalibrationSession?
    private(set) var calibrationData: CalibrationData?

    private var currentPlan: RoundPlan?
    /// plan.drawAt converted into this device's monotonic clock.
    private var localDrawAt: TimeInterval?
    private var hostReports: [UUID: PlayerRoundReport] = [:]
    private var scheduledWork: [DispatchWorkItem] = []
    private var lastDiagnosticsUpdate: TimeInterval = 0

    // MARK: - Init

    init(settings: SettingsStore,
         stats: StatsStore,
         link: PeerLink = PeerConnectionService(),
         motion: MotionSource = MotionService()) {
        self.settings = settings
        self.stats = stats
        self.link = link
        self.motion = motion
        self.detector = DrawDetector(configuration: .forSensitivity(settings.sensitivity))
        wireLink()
        wireMotion()
        syncFeedbackSettings()
    }

    private func wireLink() {
        link.onEvent = { [weak self] event in
            // PeerLink implementations already deliver on main.
            self?.handleLinkEvent(event)
        }
    }

    private func wireMotion() {
        motion.onSample = { [weak self] sample in
            DispatchQueue.main.async { self?.handleSample(sample) }
        }
    }

    /// Push the current sound/haptics toggles into the services.
    func syncFeedbackSettings() {
        audio.isEnabled = settings.soundEnabled
        haptics.isEnabled = settings.hapticsEnabled
    }

    private var localPlayerID: UUID { settings.playerID }

    private var players: (UUID, UUID)? {
        guard let opponent = opponentProfile else { return nil }
        return (localPlayerID, opponent.id)
    }

    private var motionAvailable: Bool { motion.isAvailable || isSimulated }

    // MARK: - Home-screen intents

    func hostGame() {
        audio.buttonTap(); haptics.buttonTap()
        role = .host
        setPhase(.hosting)
        link.startHosting(displayName: settings.displayName)
    }

    func joinGame() {
        audio.buttonTap(); haptics.buttonTap()
        role = .joiner
        discoveredPeers = []
        setPhase(.browsing)
        link.startBrowsing(displayName: settings.displayName)
    }

    func selectPeer(_ peer: DiscoveredPeer) {
        audio.buttonTap(); haptics.buttonTap()
        connectingPeerName = peer.displayName
        setPhase(.connecting)
        link.invite(peer)
    }

    /// Cancel hosting/browsing/connecting and return home.
    func cancelConnection() {
        resetToHome()
    }

    // MARK: - Lobby intents

    func toggleReady() {
        localReady.toggle()
        audio.readyCue(); haptics.readyCue()
        link.send(.readyChanged(playerID: localPlayerID, isReady: localReady))
        if role == .host { checkLobbyGate() }
    }

    private func checkLobbyGate() {
        guard role == .host, phase == .lobby else { return }
        let gate = ReadinessGate(isConnected: link.isConnected,
                                 localReady: localReady,
                                 opponentReady: opponentReady,
                                 motionAvailable: motionAvailable)
        if gate.canProceedToCalibration {
            link.send(.beginCalibration)
            enterCalibration()
        }
    }

    // MARK: - Calibration

    private func enterCalibration() {
        calibrationGate.reset()
        localCalibrated = false
        opponentCalibrated = false
        calibrationRunning = false
        calibrationProgress = 0
        calibrationFailure = nil
        calibrationSession = nil
        setPhase(.calibrating)
        motion.start()
    }

    /// Player tapped "Hold still — start capture".
    func startCalibrationCapture() {
        audio.buttonTap(); haptics.buttonTap()
        calibrationFailure = nil
        calibrationProgress = 0
        calibrationRunning = true
        if isSimulated {
            // Simulator: no real sensors; complete with a canonical resting pose.
            schedule(after: 1.2) { [weak self] in
                self?.finishCalibration(.success(CalibrationData(
                    restingGravity: Vector3(x: 0, y: -1, z: 0),
                    gravityNoise: 0.02, accelerationNoise: 0.01, restingPitch: 0)))
            }
            return
        }
        calibrationSession = CalibrationSession()
    }

    private func finishCalibration(_ outcome: CalibrationOutcome) {
        calibrationRunning = false
        calibrationSession = nil
        switch outcome {
        case .success(let data):
            calibrationData = data
            detector.setCalibration(data)
            localCalibrated = true
            calibrationGate.markComplete(playerID: localPlayerID)
            link.send(.calibrationDone(playerID: localPlayerID))
            audio.readyCue(); haptics.readyCue()
            if role == .host { checkCalibrationGate() }
        case .failedTooMuchMovement:
            calibrationFailure = "Too much movement. Hold the phone still at your hip and try again."
        case .failedNotUpright:
            calibrationFailure = "Hold the phone upright (vertical) near your hip, then try again."
        case .failedNoData:
            calibrationFailure = "Couldn't read motion data. Try again."
        }
    }

    private func checkCalibrationGate() {
        guard role == .host, phase == .calibrating, let players else { return }
        if calibrationGate.bothCalibrated(players: players) {
            startNewRound()
        }
    }

    // MARK: - Round lifecycle

    /// Host only: mint a new round and move both devices to positioning.
    private func startNewRound() {
        guard role == .host else { return }
        let roundID = UUID()
        link.send(.beginPositioning(roundID: roundID))
        enterPositioning(roundID: roundID)
    }

    private func enterPositioning(roundID: UUID) {
        roundGate.beginRound(roundID)
        currentPlan = nil
        localDrawAt = nil
        hostReports = [:]
        positionVotes = []
        rematch.reset()
        rematchVotedLocally = false
        opponentWantsRematch = false
        localPositionConfirmed = false
        opponentPositionConfirmed = false
        localFalseStarted = false
        localDrawElapsed = nil
        latestResult = nil
        countdownStage = .waiting
        detector.reset()
        detector.configuration = .forSensitivity(settings.sensitivity)
        motion.start()
        haptics.prepareForRound()
        syncFeedbackSettings()
        setPhase(.positioning)
        if role == .joiner { runClockSyncBurst() }
    }

    /// Player tapped "I'm in Position".
    func confirmPosition() {
        guard phase == .positioning, !localPositionConfirmed,
              let roundID = roundGate.currentRoundID else { return }
        audio.buttonTap(); haptics.buttonTap()
        localPositionConfirmed = true
        link.send(.positionConfirmed(playerID: localPlayerID, roundID: roundID))
        if role == .host {
            positionVotes.insert(localPlayerID)
            checkPositionGate()
        }
    }

    private func checkPositionGate() {
        guard role == .host, phase == .positioning, let players,
              let roundID = roundGate.currentRoundID else { return }
        if positionVotes.contains(players.0) && positionVotes.contains(players.1) {
            let plan = RoundPlan.schedule(
                roundID: roundID,
                now: MonotonicClock.now,
                suspenseDelay: .random(in: GameTuning.suspenseDelayRange))
            link.send(.roundScheduled(plan: plan))
            beginCountdown(plan)
        }
    }

    /// Both roles: turn the (host-clock) plan into a local timeline.
    private func beginCountdown(_ plan: RoundPlan) {
        currentPlan = plan
        let readyLocal = clockSync.localTime(forHostTime: plan.readyAt)
        let steadyLocal = clockSync.localTime(forHostTime: plan.steadyAt)
        let drawLocal = clockSync.localTime(forHostTime: plan.drawAt)
        localDrawAt = drawLocal

        // Motion monitoring is live for the whole countdown: arm now so any
        // early draw between READY and DRAW is caught as a false start.
        detector.arm(at: readyLocal, signalAt: drawLocal)

        UIApplication.shared.isIdleTimerDisabled = true
        setPhase(.countdown)
        countdownStage = .waiting

        schedule(at: readyLocal) { [weak self] in
            guard let self, self.phase == .countdown else { return }
            self.countdownStage = .ready
            self.audio.countdownReady(); self.haptics.countdownTick()
        }
        schedule(at: steadyLocal) { [weak self] in
            guard let self, self.phase == .countdown else { return }
            self.countdownStage = .steady
            self.audio.countdownSteady(); self.haptics.countdownTick()
        }
        schedule(at: drawLocal) { [weak self] in
            guard let self, self.phase == .countdown else { return }
            self.countdownStage = .draw
            self.setPhase(.armed)
            self.audio.drawSignal(); self.haptics.drawSignal()
        }
        schedule(at: drawLocal + GameTuning.maxDrawWindow) { [weak self] in
            self?.handleLocalNoDraw()
        }
        if role == .host {
            schedule(at: drawLocal + GameTuning.maxDrawWindow + GameTuning.hostResolveGrace) { [weak self] in
                self?.maybeResolve(timedOut: true)
            }
        }
    }

    // MARK: - Local round outcomes

    private func handleLocalDraw(elapsed: TimeInterval,
                                 peakRotation: Double?, tilt: Double?) {
        // .countdown is also legal: the detector timestamps against the DRAW
        // moment itself, and a fast draw's sample can arrive a beat before the
        // scheduled phase flip to .armed executes.
        guard phase == .armed || phase == .countdown,
              localDrawElapsed == nil, !localFalseStarted, elapsed >= 0,
              let roundID = roundGate.currentRoundID else { return }
        localDrawElapsed = elapsed
        haptics.readyCue()
        let report = PlayerRoundReport.draw(playerID: localPlayerID, roundID: roundID,
                                            elapsed: elapsed,
                                            peakRotation: peakRotation, tiltAngle: tilt)
        setPhase(.resolving)
        submit(report)
        updateDiagnosticsDetection("draw @ \(elapsed.reactionString)")
    }

    private func handleLocalFalseStart() {
        guard phase == .countdown || phase == .armed,
              !localFalseStarted, localDrawElapsed == nil,
              let roundID = roundGate.currentRoundID else { return }
        localFalseStarted = true
        audio.falseStart(); haptics.falseStart()
        cancelCountdownDisplay()
        let report = PlayerRoundReport.falseStart(playerID: localPlayerID, roundID: roundID)
        setPhase(.resolving)
        submit(report)
        updateDiagnosticsDetection("FALSE START")
    }

    private func handleLocalNoDraw() {
        guard phase == .armed, localDrawElapsed == nil, !localFalseStarted,
              let roundID = roundGate.currentRoundID else { return }
        let report = PlayerRoundReport.noDraw(playerID: localPlayerID, roundID: roundID)
        setPhase(.resolving)
        submit(report)
    }

    /// Route a local report: the host stores it directly, a joiner sends it.
    private func submit(_ report: PlayerRoundReport) {
        if role == .host {
            storeReport(report)
        } else {
            link.send(.report(report))
        }
    }

    // MARK: - Host-authoritative resolution

    private func storeReport(_ report: PlayerRoundReport) {
        guard role == .host, roundGate.allows(report.roundID) else { return }
        hostReports[report.playerID] = report
        if report.playerID != localPlayerID {
            diagnostics.opponentReport = report.falseStart
                ? "false start"
                : report.elapsed.map { $0.reactionString } ?? "no draw"
        }
        if report.falseStart {
            // Give the other player a short window to also false start, then
            // resolve with whatever we have.
            schedule(after: GameTuning.falseStartSettleWindow) { [weak self] in
                self?.maybeResolve(timedOut: true)
            }
        }
        maybeResolve(timedOut: false)
    }

    private func maybeResolve(timedOut: Bool) {
        guard role == .host, let players,
              let roundID = roundGate.currentRoundID,
              latestResult?.roundID != roundID else { return }
        if let resolved = resolver.resolve(roundID: roundID, players: players,
                                           reports: hostReports, timedOut: timedOut) {
            link.send(.roundResult(resolved))
            apply(result: resolved)
        }
    }

    private func apply(result: ResolvedRound) {
        cancelAllScheduledWork()
        detector.reset()
        motion.stop()
        UIApplication.shared.isIdleTimerDisabled = false
        latestResult = result
        stats.record(result: result, localPlayerID: localPlayerID)
        setPhase(.result)

        if result.isVoid {
            haptics.lose()
        } else if result.winnerID == localPlayerID {
            audio.win(); haptics.win()
        } else {
            audio.lose(); haptics.lose()
        }
    }

    // MARK: - Result-screen intents

    func requestRematch() {
        guard phase == .result, !rematchVotedLocally,
              let roundID = latestResult?.roundID else { return }
        audio.buttonTap(); haptics.buttonTap()
        rematchVotedLocally = true
        rematch.vote(playerID: localPlayerID)
        link.send(.rematchRequest(playerID: localPlayerID, afterRoundID: roundID))
        if role == .host { checkRematchGate() }
    }

    private func checkRematchGate() {
        guard role == .host, phase == .result, let players else { return }
        if rematch.bothAgreed(players: players) {
            startNewRound()
        }
    }

    func returnToLobby() {
        audio.buttonTap(); haptics.buttonTap()
        cancelAllScheduledWork()
        detector.reset()
        motion.stop()
        UIApplication.shared.isIdleTimerDisabled = false
        roundGate.endRound()
        localReady = false
        link.send(.readyChanged(playerID: localPlayerID, isReady: false))
        localPositionConfirmed = false
        opponentPositionConfirmed = false
        localFalseStarted = false
        localDrawElapsed = nil
        rematchVotedLocally = false
        opponentWantsRematch = false
        setPhase(.lobby)
    }

    func leaveGame() {
        link.send(.leaveGame(playerID: localPlayerID))
        resetToHome()
    }

    /// From the disconnected/error screens.
    func returnHome() {
        resetToHome()
    }

    // MARK: - Incoming events

    private func handleLinkEvent(_ event: PeerLinkEvent) {
        switch event {
        case .discoveredPeers(let peers):
            discoveredPeers = peers

        case .connecting(let name):
            connectingPeerName = name
            if phase == .browsing { setPhase(.connecting) }

        case .connected(let name):
            connectingPeerName = name
            audio.playerConnected(); haptics.playerConnected()
            link.send(.hello(profile: settings.profile))
            localReady = false
            opponentReady = false
            setPhase(.lobby)

        case .received(let message):
            handle(message)

        case .disconnected:
            handlePeerLost(reason: "Connection to your opponent was lost.")

        case .failed(let reason):
            errorMessage = reason
            switch phase {
            case .connecting:
                setPhase(.browsing)   // browser is still running; pick again
            case .hosting, .browsing:
                setPhase(.error(reason))
            default:
                break
            }
        }
    }

    private func handle(_ message: NetworkMessage) {
        // Round-scoped messages from stale rounds are dropped outright —
        // except beginPositioning, which legitimately establishes a NEW round.
        if case .beginPositioning = message {
        } else if !roundGate.allows(message.roundID) {
            Log.game.debug("Dropped stale round message")
            return
        }

        switch message {
        case .hello(let profile):
            opponentProfile = profile

        case .readyChanged(let playerID, let isReady):
            guard playerID == opponentProfile?.id else { return }
            opponentReady = isReady
            if isReady { audio.readyCue() }
            if role == .host { checkLobbyGate() }

        case .beginCalibration:
            guard role == .joiner else { return }
            enterCalibration()

        case .calibrationDone(let playerID):
            calibrationGate.markComplete(playerID: playerID)
            if playerID == opponentProfile?.id { opponentCalibrated = true }
            if role == .host { checkCalibrationGate() }

        case .beginPositioning(let roundID):
            guard role == .joiner else { return }
            enterPositioning(roundID: roundID)

        case .positionConfirmed(let playerID, _):
            if playerID == opponentProfile?.id { opponentPositionConfirmed = true }
            if role == .host {
                positionVotes.insert(playerID)
                checkPositionGate()
            }

        case .roundScheduled(let plan):
            guard role == .joiner, phase == .positioning else { return }
            beginCountdown(plan)

        case .report(let report):
            guard role == .host, report.playerID == opponentProfile?.id else { return }
            storeReport(report)

        case .roundResult(let result):
            guard role == .joiner else { return }
            apply(result: result)

        case .rematchRequest(let playerID, _):
            guard playerID == opponentProfile?.id else { return }
            rematch.vote(playerID: playerID)
            opponentWantsRematch = true
            if role == .host { checkRematchGate() }

        case .leaveGame:
            handlePeerLost(reason: "Your opponent left the game.")

        case .syncPing(let id, let senderTime):
            // Answer instantly with our (host) monotonic clock.
            link.send(.syncPong(id: id, senderTime: senderTime,
                                hostTime: MonotonicClock.now))

        case .syncPong(_, let senderTime, let hostTime):
            clockSync.addExchange(pingSentAt: senderTime,
                                  hostTime: hostTime,
                                  pongReceivedAt: MonotonicClock.now)
            diagnostics.syncOffsetMs = clockSync.offset * 1000
            diagnostics.syncErrorMs = clockSync.estimatedError.map { $0 * 1000 }
        }
    }

    private func handlePeerLost(reason: String) {
        guard phase != .home else { return }
        cancelAllScheduledWork()
        detector.reset()
        motion.stop()
        UIApplication.shared.isIdleTimerDisabled = false
        disconnectReason = reason
        setPhase(.disconnected)
        link.disconnect()
    }

    // MARK: - Motion pipeline

    private func handleSample(_ sample: MotionSample) {
        // Calibration capture.
        if phase == .calibrating, let session = calibrationSession {
            session.add(sample)
            calibrationProgress = session.progress
            if session.isComplete {
                finishCalibration(session.finish())
            }
        }

        // Round monitoring.
        if phase == .countdown || phase == .armed {
            if let event = detector.process(sample) {
                switch event {
                case .drawConfirmed(let at, let peak, let tilt):
                    if let drawAt = localDrawAt {
                        handleLocalDraw(elapsed: at - drawAt,
                                        peakRotation: peak, tilt: tilt)
                    }
                case .falseStart:
                    handleLocalFalseStart()
                case .movementStarted, .returnedToHolster:
                    break
                }
            }
        }

        updateDiagnostics(with: sample)
    }

    // MARK: - Clock sync

    /// Joiner: burst of pings to (re)estimate the host clock offset. Runs at
    /// the start of every positioning phase so each round gets fresh data.
    private func runClockSyncBurst() {
        for i in 0..<GameTuning.clockSyncPingCount {
            schedule(after: Double(i) * GameTuning.clockSyncPingInterval) { [weak self] in
                guard let self else { return }
                self.link.send(.syncPing(id: i, senderTime: MonotonicClock.now))
            }
        }
    }

    // MARK: - Scheduling helpers (monotonic)

    private func schedule(at monotonicTime: TimeInterval, _ block: @escaping () -> Void) {
        schedule(after: monotonicTime - MonotonicClock.now, block)
    }

    private func schedule(after delay: TimeInterval, _ block: @escaping () -> Void) {
        let item = DispatchWorkItem(block: block)
        scheduledWork.append(item)
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0, delay), execute: item)
    }

    private func cancelAllScheduledWork() {
        scheduledWork.forEach { $0.cancel() }
        scheduledWork.removeAll()
    }

    /// After a local false start the countdown display must stop, but host
    /// resolution timers keep running; cancelling everything is fine here
    /// because the false-start path re-arms its own settle timer via
    /// storeReport, and the joiner just waits for the host's result.
    private func cancelCountdownDisplay() {
        cancelAllScheduledWork()
    }

    // MARK: - Reset

    private func resetToHome() {
        cancelAllScheduledWork()
        link.disconnect()
        motion.stop()
        detector.reset()
        clockSync.reset()
        UIApplication.shared.isIdleTimerDisabled = false

        roundGate.endRound()
        rematch.reset()
        calibrationGate.reset()
        positionVotes = []
        hostReports = [:]
        currentPlan = nil
        localDrawAt = nil
        calibrationSession = nil
        calibrationData = nil

        discoveredPeers = []
        opponentProfile = nil
        connectingPeerName = nil
        localReady = false
        opponentReady = false
        localCalibrated = false
        opponentCalibrated = false
        localPositionConfirmed = false
        opponentPositionConfirmed = false
        latestResult = nil
        localFalseStarted = false
        localDrawElapsed = nil
        calibrationRunning = false
        calibrationProgress = 0
        calibrationFailure = nil
        rematchVotedLocally = false
        opponentWantsRematch = false
        disconnectReason = nil

        #if DEBUG
        if isSimulated {
            isSimulated = false
            link = PeerConnectionService()
            wireLink()
        }
        #endif
        setPhase(.home)
    }

    private func setPhase(_ newPhase: GamePhase) {
        phase = newPhase
        diagnostics.phase = String(describing: newPhase)
        diagnostics.connection = link.isConnected ? "connected" : "not connected"
        diagnostics.roundID = roundGate.currentRoundID.map { String($0.uuidString.prefix(8)) } ?? "—"
    }

    // MARK: - Diagnostics

    private func updateDiagnostics(with sample: MotionSample) {
        guard settings.diagnosticsEnabled else { return }
        let now = MonotonicClock.now
        guard now - lastDiagnosticsUpdate > 0.15 else { return }
        lastDiagnosticsUpdate = now
        diagnostics.samplingHz = motion.updateInterval > 0 ? 1.0 / motion.updateInterval : 0
        diagnostics.tilt = detector.lastTilt
        diagnostics.rotationMagnitude = detector.lastRotationMagnitude
        diagnostics.accelerationMagnitude = detector.lastAccelerationMagnitude
        diagnostics.pitchDelta = calibrationData.map { sample.pitch - $0.restingPitch } ?? 0
        diagnostics.detectorState = detector.state.rawValue
        let c = detector.configuration
        diagnostics.thresholds = String(format: "tilt %.2f rot %.1f acc %.2f",
                                        c.confirmTiltAngle, c.confirmMinRotationPeak,
                                        c.startAcceleration)
    }

    private func updateDiagnosticsDetection(_ text: String) {
        diagnostics.lastDetection = text
    }

    // MARK: - DEBUG simulation controls

    #if DEBUG
    /// Home screen: practice the full flow against the scripted opponent.
    func startPracticeVsSimulatedOpponent() {
        isSimulated = true
        let simLink = SimulatedPeerLink()
        link = simLink
        wireLink()
        role = .host
        setPhase(.hosting)
        link.startHosting(displayName: settings.displayName)
    }

    /// Armed screen: fake a valid local draw (simulator has no sensors).
    func debugTriggerDraw() {
        guard phase == .armed else { return }
        handleLocalDraw(elapsed: TimeInterval.random(in: 0.28...0.55),
                        peakRotation: 4.2, tilt: 1.2)
    }

    /// Countdown screen: fake a local false start.
    func debugTriggerFalseStart() {
        guard phase == .countdown else { return }
        handleLocalFalseStart()
    }

    /// Simulate the opponent dropping the connection.
    func debugForceDisconnect() {
        if let sim = link as? SimulatedPeerLink {
            sim.forceDisconnect()
        } else {
            handlePeerLost(reason: "Connection to your opponent was lost.")
        }
    }
    #endif
}
