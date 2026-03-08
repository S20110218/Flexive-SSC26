import Foundation
@preconcurrency import AVFoundation
import Vision
import SwiftUI
import UIKit

@MainActor
class GameViewModel: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {

    // ===== Camera =====
    let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let captureQueue = DispatchQueue(label: "camera.capture.queue")
    nonisolated(unsafe) private let poseRequest = VNDetectHumanBodyPoseRequest()
    nonisolated(unsafe) private let estimator = PoseEstimator()

    // ===== Game State =====
    @Published var totalScore: Int = 0
    @Published var clearCount: Int = 0
    @Published var combo: Int = 0
    @Published var maxCombo: Int = 0
    @Published var poseTimeRemaining: Int = 10
    @Published var gameEnded: Bool = false
    @Published var currentPose: GamePose = .armsUp
    @Published var joints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
    @Published var currentPoseScore: Int = 0
    @Published var isNextPoseButtonEnabled: Bool = false
    @Published var isBossPhase: Bool = false
    @Published var currentBossPose: GamePose? = nil
    @Published var cameraErrorMessage: String?
    @Published var showClearEffect: Bool = false
    @Published var clearMessage: String = ""
    @Published var showMiss: Bool = false
    @Published var comboMessage: String = ""
    @Published var difficulty: Difficulty = .normal
    @Published var gameMode: GameMode = .endless
    @Published var timeAttackRemaining: Int = 60
    @Published var countdownValue: Int = 0
    @Published var isCountingDown: Bool = false
    @Published var isNewHighScore: Bool = false

    // ── Level System ──
    // Lv1: Clears 0-3  → Lv1 poses only
    // Lv2: Clears 4-9  → Lv1 + Lv2 poses
    // Lv3: Clears 10+  → All poses
    @Published var currentLevel: Int = 1
    @Published var showLevelUp: Bool = false

    private let clearThreshold: Int = 65       // 65点以上でクリア対象
    private let bossScoreThreshold: Int = 82
    private let requiredHoldFrames: Int = 6    // 約0.4秒間キープで確定
    nonisolated(unsafe) private var holdFrameCount: Int = 0  // 連続高スコアフレーム数

    // ✅ ハプティクスジェネレーター
    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
    private let heavyFeedback = UIImpactFeedbackGenerator(style: .heavy)

    // ✅ 難易度定義
    enum Difficulty: String, CaseIterable {
        case easy = "Easy"
        case normal = "Normal"
        case hard = "Hard"

        var poseTime: Int {
            switch self {
            case .easy: return 15
            case .normal: return 10
            case .hard: return 5
            }
        }
    }

    // ✅ ゲームモード定義
    enum GameMode: String, CaseIterable {
        case endless = "Endless"
        case timeAttack = "Time Attack (60s)"
    }

    nonisolated(unsafe) private var isCheckingPose = false
    nonisolated(unsafe) private var currentPoseForCapture: GamePose = .armsUp
    nonisolated(unsafe) private var isMovingToNextPose = false  // 次ポーズへの移行中フラグ
    private var isSessionConfigured = false
    private var poseTimer: Timer?
    private var timeAttackTimer: Timer?

    // ===== Init =====
    override init() {
        super.init()
        impactFeedback.prepare()
        heavyFeedback.prepare()
    }

    // ===== Camera Setup =====
    private func setupCameraIfNeeded() -> Bool {
        if isSessionConfigured { return true }

        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }
        captureSession.sessionPreset = .high

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
            ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            ?? AVCaptureDevice.default(for: .video) else {
            cameraErrorMessage = "No camera device is available on this runtime."
            return false
        }

        guard let input = try? AVCaptureDeviceInput(device: device),
              captureSession.canAddInput(input) else {
            cameraErrorMessage = "Failed to configure camera input."
            return false
        }
        captureSession.addInput(input)

        guard captureSession.canAddOutput(videoOutput) else {
            cameraErrorMessage = "Failed to configure camera output."
            return false
        }
        videoOutput.setSampleBufferDelegate(self, queue: captureQueue)
        captureSession.addOutput(videoOutput)

        if let connection = videoOutput.connection(with: .video) {
            if connection.isVideoOrientationSupported { connection.videoOrientation = .portrait }
            if connection.isVideoMirroringSupported && device.position == .front {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = true
            }
            if connection.isVideoStabilizationSupported {
                connection.preferredVideoStabilizationMode = .standard
            }
        }

        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]

        isSessionConfigured = true
        cameraErrorMessage = nil
        return true
    }

    // ===== Game Control =====
    func startGame() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let isAuthorized = await self.ensureCameraAuthorization()
            guard isAuthorized else {
                self.cameraErrorMessage = "Camera access is denied. Allow camera access in Settings."
                return
            }
            guard self.setupCameraIfNeeded() else { return }

            if !self.captureSession.isRunning {
                let session = self.captureSession
                self.captureQueue.async { session.startRunning() }
            }

            // ✅ カウントダウン開始
            await self.runCountdown()

            self.isBossPhase = false
            self.currentBossPose = nil
            self.startTimers()
            self.selectRandomPose()
            self.isNextPoseButtonEnabled = false
            self.cameraErrorMessage = nil
        }
    }

    // ✅ 3・2・1・GO! カウントダウン
    private func runCountdown() async {
        isCountingDown = true
        let pitches: [Float] = [440, 660, 880]  // 3→低、2→中、1→高
        for (idx, i) in stride(from: 3, through: 1, by: -1).enumerated() {
            countdownValue = i
            impactFeedback.impactOccurred()
            SoundPlayer.shared.playCountdownBeep(pitch: pitches[idx], duration: 0.15)
            try? await Task.sleep(nanoseconds: 900_000_000)
        }
        countdownValue = 0  // "GO!" は View 側で0を判定
        heavyFeedback.impactOccurred()
        SoundPlayer.shared.playGoSound()
        try? await Task.sleep(nanoseconds: 700_000_000)
        isCountingDown = false
    }

    func stopGame() {
        let session = captureSession
        captureQueue.async { session.stopRunning() }
        poseTimer?.invalidate()
        timeAttackTimer?.invalidate()

        // ✅ ハイスコア判定
        let previousBest = UserDefaults.standard.integer(forKey: "highScore")
        if totalScore > previousBest {
            UserDefaults.standard.set(totalScore, forKey: "highScore")
            isNewHighScore = true
        }
        gameEnded = true
    }

    func resetGame() {
        totalScore = 0
        clearCount = 0
        combo = 0
        maxCombo = 0
        currentLevel = 1
        poseTimeRemaining = difficulty.poseTime
        timeAttackRemaining = 60
        gameEnded = false
        isBossPhase = false
        currentBossPose = nil
        isNextPoseButtonEnabled = false
        isNewHighScore = false
        clearMessage = ""
        showMiss = false
        comboMessage = ""
        startGame()
    }

    var highScore: Int { UserDefaults.standard.integer(forKey: "highScore") }

    // ===== Timer =====
    private func startTimers() {
        poseTimer?.invalidate()
        poseTimeRemaining = difficulty.poseTime

        poseTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.poseTimeRemaining -= 1
                // 残り3・2・1でビープ音
                if self.poseTimeRemaining == 3 {
                    SoundPlayer.shared.playCountdownBeep(pitch: 440, duration: 0.12)
                } else if self.poseTimeRemaining == 2 {
                    SoundPlayer.shared.playCountdownBeep(pitch: 660, duration: 0.12)
                } else if self.poseTimeRemaining == 1 {
                    SoundPlayer.shared.playCountdownBeep(pitch: 880, duration: 0.12)
                }
                if self.poseTimeRemaining <= 0 {
                    self.combo = 0
                    self.comboMessage = ""
                    self.holdFrameCount = 0
                    self.isMovingToNextPose = false
                    // MISS display
                    self.showMiss = true
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 900_000_000)
                        self.showMiss = false
                    }
                    self.selectRandomPose()
                    self.poseTimeRemaining = self.difficulty.poseTime
                }
            }
        }

        // ✅ タイムアタックタイマー
        if gameMode == .timeAttack {
            timeAttackRemaining = 60
            timeAttackTimer?.invalidate()
            timeAttackTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in
                    self.timeAttackRemaining -= 1
                    if self.timeAttackRemaining <= 0 {
                        self.stopGame()
                    }
                }
            }
        }
    }

    // ===== Pose =====
    private func selectRandomPose() {
        holdFrameCount = 0
        // ポーズ切り替え直後は1.5秒間クリア判定をブロック
        isMovingToNextPose = true

        if let bossPose = currentBossPose {
            currentPose = bossPose
        } else {
            let available = GamePose.allCases.filter { $0.level <= currentLevel }
            let candidates = available.count > 1 ? available.filter { $0 != currentPose } : available
            currentPose = candidates.randomElement() ?? .armsUp
        }
        currentPoseForCapture = currentPose
        isCheckingPose = false

        let pose = currentPose
        SoundPlayer.shared.playChangeSound()
        SoundPlayer.shared.speakPose(pose.announcement)

        // 1.5秒後にクリア判定を再開（DispatchQueueで安全に）
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.isMovingToNextPose = false
            self?.holdFrameCount = 0
        }
    }

    // クリア数に応じてレベルを更新
    private func checkLevelUp() {
        let newLevel: Int
        switch clearCount {
        case 0..<4:  newLevel = 1   // Lv1: Clears 0-3  → Easy poses only
        case 4..<10: newLevel = 2   // Lv2: Clears 4-9  → Normal poses added
        default:     newLevel = 3   // Lv3: Clears 10+  → Hard poses unlocked
        }
        if newLevel > currentLevel {
            currentLevel = newLevel
            showLevelUp = true
            heavyFeedback.impactOccurred()
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_800_000_000)
                self.showLevelUp = false
            }
        }
    }

    // ===== Boss =====
    private func enterBossPhase(with pose: GamePose? = nil) {
        isBossPhase = true
        currentBossPose = pose ?? currentPose
        poseTimeRemaining = difficulty.poseTime
        selectRandomPose()
    }

    // ✅ コンボメッセージ生成
    private func updateComboMessage(_ newCombo: Int) {
        guard newCombo >= 2 else { comboMessage = ""; return }
        let excl = String(repeating: "!", count: min(newCombo / 3 + 1, 5))
        let emoji: String
        switch newCombo {
        case 2..<5:   emoji = "🔥"
        case 5..<10:  emoji = "⚡"
        case 10..<20: emoji = "💥"
        default:      emoji = "🌟"
        }
        comboMessage = "\(emoji) \(newCombo) COMBO\(excl)"
    }

    private func ensureCameraAuthorization() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    continuation.resume(returning: granted)
                }
            }
        case .denied, .restricted: return false
        @unknown default: return false
        }
    }

    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if isCheckingPose { return }
        if isMovingToNextPose { return }   // 次ポーズ移行中は判定しない
        isCheckingPose = true

        let pose = currentPoseForCapture
        let jointNames: [VNHumanBodyPoseObservation.JointName] = [
            .nose, .neck, .leftShoulder, .rightShoulder, .leftElbow, .rightElbow,
            .leftWrist, .rightWrist, .leftHip, .rightHip, .leftKnee, .rightKnee,
            .leftAnkle, .rightAnkle
        ]
        let imageOrientation: CGImagePropertyOrientation = connection.isVideoMirrored ? .upMirrored : .up

        estimator.process(sampleBuffer: sampleBuffer, orientation: imageOrientation) { [weak self] observation in
            guard let self = self, let observation = observation else {
                self?.isCheckingPose = false
                return
            }

            let score = pose.calculateScore(observation: observation)
            var extractedJoints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
            for joint in jointNames {
                guard let p = try? observation.recognizedPoint(joint), p.confidence > 0.3 else { continue }
                extractedJoints[joint] = CGPoint(x: p.location.x, y: 1 - p.location.y)
            }

            // 連続フレームカウント更新（メインスレッド外で安全にアクセス）
            let threshold = pose.clearThreshold
            if score >= threshold {
                self.holdFrameCount += 1
            } else {
                self.holdFrameCount = 0
            }
            let didHold = self.holdFrameCount >= self.requiredHoldFrames

            Task { @MainActor in
                self.joints = extractedJoints
                self.currentPoseScore = score

                // 連続キープ達成でクリア
                if didHold && !self.isMovingToNextPose {
                    self.isMovingToNextPose = true
                    self.holdFrameCount = 0

                    // コンボ加算＆スコア
                    self.combo += 1
                    if self.combo > self.maxCombo { self.maxCombo = self.combo }
                    let comboBonus = self.combo >= 3 ? (self.combo - 2) * 5 : 0
                    self.totalScore += score + comboBonus
                    self.clearCount += 1
                    self.checkLevelUp()
                    self.updateComboMessage(self.combo)
                    self.impactFeedback.impactOccurred()

                    self.clearMessage = score >= 90 ? "PERFECT! 🌟" : score >= 75 ? "GREAT! 🔥" : "NICE! 👍"
                    self.showClearEffect = true

                    // クリア音（ok.m4a の代わりに change.mp3 を使用）
                    SoundPlayer.shared.playChangeSound()

                    // クリアエフェクト表示中に次ポーズの読み上げを開始
                    // 読み上げ完了後（約2秒）にポーズ切り替え
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 800_000_000)
                        self.showClearEffect = false
                        self.clearMessage = ""
                    }

                    if score >= self.bossScoreThreshold && !self.isBossPhase {
                        self.heavyFeedback.impactOccurred()
                        // 読み上げ待ち（2.2秒）してからボスフェーズへ
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 1_400_000_000)
                            self.enterBossPhase(with: self.currentPose)
                            self.isNextPoseButtonEnabled = false
                        }
                    } else if self.isBossPhase {
                        self.isBossPhase = false
                        self.currentBossPose = nil
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 1_400_000_000)
                            self.selectRandomPose()
                            self.isNextPoseButtonEnabled = false
                            self.poseTimeRemaining = self.difficulty.poseTime
                        }
                    } else {
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 1_400_000_000)
                            self.selectRandomPose()
                            self.isNextPoseButtonEnabled = false
                            self.poseTimeRemaining = self.difficulty.poseTime
                        }
                    }
                }

                self.isCheckingPose = false
            }
        }
    }
}
