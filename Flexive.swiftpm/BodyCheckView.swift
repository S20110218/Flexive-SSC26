import SwiftUI
import Vision

struct BodyCheckView: View {

    @StateObject var viewModel = BodyCheckViewModel()

    var body: some View {
        ZStack {
            // ── 完全黒背景（カメラを完全に隠す）──
            Color.black.ignoresSafeArea()

            // ── ゲームと同じ背景オーバーレイ ──
            GameBackgroundView()
                .ignoresSafeArea()

            // ── スケルトン（ユーザー＋お手本）──
            GeometryReader { geo in
                let topSafe: CGFloat    = 160
                let bottomSafe: CGFloat = 180
                let safeH = geo.size.height - topSafe - bottomSafe

                // お手本をX反転＋表示領域にリマップ
                let remappedTarget = remapJoints(
                    viewModel.currentPose.targetJoints,
                    frameHeight: geo.size.height,
                    topSafe: topSafe,
                    bottomSafe: bottomSafe
                )

                DualSkeletonOverlayView(
                    userJoints:   viewModel.joints,
                    targetJoints: remappedTarget,
                    score: Double(viewModel.score) / 100.0
                )
                .frame(width: geo.size.width, height: safeH)
                .offset(y: topSafe)
                .clipped()
            }
            .ignoresSafeArea()

            // ── メインUI ──
            VStack(spacing: 0) {

                // ━━ 上段ヘッダー ━━
                HStack(alignment: .center, spacing: 10) {

                    // スコア（左）
                    VStack(spacing: 3) {
                        HStack(spacing: 3) {
                            Image(systemName: "figure.walk")
                                .font(.system(size: 9))
                                .foregroundColor(.cyan.opacity(0.8))
                            Text("PRACTICE")
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(.cyan.opacity(0.8))
                                .kerning(1.2)
                        }
                        Text("\(viewModel.combo)")
                            .font(.system(size: 34, weight: .black, design: .rounded))
                            .foregroundColor(.cyan)
                            .shadow(color: .cyan.opacity(0.6), radius: 6)
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: viewModel.combo)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.black.opacity(0.6))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.cyan.opacity(0.3), lineWidth: 1.5))
                    )

                    // 中央：ポーズ名＋残り時間
                    VStack(spacing: 4) {
                        Text(viewModel.currentPose.rawValue)
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                        Text(viewModel.currentPose.description)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text("\(viewModel.timeRemaining)s")
                            .font(.system(size: 20, weight: .black, design: .monospaced))
                            .foregroundColor(viewModel.timeRemaining <= 5 ? .red : .white)
                            .shadow(color: viewModel.timeRemaining <= 5 ? .red.opacity(0.8) : .clear, radius: 6)
                    }
                    .frame(maxWidth: .infinity)

                    // スコア（右）
                    VStack(spacing: 3) {
                        HStack(spacing: 3) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 9))
                                .foregroundColor(.yellow.opacity(0.8))
                            Text("SCORE")
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(.yellow.opacity(0.8))
                                .kerning(1.2)
                        }
                        Text("\(viewModel.score)")
                            .font(.system(size: 34, weight: .black, design: .rounded))
                            .foregroundColor(.yellow)
                            .shadow(color: .yellow.opacity(0.6), radius: 6)
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: viewModel.score)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.black.opacity(0.6))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.yellow.opacity(0.3), lineWidth: 1.5))
                    )
                }
                .padding(.horizontal, 14)
                .padding(.top, 56)

                Spacer()

                // ━━ 下部：スコアゲージ ━━
                PoseScoreGauge(
                    score: viewModel.score,
                    combo: viewModel.combo,
                    comboMessage: viewModel.combo >= 2 ? "🔥 \(viewModel.combo) Combo!" : ""
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 6)

                // ━━ ボタン ━━
                HStack(spacing: 10) {
                    Button(action: { viewModel.restartGame() }) {
                        Label("Restart", systemImage: "arrow.clockwise")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .buttonStyle(.borderedProminent).tint(.blue)
                }
                .padding(.bottom, 38)
            }

            // ── CLEAR エフェクト ──
            if viewModel.showClearEffect {
                Text("CLEAR! 🎉")
                    .font(.system(size: 58, weight: .black, design: .rounded))
                    .foregroundColor(Color(red: 0.2, green: 1, blue: 0.5))
                    .shadow(color: .green.opacity(0.7), radius: 20)
                    .transition(.scale(scale: 0.5).combined(with: .opacity))
            }

            // ── 全ポーズ完了 ──
            if viewModel.showGameClear {
                ZStack {
                    Color.black.opacity(0.7).ignoresSafeArea()
                    VStack(spacing: 24) {
                        Text("🎉")
                            .font(.system(size: 70))
                        Text("Practice Complete!")
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        Text("Combos: \(viewModel.combo)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.yellow)
                        Button(action: { viewModel.restartGame() }) {
                            Text("Play Again")
                                .font(.system(size: 18, weight: .black))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
                                .cornerRadius(16)
                        }
                        .padding(.horizontal, 40)
                    }
                }
            }

            // ── カメラエラー ──
            if let msg = viewModel.cameraErrorMessage {
                VStack(spacing: 8) {
                    Text("Camera Unavailable").font(.headline).foregroundColor(.white)
                    Text(msg).font(.subheadline).multilineTextAlignment(.center).foregroundColor(.white.opacity(0.9))
                }
                .padding(16).background(Color.black.opacity(0.8)).cornerRadius(14).padding()
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: viewModel.showClearEffect)
        .animation(.easeInOut, value: viewModel.showGameClear)
    }

    private func remapJoints(
        _ joints: [VNHumanBodyPoseObservation.JointName: CGPoint],
        frameHeight: CGFloat,
        topSafe: CGFloat,
        bottomSafe: CGFloat
    ) -> [VNHumanBodyPoseObservation.JointName: CGPoint] {
        let margin: CGFloat = 0.02
        return joints.mapValues { pt in
            CGPoint(x: pt.x, y: margin + pt.y * (1.0 - margin * 2))
        }
    }
}


