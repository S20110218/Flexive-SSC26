import SwiftUI
import Vision

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @State private var showGameView = false

    var body: some View {
        ZStack {
            // カメラ（姿勢検出用・表示しない）
            CameraPreview(session: viewModel.captureSession)
                .ignoresSafeArea()
                .opacity(0.001)

            // 黒背景
            Color.black.ignoresSafeArea()

            // ゲームと同じ宇宙風背景
            GameBackgroundView()
                .ignoresSafeArea()

            // スケルトン（Wii Fit風ユーザー + オレンジお手本）
            GeometryReader { geo in
                let topSafe: CGFloat    = 160
                let bottomSafe: CGFloat = 190
                let safeH = geo.size.height - topSafe - bottomSafe

                let remappedTarget = remapJoints(
                    viewModel.currentPoseTemplate.joints,
                    topSafe: topSafe, bottomSafe: bottomSafe
                )

                // ユーザー骨格もX反転（フロントカメラのミラー表示と一致させる）
                let mirroredUser = viewModel.userJoints.mapValues { pt in
                    CGPoint(x: 1.0 - pt.x, y: pt.y)
                }

                DualSkeletonOverlayView(
                    userJoints: mirroredUser,
                    targetJoints: remappedTarget,
                    score: viewModel.score
                )
                .frame(width: geo.size.width, height: safeH)
                .offset(y: topSafe)
                .clipped()
            }
            .ignoresSafeArea()

            // メインUI
            VStack(spacing: 0) {

                // ヘッダー
                HStack(spacing: 10) {
                    // ポーズ名
                    VStack(spacing: 3) {
                        Text("POSE")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(.cyan.opacity(0.8))
                            .kerning(1.5)
                        Text(viewModel.currentPoseTemplate.name)
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: .cyan.opacity(0.4), radius: 4)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.6)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.black.opacity(0.6))
                            .overlay(RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.cyan.opacity(0.3), lineWidth: 1.5))
                    )

                    // スコア
                    VStack(spacing: 3) {
                        Text("SCORE")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(.yellow.opacity(0.8))
                            .kerning(1.5)
                        Text(String(format: "%.0f", viewModel.score * 100))
                            .font(.system(size: 34, weight: .black, design: .rounded))
                            .foregroundColor(scoreColor)
                            .shadow(color: scoreColor.opacity(0.6), radius: 6)
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: viewModel.score)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.black.opacity(0.6))
                            .overlay(RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.yellow.opacity(0.3), lineWidth: 1.5))
                    )
                }
                .padding(.horizontal, 14)
                .padding(.top, 56)

                Spacer()

                // スコアゲージ（ボーダーライン付き）
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.12))
                        RoundedRectangle(cornerRadius: 6)
                            .fill(scoreColor)
                            .frame(width: geo.size.width * CGFloat(viewModel.score))
                            .animation(.easeOut(duration: 0.15), value: viewModel.score)
                        // クリアボーダーライン（65点）
                        Rectangle()
                            .fill(Color.white.opacity(0.8))
                            .frame(width: 2)
                            .offset(x: geo.size.width * 0.65)
                        Text("CLEAR")
                            .font(.system(size: 8, weight: .black))
                            .foregroundColor(.white.opacity(0.9))
                            .offset(x: geo.size.width * 0.65 - 14, y: -14)
                    }
                }
                .frame(height: 10)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

                // ボタン
                HStack(spacing: 14) {
                    Button(action: { showGameView = true }) {
                        HStack(spacing: 8) {
                            Image(systemName: "gamecontroller.fill").font(.system(size: 18))
                            Text("Game Start").font(.system(size: 20, weight: .black, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 30).padding(.vertical, 14)
                        .background(LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing))
                        .cornerRadius(28)
                        .shadow(color: .orange.opacity(0.5), radius: 10, x: 0, y: 5)
                    }

                    Button(action: { viewModel.loadNextPose() }) {
                        HStack(spacing: 6) {
                            Text("Next Pose").font(.system(size: 16, weight: .bold, design: .rounded))
                            Image(systemName: "arrow.right.circle.fill").font(.system(size: 16))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20).padding(.vertical, 14)
                        .background(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
                        .cornerRadius(28)
                        .shadow(color: .blue.opacity(0.4), radius: 8, x: 0, y: 4)
                    }
                }
                .padding(.bottom, 44)
            }

            // カメラエラー
            if let msg = viewModel.cameraErrorMessage {
                VStack(spacing: 8) {
                    Text("Camera Unavailable").font(.headline).foregroundColor(.white)
                    Text(msg).font(.subheadline).multilineTextAlignment(.center).foregroundColor(.white.opacity(0.9))
                }
                .padding(16).background(Color.black.opacity(0.8)).cornerRadius(12).padding()
            }
        }
        .onAppear {
            viewModel.startSession()
            // 1.5秒後に「Practice Mode! + 最初のポーズ名」を読み上げ
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                SoundPlayer.shared.speakPoseSequence([
                    "Practice Mode!",
                    "First pose: \(viewModel.currentPoseTemplate.name). Try to match it!"
                ])
            }
        }
        .onDisappear { viewModel.stopSession() }
        .fullScreenCover(isPresented: $showGameView) { GameView() }
    }

    private var scoreColor: Color {
        if viewModel.score >= 0.75 { return Color(red: 0.2, green: 1.0, blue: 0.4) }
        if viewModel.score >= 0.45 { return .yellow }
        return Color(red: 1, green: 0.4, blue: 0.2)
    }

    private func remapJoints(
        _ joints: [VNHumanBodyPoseObservation.JointName: CGPoint],
        topSafe: CGFloat, bottomSafe: CGFloat
    ) -> [VNHumanBodyPoseObservation.JointName: CGPoint] {
        let margin: CGFloat = 0.02
        return joints.mapValues { pt in
            CGPoint(x: 1.0 - pt.x, y: margin + pt.y * (1.0 - margin * 2))
        }
    }
}
