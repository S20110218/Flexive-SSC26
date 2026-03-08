import Vision
import AVFoundation
import CoreGraphics

final class PoseEstimator {

    private let request = VNDetectHumanBodyPoseRequest()

    func process(sampleBuffer: CMSampleBuffer,
                 orientation: CGImagePropertyOrientation,
                 completion: @escaping (VNHumanBodyPoseObservation?) -> Void) {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            completion(nil); return
        }
        let handler = VNImageRequestHandler(cvPixelBuffer: buffer, orientation: orientation)
        do { try handler.perform([request]) } catch { completion(nil); return }
        completion(request.results?.first)
    }

    // MARK: - スコア計算（0.0〜1.0）
    //
    // ■ 設計方針
    //   距離ベースの比較は「カメラとの距離」「体格」に左右されやすい。
    //   代わりに「各関節の角度（方向ベクトル）」を比較する。
    //   角度は距離・体格に依存しないため、公平な判定ができる。
    //
    // ■ 具体的な計算
    //   各ボーン（肩→肘など）の向きを角度（ラジアン）で求め、
    //   ターゲットとの角度差（0〜π）をスコアに変換する。
    //   角度差 0rad → スコア1.0、π/2(90°)差 → スコア0.0
    //
    func score(current: [VNHumanBodyPoseObservation.JointName: CGPoint],
               target:  [VNHumanBodyPoseObservation.JointName: CGPoint]) -> Double {

        // 比較するボーン一覧（親関節→子関節）と重み
        let bones: [(VNHumanBodyPoseObservation.JointName,
                     VNHumanBodyPoseObservation.JointName,
                     Double)] = [
            // 腕（ポーズ判定の中心）
            (.leftShoulder,  .leftElbow,   3.0),
            (.leftElbow,     .leftWrist,   3.0),
            (.rightShoulder, .rightElbow,  3.0),
            (.rightElbow,    .rightWrist,  3.0),
            // 脚（足上げを確実に検出するため重みを上げる）
            (.leftHip,       .leftKnee,    3.5),
            (.leftKnee,      .leftAnkle,   2.5),
            (.rightHip,      .rightKnee,   3.5),
            (.rightKnee,     .rightAnkle,  2.5),
            // 体幹
            (.leftShoulder,  .leftHip,     0.8),
            (.rightShoulder, .rightHip,    0.8),
            (.leftShoulder,  .rightShoulder, 0.3),
            (.leftHip,       .rightHip,    0.3),
        ]

        var totalWeight = 0.0
        var totalScore  = 0.0

        for (from, to, weight) in bones {
            guard let curFrom = current[from], let curTo = current[to],
                  let tgtFrom = target[from],  let tgtTo  = target[to]
            else { continue }

            let curAngle = angle(from: curFrom, to: curTo)
            let tgtAngle = angle(from: tgtFrom, to: tgtTo)

            var diff = abs(curAngle - tgtAngle)
            if diff > .pi { diff = 2 * .pi - diff }

            // 差が110°(π*110/180)を超えたらスコア0（従来90°より緩め）
            let boneScore = max(0.0, 1.0 - diff / (.pi * 110.0 / 180.0))
            totalScore  += boneScore * weight
            totalWeight += weight
        }

        guard totalWeight > 0 else { return 0 }
        return totalScore / totalWeight
    }

    // MARK: - 2点間の角度（ラジアン）
    private func angle(from: CGPoint, to: CGPoint) -> Double {
        Double(atan2(to.y - from.y, to.x - from.x))
    }
}
