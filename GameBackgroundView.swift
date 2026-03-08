import SwiftUI

/// ゲーム空間っぽい背景
/// カメラ映像の上に重ねて使う
struct GameBackgroundView: View {

    @State private var phase: CGFloat = 0
    @State private var sparkles: [SparkleParticle] = SparkleParticle.generate(count: 28)

    var body: some View {
        ZStack {
            // ── 1. ベースグラデーション（深い紺〜紫〜黒）──
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.06, blue: 0.22),
                    Color(red: 0.10, green: 0.04, blue: 0.20),
                    Color(red: 0.02, green: 0.02, blue: 0.12),
                ],
                startPoint: .top, endPoint: .bottom
            )
            .opacity(0.82)

            // ── 2. グリッド（奥行き感） ──
            GridOverlay()
                .opacity(0.13)

            // ── 3. 床面グロー（下から青白い光） ──
            RadialGradient(
                colors: [
                    Color(red: 0.20, green: 0.60, blue: 1.00).opacity(0.35),
                    Color.clear
                ],
                center: UnitPoint(x: 0.5, y: 1.1),
                startRadius: 0,
                endRadius: 500
            )

            // ── 4. 頭上スポットライト ──
            RadialGradient(
                colors: [
                    Color.white.opacity(0.06),
                    Color.clear
                ],
                center: UnitPoint(x: 0.5, y: -0.1),
                startRadius: 0,
                endRadius: 350
            )

            // ── 5. キラキラパーティクル ──
            TimelineView(.animation) { timeline in
                Canvas { ctx, size in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    for s in sparkles {
                        let x = s.x * size.width
                        let baseY = s.y * size.height
                        // ゆっくり上に流れる
                        let y = baseY - CGFloat(t * s.speed * 18).truncatingRemainder(dividingBy: size.height)
                        let alpha = 0.3 + 0.7 * abs(sin(t * s.blinkRate + s.phase))
                        let r = s.radius

                        // 輝点
                        ctx.fill(
                            Path(ellipseIn: CGRect(x: x-r, y: y-r, width: r*2, height: r*2)),
                            with: .color(s.color.opacity(alpha))
                        )
                        // 外側グロー
                        ctx.fill(
                            Path(ellipseIn: CGRect(x: x-r*2.5, y: y-r*2.5, width: r*5, height: r*5)),
                            with: .color(s.color.opacity(alpha * 0.18))
                        )
                    }
                }
            }

            // ── 6. 左右エッジグロー（ステージ感） ──
            HStack {
                LinearGradient(
                    colors: [Color(red: 0.1, green: 0.4, blue: 1.0).opacity(0.20), Color.clear],
                    startPoint: .leading, endPoint: .trailing
                )
                .frame(width: 60)
                Spacer()
                LinearGradient(
                    colors: [Color.clear, Color(red: 0.6, green: 0.1, blue: 1.0).opacity(0.20)],
                    startPoint: .leading, endPoint: .trailing
                )
                .frame(width: 60)
            }
        }
    }
}

// ─── グリッドオーバーレイ ───
struct GridOverlay: View {
    var body: some View {
        Canvas { ctx, size in
            let cols = 10
            let rows = 18
            let cw = size.width  / CGFloat(cols)
            let rh = size.height / CGFloat(rows)

            for i in 0...cols {
                var p = Path()
                p.move(to: CGPoint(x: CGFloat(i)*cw, y: 0))
                p.addLine(to: CGPoint(x: CGFloat(i)*cw, y: size.height))
                ctx.stroke(p, with: .color(.white), lineWidth: 0.5)
            }
            for j in 0...rows {
                var p = Path()
                p.move(to: CGPoint(x: 0,          y: CGFloat(j)*rh))
                p.addLine(to: CGPoint(x: size.width, y: CGFloat(j)*rh))
                ctx.stroke(p, with: .color(.white), lineWidth: 0.5)
            }
        }
    }
}

// ─── パーティクルデータ ───
struct SparkleParticle {
    let x: CGFloat
    let y: CGFloat
    let radius: CGFloat
    let speed: CGFloat
    let blinkRate: Double
    let phase: Double
    let color: Color

    static func generate(count: Int) -> [SparkleParticle] {
        let colors: [Color] = [
            Color(red: 0.5, green: 0.9, blue: 1.0),
            Color(red: 0.8, green: 0.5, blue: 1.0),
            Color(red: 0.4, green: 0.7, blue: 1.0),
            Color.white,
        ]
        return (0..<count).map { _ in
            SparkleParticle(
                x: CGFloat.random(in: 0...1),
                y: CGFloat.random(in: 0...1),
                radius: CGFloat.random(in: 1.2...3.0),
                speed: CGFloat.random(in: 0.4...1.2),
                blinkRate: Double.random(in: 0.8...2.5),
                phase: Double.random(in: 0...(2 * .pi)),
                color: colors.randomElement()!
            )
        }
    }
}
