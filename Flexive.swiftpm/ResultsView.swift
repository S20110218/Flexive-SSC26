import SwiftUI

struct ResultsView: View {
    let score: Int
    let clearCount: Int
    let maxCombo: Int
    let isNewHighScore: Bool
    let onHome: () -> Void
    let onPlayAgain: () -> Void

    @StateObject private var recordsManager = GameRecordsManager()

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.1, green: 0.15, blue: 0.4),
                    Color(red: 0.3, green: 0.1, blue: 0.5)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {

                    // ---- ヘッダー ----
                    VStack(spacing: 10) {
                        if isNewHighScore {
                            Text("🏆")
                                .font(.system(size: 70))
                            Text("NEW RECORD!")
                                .font(.system(size: 38, weight: .black, design: .rounded))
                                .foregroundColor(.yellow)
                                .shadow(color: .yellow.opacity(0.6), radius: 12)
                        } else {
                            Text("🎊")
                                .font(.system(size: 70))
                            Text("GAME OVER")
                                .font(.system(size: 38, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.top, 56)

                    // ---- 今回のスコア ----
                    VStack(spacing: 12) {
                        resultRow(icon: "star.fill",       label: "Score",     value: "\(score)",      color: .yellow)
                        resultRow(icon: "checkmark.circle.fill", label: "Cleared", value: "\(clearCount)", color: .green)
                        resultRow(icon: "flame.fill",      label: "Max Combo", value: "\(maxCombo)",   color: .orange)
                        resultRow(icon: "crown.fill",      label: "Best",      value: "\(GameRecordsManager.highScore)", color: .yellow)
                    }
                    .padding(.horizontal, 24)

                    // ---- ボタン ----
                    VStack(spacing: 12) {
                        Button(action: onPlayAgain) {
                            HStack(spacing: 10) {
                                Image(systemName: "arrow.clockwise")
                                Text("Play Again")
                                    .fontWeight(.bold)
                            }
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [.blue, .purple]),
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                            .shadow(color: .blue.opacity(0.4), radius: 8, x: 0, y: 4)
                        }

                        Button(action: onHome) {
                            HStack(spacing: 10) {
                                Image(systemName: "house.fill")
                                Text("Back to Home")
                                    .fontWeight(.semibold)
                            }
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.9))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.12))
                            .cornerRadius(16)
                        }
                    }
                    .padding(.horizontal, 24)

                    // ---- 過去記録 ----
                    VStack(alignment: .leading, spacing: 14) {
                        Text("🏅 Past Records")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        if recordsManager.records.isEmpty {
                            Text("No records yet")
                                .foregroundColor(.white.opacity(0.5))
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 30)
                        } else {
                            VStack(spacing: 10) {
                                ForEach(Array(recordsManager.records.enumerated()), id: \.element.id) { index, record in
                                    RecordRow(rank: index + 1, record: record)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            recordsManager.addRecord(score: score, clearCount: clearCount)
        }
    }

    private func resultRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            Text(label)
                .foregroundColor(.white.opacity(0.8))
            Spacer()
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(color)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.08))
        .cornerRadius(14)
    }
}
