import SwiftUI

struct TimerBox: View {
    let title: String
    let value: Int
    let color: Color

    /// ポーズ制限時間の最大値（デフォルト10秒）
    var totalTime: Int = 10

    private var progress: Double {
        guard totalTime > 0 else { return 0 }
        return Double(value) / Double(totalTime)
    }

    private var dialColor: Color {
        if progress > 0.5 { return color }
        if progress > 0.25 { return .yellow }
        return .red
    }

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(0.6))
                .kerning(1.2)

            ZStack {
                // 外枠（時計のベゼル）
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [Color.white.opacity(0.12), Color.black.opacity(0.5)]),
                            center: .center,
                            startRadius: 20,
                            endRadius: 45
                        )
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.18), lineWidth: 1.5)
                    )

                // 目盛り（12本）
                ForEach(0..<12) { i in
                    let angle = Double(i) * 30.0
                    Rectangle()
                        .fill(Color.white.opacity(i % 3 == 0 ? 0.5 : 0.2))
                        .frame(width: i % 3 == 0 ? 2 : 1, height: i % 3 == 0 ? 7 : 4)
                        .offset(y: -30)
                        .rotationEffect(.degrees(angle))
                }

                // 背景トラック
                Circle()
                    .stroke(Color.white.opacity(0.1), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 52, height: 52)

                // プログレスリング
                Circle()
                    .trim(from: 0, to: CGFloat(max(progress, 0)))
                    .stroke(
                        dialColor,
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .frame(width: 52, height: 52)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1.0), value: value)
                    .shadow(color: dialColor.opacity(0.7), radius: 4)

                // 中心：秒数表示
                VStack(spacing: 0) {
                    Text("\(value)")
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .foregroundColor(dialColor)
                        .animation(.easeOut(duration: 0.2), value: value)
                    Text("s")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white.opacity(0.5))
                }

                // 中心点
                Circle()
                    .fill(dialColor)
                    .frame(width: 4, height: 4)
                    .shadow(color: dialColor, radius: 3)
            }
            .frame(width: 76, height: 76)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(color.opacity(0.25), lineWidth: 1)
                )
        )
    }
}
