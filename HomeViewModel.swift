import Foundation
@preconcurrency import AVFoundation
import Vision
import Combine
import SwiftUI

@MainActor
class HomeViewModel: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {

    // MARK: - Published
    @Published var userJoints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
    @Published var currentPoseTemplate: PoseTemplate
    @Published var score: Double = 0.0
    @Published var isCameraActive = false
    @Published var cameraErrorMessage: String?

    // MARK: - Camera
    let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let videoQueue = DispatchQueue(label: "HomeVideoQueue", qos: .userInteractive)
    private var isSessionConfigured = false

    // MARK: - Pose / Auto-advance
    private let defaultAutoAdvanceThreshold: Double = 0.50
    private let jumpingJackAutoAdvanceThreshold: Double = 0.40
    private let autoAdvanceDelay: TimeInterval = 1.0
    private var autoAdvanceCooldownUntil: Date = .distantPast
    private var pendingAutoAdvanceTask: Task<Void, Never>?
    private var pendingAutoAdvancePoseName: String?

    // MARK: - フリーズ対策：フレームスロットリング
    // captureOutput は毎秒30フレーム飛んでくる。
    // 毎フレーム Task { @MainActor } を生成するとキューが詰まりフリーズする。
    // → 最低 frameInterval 秒に1回だけ処理する。
    nonisolated(unsafe) private var lastProcessedTime: Date = .distantPast
    private let frameInterval: TimeInterval = 1.0 / 15  // 15fps に間引く
    nonisolated(unsafe) private var isProcessingFrame = false

    nonisolated(unsafe) private let poseEstimator = PoseEstimator()
    nonisolated private let poseRepository = PoseTemplateRepository.shared
    nonisolated(unsafe) private var currentPoseTemplateForCapture: PoseTemplate

    override init() {
        let initial = poseRepository.random()
        self.currentPoseTemplate = initial
        self.currentPoseTemplateForCapture = initial
        super.init()
    }

    // MARK: - Public

    func startSession() {
        Task { @MainActor [weak self] in
            guard let self else { return }

            let authorized = await self.ensureCameraAuthorization()
            guard authorized else {
                self.cameraErrorMessage = "Camera access is denied. Allow camera access in Settings."
                self.isCameraActive = false
                return
            }
            guard self.setupCameraIfNeeded() else {
                self.isCameraActive = false
                return
            }
            guard !self.captureSession.isRunning else {
                self.cameraErrorMessage = nil
                self.isCameraActive = true
                return
            }

            let session = self.captureSession
            self.videoQueue.async { [weak self] in
                session.startRunning()
                DispatchQueue.main.async {
                    self?.isCameraActive = session.isRunning
                    if !session.isRunning {
                        self?.cameraErrorMessage = "Failed to start camera session."
                    } else {
                        self?.cameraErrorMessage = nil
                    }
                }
            }
        }
    }

    func stopSession() {
        pendingAutoAdvanceTask?.cancel()
        pendingAutoAdvanceTask = nil
        pendingAutoAdvancePoseName = nil

        guard captureSession.isRunning else {
            isCameraActive = false
            return
        }
        let session = captureSession
        videoQueue.async { [weak self] in
            session.stopRunning()
            DispatchQueue.main.async { self?.isCameraActive = false }
        }
    }

    /// セッションが詰まっている場合の強制リセット
    func restartSessionIfNeeded() {
        guard isCameraActive else { return }
        let session = captureSession
        videoQueue.async { [weak self] in
            if session.isRunning {
                session.stopRunning()
                Thread.sleep(forTimeInterval: 0.3)
            }
            session.startRunning()
            DispatchQueue.main.async {
                self?.isCameraActive = session.isRunning
            }
        }
    }

    func loadNextPose(playSound: Bool = true, detectionCooldown: TimeInterval = 0.35) {
        pendingAutoAdvanceTask?.cancel()
        pendingAutoAdvanceTask = nil
        pendingAutoAdvancePoseName = nil

        let next = poseRepository.random(excludingName: currentPoseTemplate.name)
        self.currentPoseTemplate = next
        self.currentPoseTemplateForCapture = next
        self.score = 0.0
        self.autoAdvanceCooldownUntil = Date().addingTimeInterval(detectionCooldown)

        if playSound {
            SoundPlayer.shared.playChangeSound()
            SoundPlayer.shared.speakPose("Next: \(next.name)!")
        }
    }

    // MARK: - Camera Setup

    private func setupCameraIfNeeded() -> Bool {
        if isSessionConfigured { return true }

        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }
        captureSession.sessionPreset = .medium   // high → medium でCPU負荷削減

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
            ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            ?? AVCaptureDevice.default(for: .video) else {
            cameraErrorMessage = "No camera device is available."
            return false
        }

        // フレームレートを15fpsに制限してCPU負荷を下げる
        try? camera.lockForConfiguration()
        camera.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 15)
        camera.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 15)
        camera.unlockForConfiguration()

        guard let input = try? AVCaptureDeviceInput(device: camera),
              captureSession.canAddInput(input) else {
            cameraErrorMessage = "Failed to configure camera input."
            return false
        }
        captureSession.addInput(input)

        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoOutput.alwaysDiscardsLateVideoFrames = true  // 遅延フレームを捨てて詰まりを防ぐ
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)

        guard captureSession.canAddOutput(videoOutput) else {
            cameraErrorMessage = "Failed to configure camera output."
            return false
        }
        captureSession.addOutput(videoOutput)

        if let connection = videoOutput.connection(with: .video) {
            if connection.isVideoOrientationSupported { connection.videoOrientation = .portrait }
            if connection.isVideoMirroringSupported && camera.position == .front {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = true
            }
        }

        isSessionConfigured = true
        cameraErrorMessage = nil
        return true
    }

    private func ensureCameraAuthorization() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .video) { continuation.resume(returning: $0) }
            }
        case .denied, .restricted: return false
        @unknown default: return false
        }
    }

    // MARK: - Auto-advance

    private func autoAdvanceThreshold(for poseName: String) -> Double {
        poseName.caseInsensitiveCompare("Jumping Jack") == .orderedSame
            ? jumpingJackAutoAdvanceThreshold : defaultAutoAdvanceThreshold
    }

    private func scheduleAutoAdvance(for poseName: String) {
        guard pendingAutoAdvanceTask == nil else { return }
        pendingAutoAdvancePoseName = poseName
        SoundPlayer.shared.playOkSound()
        autoAdvanceCooldownUntil = Date().addingTimeInterval(autoAdvanceDelay)
        let delayNanos = UInt64(autoAdvanceDelay * 1_000_000_000)
        pendingAutoAdvanceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: delayNanos)
            self?.performDelayedAutoAdvance(for: poseName)
        }
    }

    private func performDelayedAutoAdvance(for poseName: String) {
        defer { pendingAutoAdvanceTask = nil; pendingAutoAdvancePoseName = nil }
        guard pendingAutoAdvancePoseName == poseName else { return }
        // クールダウン2秒：切り替え直後のポーズで即クリアを防ぐ
        loadNextPose(playSound: true, detectionCooldown: 2.0)
    }

    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

    nonisolated func captureOutput(_ output: AVCaptureOutput,
                                   didOutput sampleBuffer: CMSampleBuffer,
                                   from connection: AVCaptureConnection) {
        // ── フリーズ対策1: 多重処理ガード ──
        guard !isProcessingFrame else { return }

        // ── フリーズ対策2: 時間間引き（15fps 相当） ──
        let now = Date()
        guard now.timeIntervalSince(lastProcessedTime) >= frameInterval else { return }

        isProcessingFrame = true
        lastProcessedTime = now

        let orientation: CGImagePropertyOrientation = connection.isVideoMirrored ? .upMirrored : .up
        let template = currentPoseTemplateForCapture

        poseEstimator.process(sampleBuffer: sampleBuffer, orientation: orientation) { [weak self] observation in
            guard let self else { self?.isProcessingFrame = false; return }

            var joints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
            let jointNames: [VNHumanBodyPoseObservation.JointName] = [
                .nose, .neck, .leftShoulder, .rightShoulder, .leftElbow, .rightElbow,
                .leftWrist, .rightWrist, .leftHip, .rightHip, .leftKnee, .rightKnee,
                .leftAnkle, .rightAnkle
            ]

            if let obs = observation {
                for joint in jointNames {
                    guard let p = try? obs.recognizedPoint(joint), p.confidence > 0.3 else { continue }
                    joints[joint] = CGPoint(x: p.location.x, y: 1 - p.location.y)
                }
            }

            let newScore = observation != nil
                ? self.poseEstimator.score(current: joints, target: template.joints)
                : 0.0

            // ── フリーズ対策3: DispatchQueue.main.async（Task より軽量） ──
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                let threshold = self.autoAdvanceThreshold(for: template.name)
                let shouldAdvance = newScore >= threshold && Date() >= self.autoAdvanceCooldownUntil

                self.userJoints = joints
                self.score = newScore

                if shouldAdvance { self.scheduleAutoAdvance(for: template.name) }
                self.isProcessingFrame = false
            }
        }
    }
}
