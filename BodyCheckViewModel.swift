import Foundation
@preconcurrency import AVFoundation
import Vision
import CoreGraphics

@MainActor
class BodyCheckViewModel: NSObject, ObservableObject {

    // ===== カメラ =====
    let session = AVCaptureSession()
    @Published var cameraErrorMessage: String?
    private var isSessionConfigured = false
    private let cameraQueue = DispatchQueue(label: "BodyCheck.camera.queue")

    // ===== ポーズ =====
    private let practiceSet: [GamePose] = [.armsUp, .armsOut, .rightArmUp, .leftArmUp,
                                            .tPose, .jumpingJack, .squat, .rightLegUp, .leftLegUp]
    @Published var currentPoseIndex: Int = 0

    var currentPose: GamePose { practiceSet[currentPoseIndex] }

    // ===== スケルトン（UI表示用） =====
    @Published var joints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]

    // ===== スコア =====
    @Published var score: Int = 0
    @Published var combo: Int = 0

    // ===== タイマー =====
    @Published var timeRemaining: Int = 15
    var timer: Timer?

    // ===== 演出 =====
    @Published var showClearEffect: Bool = false
    @Published var showGameClear: Bool = false

    // ===== クリア判定用連続フレーム =====
    nonisolated(unsafe) private var holdFrameCount: Int = 0
    private let requiredHoldFrames: Int = 8
    nonisolated(unsafe) private var isMovingToNextPose = false
    nonisolated(unsafe) private var currentPoseForCapture: GamePose = .armsUp  // captureOutput用キャッシュ

    // MARK: - 初期化
    override init() {
        super.init()
        currentPoseForCapture = practiceSet[0]
        Task { @MainActor [weak self] in
            await self?.prepareCamera()
        }
        startTimer()
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard let self else { return }
            SoundPlayer.shared.playChangeSound()
            SoundPlayer.shared.speakPoseSequence([
                "Practice Mode!",
                self.currentPose.announcement
            ])
        }
    }

    private func prepareCamera() async {
        let isAuthorized = await ensureCameraAuthorization()
        guard isAuthorized else {
            cameraErrorMessage = "Camera access is denied. Allow camera access in Settings."
            return
        }
        guard setupCameraIfNeeded() else { return }
        if !session.isRunning {
            let captureSession = session
            cameraQueue.async { captureSession.startRunning() }
        }
    }

    // MARK: - カメラ設定
    private func setupCameraIfNeeded() -> Bool {
        if isSessionConfigured { return true }

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
            ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            ?? AVCaptureDevice.default(for: .video) else {
            cameraErrorMessage = "No camera device is available on this runtime."
            return false
        }
        guard let input = try? AVCaptureDeviceInput(device: device) else {
            cameraErrorMessage = "Failed to create camera input."
            return false
        }
        guard session.canAddInput(input) else {
            cameraErrorMessage = "Cannot add camera input to session."
            return false
        }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: cameraQueue)
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.alwaysDiscardsLateVideoFrames = true

        guard session.canAddOutput(output) else {
            cameraErrorMessage = "Cannot add camera output to session."
            return false
        }
        session.addOutput(output)

        if let connection = output.connection(with: .video) {
            if connection.isVideoOrientationSupported { connection.videoOrientation = .portrait }
            if connection.isVideoMirroringSupported && device.position == .front {
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

    // MARK: - タイマー
    func startTimer() {
        timeRemaining = 15
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.timeRemaining -= 1
                if self.timeRemaining <= 0 {
                    self.failPose()
                }
            }
        }
    }

    func failPose() {
        holdFrameCount = 0
        isMovingToNextPose = false
        combo = 0
        score = 0
        startTimer()
    }

    // MARK: - 次ポーズへ
    func goToNextPose() {
        timer?.invalidate()
        holdFrameCount = 0
        isMovingToNextPose = false

        SoundPlayer.shared.playChangeSound()

        if currentPoseIndex < practiceSet.count - 1 {
            currentPoseIndex += 1
            currentPoseForCapture = practiceSet[currentPoseIndex]
            score = 0
            startTimer()
            let pose = currentPose
            SoundPlayer.shared.speakPose(pose.announcement)
        } else {
            showGameClear = true
        }
    }

    // MARK: - リスタート
    func restartGame() {
        currentPoseIndex = 0
        currentPoseForCapture = practiceSet[0]
        score = 0
        combo = 0
        holdFrameCount = 0
        isMovingToNextPose = false
        showGameClear = false
        startTimer()
        SoundPlayer.shared.playChangeSound()
        SoundPlayer.shared.speakPose(currentPose.announcement)
    }
}

// MARK: - Camera delegate
extension BodyCheckViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {

    nonisolated func captureOutput(_ output: AVCaptureOutput,
                                   didOutput sampleBuffer: CMSampleBuffer,
                                   from connection: AVCaptureConnection) {
        if isMovingToNextPose { return }

        let estimator = PoseEstimator()
        let imageOrientation: CGImagePropertyOrientation = connection.isVideoMirrored ? .upMirrored : .up
        let jointNames: [VNHumanBodyPoseObservation.JointName] = [
            .nose, .neck, .leftShoulder, .rightShoulder, .leftElbow, .rightElbow,
            .leftWrist, .rightWrist, .leftHip, .rightHip, .leftKnee, .rightKnee,
            .leftAnkle, .rightAnkle
        ]

        estimator.process(sampleBuffer: sampleBuffer, orientation: imageOrientation) { [weak self] observation in
            guard let self, let observation = observation else { return }

            // 関節を抽出
            var extractedJoints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
            for joint in jointNames {
                guard let p = try? observation.recognizedPoint(joint), p.confidence > 0.3 else { continue }
                extractedJoints[joint] = CGPoint(x: p.location.x, y: 1 - p.location.y)
            }

            // GamePose.calculateScore（X反転済み）でスコア計算
            let poseScore = self.currentPoseForCapture.calculateScore(observation: observation)

            // 連続フレームキープ判定
            if poseScore >= self.currentPoseForCapture.clearThreshold {
                self.holdFrameCount += 1
            } else {
                self.holdFrameCount = 0
            }
            let didClear = self.holdFrameCount >= self.requiredHoldFrames

            Task { @MainActor in
                self.joints = extractedJoints
                self.score = poseScore

                if didClear && !self.isMovingToNextPose {
                    self.isMovingToNextPose = true
                    self.holdFrameCount = 0
                    self.combo += 1
                    self.showClearEffect = true

                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 700_000_000)
                        self.showClearEffect = false
                        self.goToNextPose()
                    }
                }
            }
        }
    }
}

