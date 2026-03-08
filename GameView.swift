import SwiftUI
import Vision

struct GameView: View {
    @StateObject private var viewModel = GameViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showDifficultyPicker = true

    // レベルに対応した色
    private var levelColor: Color {
        switch viewModel.currentLevel {
        case 1: return .green
        case 2: return .orange
        default: return .red
        }
    }
    private var levelLabel: String {
        switch viewModel.currentLevel {
        case 1: return "Easy"
        case 2: return "Normal"
        default: return "Hard"
        }
    }

    var body: some View {
        ZStack {
            // 完全黒背景（カメラを完全に隠す）
            Color.black.ignoresSafeArea()

            // ゲーム背景オーバーレイ
            GameBackgroundView()
                .ignoresSafeArea()

            // スケルトン（UIと被らない中央帯のみ）
            GeometryReader { geo in
                let topSafe: CGFloat    = 160
                let bottomSafe: CGFloat = 180
                let safeH = geo.size.height - topSafe - bottomSafe

                // お手本骨格のY座標をフレーム内に収まるようリマップ
                // 元の座標は画面全体(0〜1)で定義されているため、
                // 表示領域(topSafe〜geo.height-bottomSafe)に合わせてスケーリングする
                let remappedTarget = remapJoints(
                    viewModel.currentPose.targetJoints,
                    frameHeight: geo.size.height,
                    topSafe: topSafe,
                    bottomSafe: bottomSafe
                )

                DualSkeletonOverlayView(
                    userJoints:   viewModel.joints.mapValues { CGPoint(x: 1.0 - $0.x, y: $0.y) },
                    targetJoints: remappedTarget,
                    score: Double(viewModel.currentPoseScore) / 100.0
                )
                .frame(width: geo.size.width, height: safeH)
                .offset(y: topSafe)
                .clipped()
            }
            .ignoresSafeArea()

            // ── メインUI ──
            VStack(spacing: 0) {

                // ━━ 上段：スコア・クリア・中央タイマー ━━
                HStack(alignment: .center, spacing: 10) {

                    // ── スコア（左）──
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
                        Text("\(viewModel.totalScore)")
                            .font(.system(size: 34, weight: .black, design: .rounded))
                            .foregroundColor(.yellow)
                            .shadow(color: .yellow.opacity(0.6), radius: 6)
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: viewModel.totalScore)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.black.opacity(0.6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.yellow.opacity(0.3), lineWidth: 1.5)
                            )
                    )

                    // ── 中央：レベル＋ポーズ名＋残り時間 ──
                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill").foregroundColor(levelColor).font(.system(size: 11))
                            Text("Lv.\(viewModel.currentLevel)").font(.system(size: 11, weight: .black)).foregroundColor(levelColor)
                        }
                        Text(viewModel.currentPose.rawValue)
                            .font(.system(size: 14, weight: .black, design: .rounded)).foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                        Text("\(viewModel.poseTimeRemaining)s")
                            .font(.system(size: 20, weight: .black, design: .monospaced))
                            .foregroundColor(viewModel.poseTimeRemaining <= 3 ? .red : .white)
                            .shadow(color: viewModel.poseTimeRemaining <= 3 ? .red.opacity(0.8) : .clear, radius: 6)
                    }
                    .frame(maxWidth: .infinity)

                    // ── クリア数（右）──
                    VStack(spacing: 3) {
                        HStack(spacing: 3) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 9))
                                .foregroundColor(Color(red: 0.3, green: 1, blue: 0.5).opacity(0.85))
                            Text("CLEAR")
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(Color(red: 0.3, green: 1, blue: 0.5).opacity(0.85))
                                .kerning(1.2)
                        }
                        Text("\(viewModel.clearCount)")
                            .font(.system(size: 34, weight: .black, design: .rounded))
                            .foregroundColor(Color(red: 0.3, green: 1, blue: 0.5))
                            .shadow(color: Color(red: 0.3, green: 1, blue: 0.5).opacity(0.6), radius: 6)
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: viewModel.clearCount)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.black.opacity(0.6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color(red: 0.3, green: 1, blue: 0.5).opacity(0.3), lineWidth: 1.5)
                            )
                    )
                }
                .padding(.horizontal, 14)
                .padding(.top, 56)

                Spacer()

                // ━━ タイムアタック残り時間（時計型）━━
                if viewModel.gameMode == .timeAttack {
                    ClockTimerView(
                        timeRemaining: viewModel.timeAttackRemaining,
                        totalTime: 60
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 6)
                }

                // ━━ ポーズ採点（下部）━━
                PoseScoreGauge(score: viewModel.currentPoseScore, combo: viewModel.combo, comboMessage: viewModel.comboMessage)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 6)

                // ━━ ベストスコア ━━
                if viewModel.gameMode == .endless && viewModel.highScore > 0 {
                    HStack(spacing: 5) {
                        Image(systemName: "crown.fill").foregroundColor(.yellow).font(.system(size: 11))
                        Text("BEST \(viewModel.highScore)")
                            .font(.system(size: 13, weight: .black, design: .rounded)).foregroundColor(.yellow)
                    }
                    .padding(.bottom, 4)
                }

                // ━━ ボタン行 ━━
                HStack(spacing: 10) {
                    actionButton("Start", icon: "play.fill",         tint: .green)  { viewModel.startGame() }
                    actionButton("Stop",  icon: "stop.fill",          tint: .red)    { viewModel.stopGame() }
                    Button(action: { showDifficultyPicker = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "slider.horizontal.3")
                            Text(viewModel.difficulty.rawValue)
                                .font(.system(size: 13, weight: .bold))
                        }
                    }
                    .buttonStyle(.borderedProminent).tint(.purple)
                    Button(action: { dismiss() }) {
                        Image(systemName: "house.fill")
                    }
                    .buttonStyle(.borderedProminent).tint(.gray)
                }
                .padding(.bottom, 38)
            }

            // ── エフェクト類 ──

            // クリアメッセージ (NICE! / GREAT! / PERFECT!)
            if viewModel.showClearEffect {
                VStack(spacing: 0) {
                    Text(viewModel.clearMessage)
                        .font(.system(size: 58, weight: .black, design: .rounded))
                        .foregroundColor(
                            viewModel.clearMessage.contains("PERFECT") ? .yellow :
                            viewModel.clearMessage.contains("GREAT")   ? Color(red:0.2,green:1,blue:0.5) : .white
                        )
                        .shadow(color: .black.opacity(0.5), radius: 4)
                        .shadow(color: (viewModel.clearMessage.contains("PERFECT") ? Color.yellow :
                                        viewModel.clearMessage.contains("GREAT")   ? Color.green : Color.white)
                                        .opacity(0.6), radius: 20)
                }
                .transition(.scale(scale: 0.5).combined(with: .opacity))
                .id(viewModel.clearMessage)
            }

            // MISS
            if viewModel.showMiss {
                Text("MISS...")
                    .font(.system(size: 58, weight: .black, design: .rounded))
                    .foregroundColor(.red)
                    .shadow(color: .red.opacity(0.7), radius: 20)
                    .transition(.scale(scale: 0.5).combined(with: .opacity))
            }

            // 残り3・2・1カウントダウン表示
            if !viewModel.isCountingDown && !viewModel.showMiss && !viewModel.showClearEffect
                && viewModel.poseTimeRemaining <= 3 && viewModel.poseTimeRemaining > 0 {
                Text("\(viewModel.poseTimeRemaining)")
                    .font(.system(size: 120, weight: .black, design: .rounded))
                    .foregroundColor(.red)
                    .shadow(color: .red.opacity(0.8), radius: 30)
                    .transition(.scale(scale: 1.4).combined(with: .opacity))
                    .id("posecountdown-\(viewModel.poseTimeRemaining)")
            }

            // レベルアップ
            if viewModel.showLevelUp {
                VStack(spacing: 8) {
                    Text("🆙 LEVEL UP!")
                        .font(.system(size: 46, weight: .black, design: .rounded))
                        .foregroundColor(levelColor)
                        .shadow(color: levelColor.opacity(0.8), radius: 18)
                    Text(viewModel.currentLevel == 2 ? "Normal poses unlocked!" : "Hard poses unlocked!")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.7), radius: 4)
                }
                .transition(.scale.combined(with: .opacity))
            }

            // ボスフェーズ
            if viewModel.isBossPhase {
                VStack {
                    Text("👹  BOSS TIME  👹")
                        .font(.system(size: 20, weight: .black))
                        .foregroundColor(.white)
                        .padding(.horizontal, 22).padding(.vertical, 10)
                        .background(LinearGradient(gradient: Gradient(colors: [.red, .orange]),
                                                   startPoint: .leading, endPoint: .trailing))
                        .cornerRadius(22)
                        .shadow(color: .red.opacity(0.7), radius: 12)
                        .padding(.top, 180)
                    Spacer()
                }
            }

            // カウントダウン
            if viewModel.isCountingDown {
                countdownOverlay
            }

            // カメラエラー
            if let msg = viewModel.cameraErrorMessage {
                VStack(spacing: 8) {
                    Text("Camera Unavailable").font(.headline).foregroundColor(.white)
                    Text(msg).font(.subheadline).multilineTextAlignment(.center)
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(16).background(Color.black.opacity(0.8)).cornerRadius(14).padding()
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: viewModel.showClearEffect)
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: viewModel.showMiss)
        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: viewModel.showLevelUp)
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: viewModel.poseTimeRemaining)
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: viewModel.comboMessage)
        .sheet(isPresented: $showDifficultyPicker) {
            DifficultyPickerView(
                selectedDifficulty: $viewModel.difficulty,
                selectedMode: $viewModel.gameMode
            ) {
                showDifficultyPicker = false
                viewModel.resetGame()
            }
            .presentationDetents([.medium])
        }
        .fullScreenCover(isPresented: $viewModel.gameEnded) {
            ResultsView(
                score: viewModel.totalScore,
                clearCount: viewModel.clearCount,
                maxCombo: viewModel.maxCombo,
                isNewHighScore: viewModel.isNewHighScore,
                onHome: { dismiss() },
                onPlayAgain: {
                    viewModel.gameEnded = false
                    viewModel.resetGame()
                }
            )
        }
    }

    // MARK: - Helpers

    /// お手本骨格のY座標を安全表示領域内にリマップする
    /// 元の座標系(0〜1 = 画面全体)を、UI被りのない中央帯に収める
    private func remapJoints(
        _ joints: [VNHumanBodyPoseObservation.JointName: CGPoint],
        frameHeight: CGFloat,
        topSafe: CGFloat,
        bottomSafe: CGFloat
    ) -> [VNHumanBodyPoseObservation.JointName: CGPoint] {
        // フレームは safeH の高さ。SkeletonView が座標に geo.size.height を掛けるため、
        // Y 座標はフレーム内 (0〜1) で渡す必要がある。
        // pt.y (0〜1 = 画面全体) → フレーム内 Y (0〜1) にそのままマップ。
        // 上下に margin 分の余白を確保する。
        let margin: CGFloat = 0.02
        return joints.mapValues { pt in
            CGPoint(x: 1.0 - pt.x, y: margin + pt.y * (1.0 - margin * 2))
        }
    }

    // MARK: - Subviews

    /// SCORE / CLEAR 用の大きなステータスボックス
    private func bigStatBox(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white.opacity(0.65))
                .kerning(1.5)
            Text(value)
                .font(.system(size: 36, weight: .black, design: .rounded))
                .foregroundColor(color)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.black.opacity(0.65))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(0.35), lineWidth: 1.5))
        )
    }

    /// Time attack remaining time box
    private var timeAttackBox: some View {
        VStack(spacing: 2) {
            Text("TIME LEFT")
                .font(.system(size: 11, weight: .bold)).foregroundColor(.white.opacity(0.65)).kerning(1.5)
            Text("\(viewModel.timeAttackRemaining)s")
                .font(.system(size: 36, weight: .black, design: .rounded))
                .foregroundColor(viewModel.timeAttackRemaining <= 10 ? .red : .white)
                .minimumScaleFactor(0.6).lineLimit(1)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(viewModel.timeAttackRemaining <= 10 ? Color.red.opacity(0.3) : Color.black.opacity(0.65))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(viewModel.timeAttackRemaining <= 10 ? Color.red : Color.white.opacity(0.2), lineWidth: 1.5))
        )
    }

    /// ポーズ名ボックス
    private var poseNameBox: some View {
        VStack(spacing: 4) {
            Text(viewModel.isBossPhase ? "👹 BOSS" : "POSE")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(viewModel.isBossPhase ? .red : .white.opacity(0.65))
                .kerning(1.5)
            Text(viewModel.currentPose.rawValue)
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: .white.opacity(0.3), radius: 4)
                .multilineTextAlignment(.center).lineLimit(2)
                .minimumScaleFactor(0.6)
            Text(viewModel.currentPose.description)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.65))
                .lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 10).padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(viewModel.isBossPhase ? Color.red.opacity(0.45) : Color.black.opacity(0.65))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(viewModel.isBossPhase ? Color.red : Color.white.opacity(0.2), lineWidth: 1.5))
        )
    }

    /// カウントダウンオーバーレイ
    private var countdownOverlay: some View {
        ZStack {
            Color.black.opacity(0.65).ignoresSafeArea()
            if viewModel.countdownValue > 0 {
                Text("\(viewModel.countdownValue)")
                    .font(.system(size: 130, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .blue.opacity(0.9), radius: 24)
                    .transition(.scale.combined(with: .opacity))
                    .id(viewModel.countdownValue)
            } else {
                Text("GO! 🔥")
                    .font(.system(size: 86, weight: .black, design: .rounded))
                    .foregroundColor(.yellow)
                    .shadow(color: .orange.opacity(0.9), radius: 24)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: viewModel.countdownValue)
    }

    private func actionButton(_ title: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 14, weight: .bold))
        }
        .buttonStyle(.borderedProminent).tint(tint)
    }
}

// MARK: - タイマープログレスバー（大型化）
struct TimerProgressBar: View {
    let timeRemaining: Int
    let totalTime: Int
    let isBossPhase: Bool

    private var progress: Double {
        guard totalTime > 0 else { return 0 }
        return Double(timeRemaining) / Double(totalTime)
    }
    private var barColor: Color {
        if isBossPhase { return .red }
        if progress > 0.5 { return Color(red: 0.2, green: 1, blue: 0.4) }
        if progress > 0.25 { return .yellow }
        return .red
    }

    var body: some View {
        HStack(spacing: 10) {
            // 残り秒数（大きく）
            Text("\(timeRemaining)")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundColor(progress <= 0.25 ? .red : .white)
                .frame(width: 36, alignment: .trailing)
                .minimumScaleFactor(0.7)

            // バー本体
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color.white.opacity(0.12))
                    RoundedRectangle(cornerRadius: 7)
                        .fill(barColor)
                        .frame(width: geo.size.width * CGFloat(max(progress, 0)))
                        .animation(.linear(duration: 1.0), value: timeRemaining)
                    // バーの上に「TIME」ラベル
                    Text("LEFT")
                        .font(.system(size: 9, weight: .black)).kerning(1.5)
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.leading, 8)
                }
            }
            .frame(height: 24)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Color.black.opacity(0.6)).cornerRadius(12)
    }
}

// MARK: - ポーズスコアゲージ（大型化）
struct PoseScoreGauge: View {
    let score: Int
    let combo: Int
    let comboMessage: String

    private var progress: Double { Double(score) / 100.0 }
    private var gaugeColor: Color {
        if score >= 75 { return Color(red: 0.2, green: 1, blue: 0.4) }
        if score >= 50 { return .yellow }
        return Color(red: 1, green: 0.4, blue: 0.2)
    }
    private var comboColor: Color {
        if combo >= 10 { return Color(red: 1, green: 0.3, blue: 1) }  // マゼンタ
        if combo >= 5  { return .orange }
        return Color(red: 1, green: 0.75, blue: 0.2)  // ゴールド
    }

    var body: some View {
        VStack(spacing: 3) {
            HStack(spacing: 10) {
                // スコア数値
                Text("\(score)")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundColor(gaugeColor)
                    .frame(width: 46, alignment: .trailing)
                    .minimumScaleFactor(0.7)
                    .animation(.easeOut(duration: 0.15), value: score)

                // ゲージ本体
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(Color.white.opacity(0.12))
                        RoundedRectangle(cornerRadius: 7)
                            .fill(gaugeColor)
                            .frame(width: geo.size.width * CGFloat(progress))
                            .animation(.easeOut(duration: 0.15), value: score)
                        Rectangle()
                            .fill(Color.white.opacity(0.4))
                            .frame(width: 2)
                            .offset(x: geo.size.width * 0.5 - 1)
                        Text("POSE SCORE")
                            .font(.system(size: 9, weight: .black)).kerning(1)
                            .foregroundColor(.white.opacity(0.5))
                            .padding(.leading, 8)
                    }
                }
                .frame(height: 24)
            }

            // コンボ行（combo >= 2 のときだけ表示）
            if combo >= 2 {
                HStack {
                    Spacer()
                    Text(comboMessage)
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundColor(comboColor)
                        .shadow(color: comboColor.opacity(0.8), radius: 6)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                        .id(comboMessage)
                }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Color.black.opacity(0.6)).cornerRadius(12)
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: combo)
    }
}

// MARK: - 難易度・モード選択シート
struct DifficultyPickerView: View {
    @Binding var selectedDifficulty: GameViewModel.Difficulty
    @Binding var selectedMode: GameViewModel.GameMode
    let onStart: () -> Void

    private func diffColor(_ d: GameViewModel.Difficulty) -> Color {
        switch d { case .easy: return .green; case .normal: return .blue; case .hard: return .red }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Text("Game Settings ⚙️")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .padding(.top, 24)

                // モード
                sectionLabel("MODE")
                VStack(spacing: 8) {
                    ForEach(GameViewModel.GameMode.allCases, id: \.self) { mode in
                        Button(action: { selectedMode = mode }) {
                            HStack {
                                Text(mode.rawValue).font(.system(size: 16, weight: .bold))
                                Spacer()
                                if selectedMode == mode {
                                    Image(systemName: "checkmark.circle.fill").font(.title3)
                                }
                            }
                            .foregroundColor(selectedMode == mode ? .white : .primary)
                            .padding(.horizontal, 20).padding(.vertical, 14)
                            .background(selectedMode == mode ? Color.blue.opacity(0.8) : Color(.systemGray6))
                            .cornerRadius(14)
                        }
                    }
                }
                .padding(.horizontal, 20)

                // 難易度
                sectionLabel("DIFFICULTY")
                VStack(spacing: 8) {
                    ForEach(GameViewModel.Difficulty.allCases, id: \.self) { diff in
                        Button(action: { selectedDifficulty = diff }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(diff.rawValue).font(.system(size: 17, weight: .bold))
                                    Text("Pose time limit: \(diff.poseTime)s")
                                        .font(.caption).opacity(0.8)
                                }
                                Spacer()
                                if selectedDifficulty == diff {
                                    Image(systemName: "checkmark.circle.fill").font(.title3)
                                }
                            }
                            .foregroundColor(selectedDifficulty == diff ? .white : .primary)
                            .padding(.horizontal, 20).padding(.vertical, 14)
                            .background(selectedDifficulty == diff ? diffColor(diff) : Color(.systemGray6))
                            .cornerRadius(14)
                        }
                    }
                }
                .padding(.horizontal, 20)

                Button(action: onStart) {
                    Text("Game Start! 🏃")
                        .font(.system(size: 18, weight: .black)).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 18)
                        .background(LinearGradient(gradient: Gradient(colors: [.blue, .purple]),
                                                   startPoint: .leading, endPoint: .trailing))
                        .cornerRadius(16).shadow(color: .blue.opacity(0.4), radius: 8, y: 4)
                }
                .padding(.horizontal, 20).padding(.bottom, 28)
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .bold)).foregroundColor(.secondary).kerning(1.5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
    }
}

// MARK: - タイムアタック用 時計型タイマー
struct ClockTimerView: View {
    let timeRemaining: Int
    let totalTime: Int

    private var progress: Double {
        guard totalTime > 0 else { return 0 }
        return Double(timeRemaining) / Double(totalTime)
    }
    private var isUrgent: Bool { timeRemaining <= 10 }
    private var ringColor: Color {
        if isUrgent { return .red }
        if progress > 0.5 { return Color(red: 0.2, green: 1, blue: 0.4) }
        return .yellow
    }

    var body: some View {
        HStack(spacing: 14) {
            // ── 時計本体 ──
            ZStack {
                // ベゼル
                Circle()
                    .fill(Color.black.opacity(0.7))
                    .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1.5))

                // 目盛り（12本）
                ForEach(0..<12) { i in
                    Rectangle()
                        .fill(Color.white.opacity(i % 3 == 0 ? 0.5 : 0.2))
                        .frame(width: i % 3 == 0 ? 2 : 1, height: i % 3 == 0 ? 8 : 5)
                        .offset(y: -38)
                        .rotationEffect(.degrees(Double(i) * 30))
                }

                // 背景トラック
                Circle()
                    .stroke(Color.white.opacity(0.08),
                            style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .frame(width: 62, height: 62)

                // プログレスリング
                Circle()
                    .trim(from: 0, to: CGFloat(max(progress, 0)))
                    .stroke(ringColor,
                            style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .frame(width: 62, height: 62)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1.0), value: timeRemaining)
                    .shadow(color: ringColor.opacity(0.8), radius: 5)

                // 秒数
                VStack(spacing: 0) {
                    Text("\(timeRemaining)")
                        .font(.system(size: 24, weight: .black, design: .monospaced))
                        .foregroundColor(isUrgent ? .red : .white)
                        .animation(.easeOut(duration: 0.2), value: timeRemaining)
                        .shadow(color: isUrgent ? .red.opacity(0.9) : .clear, radius: 6)
                    Text("s")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.45))
                }

                // 中心点
                Circle()
                    .fill(ringColor)
                    .frame(width: 5, height: 5)
                    .shadow(color: ringColor, radius: 3)
            }
            .frame(width: 88, height: 88)
            // 残り10秒以下でパルスアニメーション
            .scaleEffect(isUrgent ? 1.04 : 1.0)
            .animation(isUrgent ? .easeInOut(duration: 0.5).repeatForever(autoreverses: true) : .default,
                       value: isUrgent)

            // ── テキスト情報 ──
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Image(systemName: "timer")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(ringColor)
                    Text("TIME LEFT")
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(.white.opacity(0.65))
                        .kerning(1.2)
                }

                // プログレスバー
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.1))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(ringColor)
                            .frame(width: geo.size.width * CGFloat(max(progress, 0)))
                            .animation(.linear(duration: 1.0), value: timeRemaining)
                    }
                }
                .frame(height: 6)

                if isUrgent {
                    Text("Hurry! 🔥")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundColor(.red)
                        .shadow(color: .red.opacity(0.7), radius: 5)
                        .transition(.opacity)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.65))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(ringColor.opacity(0.3), lineWidth: 1.5)
                )
        )
        .animation(.easeInOut(duration: 0.3), value: isUrgent)
    }
}
