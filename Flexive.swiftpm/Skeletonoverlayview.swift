import SwiftUI
import Vision

// MARK: - Wii Fit風キャラクター（球体で構成）
struct UserSkeletonView: View {
    let joints: [VNHumanBodyPoseObservation.JointName: CGPoint]

    var body: some View {
        GeometryReader { geo in
            WiiCharCanvas(joints: joints, w: geo.size.width, h: geo.size.height)
        }
    }
}

struct WiiCharCanvas: View {
    let joints: [VNHumanBodyPoseObservation.JointName: CGPoint]
    let w: CGFloat
    let h: CGFloat

    // ── 色 ──
    private let c1 = Color(red: 0.55, green: 0.88, blue: 1.00) // 明るい水色（光源側）
    private let c2 = Color(red: 0.10, green: 0.45, blue: 0.90) // 濃い青（影側）
    private let cout = Color(red: 0.02, green: 0.18, blue: 0.52) // 輪郭
    private let cheek = Color(red: 1.0, green: 0.55, blue: 0.65)

    func pt(_ n: VNHumanBodyPoseObservation.JointName) -> CGPoint? {
        guard let p = joints[n] else { return nil }
        return CGPoint(x: p.x * w, y: p.y * h)
    }

    var body: some View {
        Canvas { ctx, _ in

            // ─── 棒（接続）を先に描いて球で隠す ───
            let rods: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName, CGFloat)] = [
                (.neck, .leftShoulder,   7),
                (.neck, .rightShoulder,  7),
                (.leftShoulder, .leftElbow,   9),
                (.leftElbow,    .leftWrist,   7),
                (.rightShoulder,.rightElbow,  9),
                (.rightElbow,   .rightWrist,  7),
                (.neck, .leftHip,        8),
                (.neck, .rightHip,       8),
                (.leftHip,  .leftKnee,  10),
                (.leftKnee, .leftAnkle,  8),
                (.rightHip, .rightKnee, 10),
                (.rightKnee,.rightAnkle, 8),
            ]
            for (a, b, r) in rods {
                guard let pa = pt(a), let pb = pt(b) else { continue }
                drawRod(ctx: ctx, from: pa, to: pb, radius: r)
            }

            // ─── 関節球 ───
            let balls: [(VNHumanBodyPoseObservation.JointName, CGFloat)] = [
                (.leftWrist,    10), (.rightWrist,   10),
                (.leftElbow,    13), (.rightElbow,   13),
                (.leftAnkle,    12), (.rightAnkle,   12),
                (.leftKnee,     15), (.rightKnee,    15),
                (.leftHip,      18), (.rightHip,     18),
                (.leftShoulder, 17), (.rightShoulder,17),
                (.neck,         13),
            ]
            for (name, r) in balls {
                guard let p = pt(name) else { continue }
                drawSphere(ctx: ctx, c: p, r: r)
            }

            // ─── 胴体（大きな球） ───
            if let ls = pt(.leftShoulder), let rs = pt(.rightShoulder),
               let lh = pt(.leftHip), let rh = pt(.rightHip) {
                let cx = (ls.x + rs.x + lh.x + rh.x) / 4
                let cy = (ls.y + rs.y + lh.y + rh.y) / 4
                let rw = abs(rs.x - ls.x) * 0.32
                let rh2 = abs(lh.y - ls.y) * 0.56
                drawSphereEllipse(ctx: ctx, c: CGPoint(x: cx, y: cy),
                                  rx: max(rw, 16), ry: max(rh2, 28))
            }

            // ─── 肩・腰を再描画（胴体球の上に重ねる） ───
            for name in [VNHumanBodyPoseObservation.JointName.leftShoulder,
                         .rightShoulder, .leftHip, .rightHip] {
                guard let p = pt(name) else { continue }
                let r: CGFloat = name == .leftHip || name == .rightHip ? 17 : 16
                drawSphere(ctx: ctx, c: p, r: r)
            }

            // ─── 頭 ───
            if let nose = pt(.nose) {
                let neck = pt(.neck)
                let headR: CGFloat = 26
                // 頭の位置：nose から少し上
                let headC = CGPoint(x: nose.x, y: nose.y - headR * 0.4)

                // 首と頭をつなぐ棒
                if let nk = neck {
                    drawRod(ctx: ctx, from: nk, to: headC, radius: 10)
                }

                // 頭球
                drawSphereEllipse(ctx: ctx, c: headC, rx: headR, ry: headR)

                // ── 顔パーツ ──
                let eyeY = headC.y + headR * 0.05
                let eyeOff = headR * 0.30

                // 白目
                for sign: CGFloat in [-1, 1] {
                    let ex = headC.x + sign * eyeOff
                    ctx.fill(Path(ellipseIn: CGRect(x: ex-7, y: eyeY-6.5, width: 14, height: 13)),
                             with: .color(.white))
                    // 黒目
                    ctx.fill(Path(ellipseIn: CGRect(x: ex-4.5, y: eyeY-4, width: 9, height: 9)),
                             with: .color(.black))
                    // 白ハイライト
                    ctx.fill(Path(ellipseIn: CGRect(x: ex-2.5, y: eyeY-3.5, width: 4, height: 4)),
                             with: .color(.white))
                }

                // 笑顔
                var smile = Path()
                let sy = eyeY + headR * 0.38
                let sr = headR * 0.38
                smile.move(to: CGPoint(x: headC.x - sr, y: sy))
                smile.addQuadCurve(
                    to:      CGPoint(x: headC.x + sr, y: sy),
                    control: CGPoint(x: headC.x,      y: sy + sr * 0.9))
                ctx.stroke(smile, with: .color(cout),
                           style: StrokeStyle(lineWidth: 3, lineCap: .round))

                // ほっぺ
                for sign: CGFloat in [-1, 1] {
                    ctx.fill(Path(ellipseIn: CGRect(
                        x: headC.x + sign * headR * 0.55 - 9,
                        y: eyeY + 7, width: 18, height: 10)),
                             with: .color(cheek.opacity(0.45)))
                }
            }
        }
    }

    // ─── 球（正円）描画 ───
    private func drawSphere(ctx: GraphicsContext, c: CGPoint, r: CGFloat) {
        drawSphereEllipse(ctx: ctx, c: c, rx: r, ry: r)
    }

    // ─── 球（楕円）描画 ───
    private func drawSphereEllipse(ctx: GraphicsContext, c: CGPoint, rx: CGFloat, ry: CGFloat) {
        // 落ち影
        ctx.fill(
            Path(ellipseIn: CGRect(x: c.x - rx + 5, y: c.y - ry + 7, width: rx*2, height: ry*2)),
            with: .color(.black.opacity(0.20)))

        // 輪郭
        ctx.fill(
            Path(ellipseIn: CGRect(x: c.x - rx - 3, y: c.y - ry - 3, width: (rx+3)*2, height: (ry+3)*2)),
            with: .color(cout))

        // 暗面（グラデ下地）
        ctx.fill(
            Path(ellipseIn: CGRect(x: c.x - rx, y: c.y - ry, width: rx*2, height: ry*2)),
            with: .color(c2))

        // メイン（少し上＋左にオフセット）
        ctx.fill(
            Path(ellipseIn: CGRect(x: c.x - rx + 1, y: c.y - ry, width: rx*2 - 2, height: ry*2 - 3)),
            with: .color(c1))

        // 光沢ハイライト（左上の明るい楕円）
        ctx.fill(
            Path(ellipseIn: CGRect(x: c.x - rx*0.62, y: c.y - ry*0.78, width: rx*1.05, height: ry*0.55)),
            with: .color(.white.opacity(0.52)))

        // 小さな光点
        ctx.fill(
            Path(ellipseIn: CGRect(x: c.x - rx*0.28, y: c.y - ry*0.60, width: rx*0.26, height: ry*0.20)),
            with: .color(.white.opacity(0.85)))
    }

    // ─── 棒（カプセル）描画 ───
    private func drawRod(ctx: GraphicsContext, from a: CGPoint, to b: CGPoint, radius r: CGFloat) {
        let dx = b.x - a.x, dy = b.y - a.y
        let len = sqrt(dx*dx + dy*dy)
        guard len > 1 else { return }
        let px = -dy/len * r, py = dx/len * r
        let angle = atan2(Double(dy), Double(dx))

        func makeCap(_ center: CGPoint, _ startA: Double, _ endA: Double) -> Path {
            var p = Path()
            p.addArc(center: center, radius: r,
                     startAngle: .radians(startA), endAngle: .radians(endA), clockwise: false)
            return p
        }

        func rodPath(expand e: CGFloat) -> Path {
            let re = r + e
            let pex = -dy/len * re, pey = dx/len * re
            var p = Path()
            p.move(to: CGPoint(x: a.x+pex, y: a.y+pey))
            p.addLine(to: CGPoint(x: b.x+pex, y: b.y+pey))
            p.addArc(center: b, radius: re,
                     startAngle: .radians(angle - .pi/2),
                     endAngle:   .radians(angle + .pi/2), clockwise: false)
            p.addLine(to: CGPoint(x: a.x-pex, y: a.y-pey))
            p.addArc(center: a, radius: re,
                     startAngle: .radians(angle + .pi/2),
                     endAngle:   .radians(angle - .pi/2), clockwise: false)
            p.closeSubpath()
            return p
        }

        // 影
        let shOff = CGPoint(x: 3, y: 5)
        var sp = Path()
        sp.move(to: CGPoint(x: a.x+px+shOff.x, y: a.y+py+shOff.y))
        sp.addLine(to: CGPoint(x: b.x+px+shOff.x, y: b.y+py+shOff.y))
        sp.addArc(center: CGPoint(x: b.x+shOff.x, y: b.y+shOff.y), radius: r,
                  startAngle: .radians(angle - .pi/2), endAngle: .radians(angle + .pi/2), clockwise: false)
        sp.addLine(to: CGPoint(x: a.x-px+shOff.x, y: a.y-py+shOff.y))
        sp.addArc(center: CGPoint(x: a.x+shOff.x, y: a.y+shOff.y), radius: r,
                  startAngle: .radians(angle + .pi/2), endAngle: .radians(angle - .pi/2), clockwise: false)
        sp.closeSubpath()
        ctx.fill(sp, with: .color(.black.opacity(0.18)))

        // 輪郭
        ctx.fill(rodPath(expand: 2.5), with: .color(cout))
        // 暗面
        ctx.fill(rodPath(expand: 0), with: .color(c2))
        // メイン
        ctx.fill(rodPath(expand: 0), with: .color(c1.opacity(0.88)))

        // ハイライト
        let mc = CGPoint(x: (a.x+b.x)/2, y: (a.y+b.y)/2)
        ctx.fill(
            Path(ellipseIn: CGRect(x: mc.x - r*0.85, y: mc.y - r*0.78, width: r*1.7, height: r*0.65)),
            with: .color(.white.opacity(0.42)))
    }
}

// MARK: - お手本骨格（オレンジ破線）
struct TargetSkeletonView: View {
    let joints: [VNHumanBodyPoseObservation.JointName: CGPoint]
    private let links: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
        (.leftShoulder,.leftElbow),(.leftElbow,.leftWrist),
        (.rightShoulder,.rightElbow),(.rightElbow,.rightWrist),
        (.leftShoulder,.rightShoulder),
        (.leftShoulder,.leftHip),(.rightShoulder,.rightHip),
        (.leftHip,.rightHip),(.neck,.nose),
        (.leftHip,.leftKnee),(.leftKnee,.leftAnkle),
        (.rightHip,.rightKnee),(.rightKnee,.rightAnkle),
    ]
    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            func p(_ n: VNHumanBodyPoseObservation.JointName) -> CGPoint? {
                guard let j = joints[n] else { return nil }
                return CGPoint(x: j.x*w, y: j.y*h)
            }
            for (ja,jb) in links {
                guard let a = p(ja), let b = p(jb) else { continue }
                var ln = Path(); ln.move(to: a); ln.addLine(to: b)
                ctx.stroke(ln, with: .color(.black.opacity(0.5)),
                           style: StrokeStyle(lineWidth: 10, lineCap: .round))
                ctx.stroke(ln, with: .color(.orange.opacity(0.9)),
                           style: StrokeStyle(lineWidth: 5, lineCap: .round, dash: [8,5]))
            }
            for (_,v) in joints {
                ctx.fill(Path(ellipseIn: CGRect(x: v.x*w-8, y: v.y*h-8, width: 16, height: 16)),
                         with: .color(.black.opacity(0.5)))
                ctx.fill(Path(ellipseIn: CGRect(x: v.x*w-5, y: v.y*h-5, width: 10, height: 10)),
                         with: .color(.orange.opacity(0.9)))
            }
        }
    }
}

// MARK: - 後方互換用（HomeView）
struct SkeletonOverlayView: View {
    let joints: [VNHumanBodyPoseObservation.JointName: CGPoint]
    let color: Color
    private let links: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
        (.leftShoulder,.leftElbow),(.leftElbow,.leftWrist),
        (.rightShoulder,.rightElbow),(.rightElbow,.rightWrist),
        (.leftShoulder,.rightShoulder),
        (.leftShoulder,.leftHip),(.rightShoulder,.rightHip),
        (.leftHip,.rightHip),(.neck,.nose),
        (.leftHip,.leftKnee),(.leftKnee,.leftAnkle),
        (.rightHip,.rightKnee),(.rightKnee,.rightAnkle),
    ]
    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            for (ja,jb) in links {
                guard let a_ = joints[ja], let b_ = joints[jb] else { continue }
                let a = CGPoint(x: a_.x*w, y: a_.y*h), b = CGPoint(x: b_.x*w, y: b_.y*h)
                var ln = Path(); ln.move(to: a); ln.addLine(to: b)
                ctx.stroke(ln, with: .color(color), style: StrokeStyle(lineWidth: 5, lineCap: .round))
            }
            for (_,v) in joints {
                let r: CGFloat = 6
                ctx.fill(Path(ellipseIn: CGRect(x: v.x*w-r, y: v.y*h-r, width: r*2, height: r*2)),
                         with: .color(color))
            }
        }
    }
}

// MARK: - DualSkeletonOverlayView
struct DualSkeletonOverlayView: View {
    let userJoints: [VNHumanBodyPoseObservation.JointName: CGPoint]
    let targetJoints: [VNHumanBodyPoseObservation.JointName: CGPoint]
    let score: Double
    var body: some View {
        ZStack {
            TargetSkeletonView(joints: targetJoints)
            UserSkeletonView(joints: userJoints)
        }
    }
}
