import Foundation
import Vision
import CoreGraphics

enum GamePose: String, CaseIterable {

    // ── Lv1: Easy (arms only) ──
    case armsUp      = "Arms Up ✋"
    case armsOut     = "Arms Out →←"
    case rightArmUp  = "Right Arm Up 🙋"
    case leftArmUp   = "Left Arm Up 🙋"

    // ── Lv2: Normal (arms + legs) ──
    case tPose           = "T-Pose 🤸"
    case jumpingJack     = "Jumping Jack ⭐"
    case squat           = "Squat ⬇️"
    case rightLegUp      = "Right Leg Up 🦵"
    case leftLegUp       = "Left Leg Up 🦵"

    // ── Lv3: Hard (combined) ──
    case rightLunge          = "Right Lunge 🏃"
    case leftLunge           = "Left Lunge 🏃"
    case armsUpRightLegUp    = "Balance Right 🧘"
    case armsUpLeftLegUp     = "Balance Left 🧘"
    case starPose            = "Star Pose 🌟"

    var level: Int {
        switch self {
        case .armsUp, .armsOut, .rightArmUp, .leftArmUp:              return 1
        case .tPose, .jumpingJack, .squat, .rightLegUp, .leftLegUp:   return 2
        case .rightLunge, .leftLunge, .armsUpRightLegUp, .armsUpLeftLegUp, .starPose: return 3
        }
    }

    // ポーズごとのクリア閾値（難しいポーズは低めに設定）
    var clearThreshold: Int {
        switch self {
        case .jumpingJack:                          return 52  // 腕+足同時で難しい
        case .starPose:                             return 52
        case .armsUpRightLegUp, .armsUpLeftLegUp:  return 55
        case .rightLunge, .leftLunge:              return 55
        case .tPose, .squat:                       return 58
        default:                                   return 65
        }
    }

    var description: String {
        switch self {
        case .armsUp:             return "Raise both arms straight up"
        case .armsOut:            return "Stretch both arms out horizontally"
        case .rightArmUp:         return "Raise only your right arm"
        case .leftArmUp:          return "Raise only your left arm"
        case .tPose:              return "Arms horizontal, feet together"
        case .jumpingJack:        return "Arms up, feet apart"
        case .squat:              return "Lower your hips into a squat"
        case .rightLegUp:         return "Lift your right leg forward"
        case .leftLegUp:          return "Lift your left leg forward"
        case .rightLunge:         return "Step your right foot forward"
        case .leftLunge:          return "Step your left foot forward"
        case .armsUpRightLegUp:   return "Stand on left leg, raise both arms"
        case .armsUpLeftLegUp:    return "Stand on right leg, raise both arms"
        case .starPose:           return "Spread arms and legs wide"
        }
    }

    /// Text for TTS voice readout (AVSpeechSynthesizer)
    var announcement: String {
        switch self {
        case .armsUp:             return "Arms up! Raise both hands above your head"
        case .armsOut:            return "Arms out! Stretch both arms to the sides"
        case .rightArmUp:         return "Right arm up! Raise your right hand"
        case .leftArmUp:          return "Left arm up! Raise your left hand"
        case .tPose:              return "T-Pose! Stretch both arms out horizontally"
        case .jumpingJack:        return "Jumping Jack! Arms up and feet apart"
        case .squat:              return "Squat! Lower your hips down"
        case .rightLegUp:         return "Right leg up! Lift your right leg forward"
        case .leftLegUp:          return "Left leg up! Lift your left leg forward"
        case .rightLunge:         return "Right Lunge! Step your right foot forward"
        case .leftLunge:          return "Left Lunge! Step your left foot forward"
        case .armsUpRightLegUp:   return "Balance right! Raise both arms and lift your right leg"
        case .armsUpLeftLegUp:    return "Balance left! Raise both arms and lift your left leg"
        case .starPose:           return "Star Pose! Spread your arms and legs as wide as you can"
        }
    }

    // MARK: - ターゲットジョイント座標（正規化済み 0〜1）
    var targetJoints: [VNHumanBodyPoseObservation.JointName: CGPoint] {
        switch self {

        // Lv1 ─────────────────────────────────────────
        case .armsUp:
            return [
                .nose: p(0.50,0.08), .neck: p(0.50,0.18),
                .leftShoulder:  p(0.60,0.25), .rightShoulder: p(0.40,0.25),
                .leftElbow:  p(0.62,0.12), .rightElbow:  p(0.38,0.12),
                .leftWrist:  p(0.62,0.02), .rightWrist:  p(0.38,0.02),
                .leftHip:  p(0.55,0.55), .rightHip:  p(0.45,0.55),
                .leftKnee: p(0.55,0.75), .rightKnee: p(0.45,0.75),
                .leftAnkle: p(0.55,0.95), .rightAnkle: p(0.45,0.95),
            ]

        case .armsOut:
            return [
                .nose: p(0.50,0.08), .neck: p(0.50,0.18),
                .leftShoulder:  p(0.60,0.25), .rightShoulder: p(0.40,0.25),
                .leftElbow:  p(0.80,0.25), .rightElbow:  p(0.20,0.25),
                .leftWrist:  p(0.95,0.25), .rightWrist:  p(0.05,0.25),
                .leftHip:  p(0.55,0.55), .rightHip:  p(0.45,0.55),
                .leftKnee: p(0.55,0.75), .rightKnee: p(0.45,0.75),
                .leftAnkle: p(0.55,0.95), .rightAnkle: p(0.45,0.95),
            ]

        case .rightArmUp:
            return [
                .nose: p(0.50,0.08), .neck: p(0.50,0.18),
                .leftShoulder:  p(0.60,0.25), .rightShoulder: p(0.40,0.25),
                .leftElbow:  p(0.65,0.40), .rightElbow:  p(0.38,0.12),  // 右腕だけ上（画面右）
                .leftWrist:  p(0.68,0.55), .rightWrist:  p(0.38,0.02),
                .leftHip:  p(0.55,0.55), .rightHip:  p(0.45,0.55),
                .leftKnee: p(0.55,0.75), .rightKnee: p(0.45,0.75),
                .leftAnkle: p(0.55,0.95), .rightAnkle: p(0.45,0.95),
            ]

        case .leftArmUp:
            return [
                .nose: p(0.50,0.08), .neck: p(0.50,0.18),
                .leftShoulder:  p(0.60,0.25), .rightShoulder: p(0.40,0.25),
                .leftElbow:  p(0.62,0.12), .rightElbow:  p(0.35,0.40),  // 左腕だけ上（画面左）
                .leftWrist:  p(0.62,0.02), .rightWrist:  p(0.32,0.55),
                .leftHip:  p(0.55,0.55), .rightHip:  p(0.45,0.55),
                .leftKnee: p(0.55,0.75), .rightKnee: p(0.45,0.75),
                .leftAnkle: p(0.55,0.95), .rightAnkle: p(0.45,0.95),
            ]

        // Lv2 ─────────────────────────────────────────
        case .tPose:
            return [
                .nose: p(0.50,0.08), .neck: p(0.50,0.18),
                .leftShoulder:  p(0.60,0.25), .rightShoulder: p(0.40,0.25),
                .leftElbow:  p(0.80,0.25), .rightElbow:  p(0.20,0.25),
                .leftWrist:  p(0.95,0.25), .rightWrist:  p(0.05,0.25),
                .leftHip:  p(0.54,0.55), .rightHip:  p(0.46,0.55),
                .leftKnee: p(0.54,0.75), .rightKnee: p(0.46,0.75),
                .leftAnkle: p(0.54,0.95), .rightAnkle: p(0.46,0.95),
            ]

        case .jumpingJack:
            return [
                .nose: p(0.50,0.08), .neck: p(0.50,0.18),
                .leftShoulder:  p(0.60,0.25), .rightShoulder: p(0.40,0.25),
                .leftElbow:  p(0.75,0.18), .rightElbow:  p(0.25,0.18),
                .leftWrist:  p(0.85,0.08), .rightWrist:  p(0.15,0.08),
                .leftHip:  p(0.55,0.55), .rightHip:  p(0.45,0.55),
                .leftKnee: p(0.65,0.75), .rightKnee: p(0.35,0.75),
                .leftAnkle: p(0.72,0.95), .rightAnkle: p(0.28,0.95),
            ]

        case .squat:
            return [
                .nose: p(0.50,0.20), .neck: p(0.50,0.28),
                .leftShoulder:  p(0.60,0.35), .rightShoulder: p(0.40,0.35),
                .leftElbow:  p(0.65,0.50), .rightElbow:  p(0.35,0.50),
                .leftWrist:  p(0.68,0.62), .rightWrist:  p(0.32,0.62),
                .leftHip:  p(0.58,0.62), .rightHip:  p(0.42,0.62),
                .leftKnee: p(0.62,0.78), .rightKnee: p(0.38,0.78),
                .leftAnkle: p(0.62,0.95), .rightAnkle: p(0.38,0.95),
            ]

        case .rightLegUp:
            return [
                .nose: p(0.50,0.08), .neck: p(0.50,0.18),
                .leftShoulder:  p(0.60,0.25), .rightShoulder: p(0.40,0.25),
                .leftElbow:  p(0.65,0.40), .rightElbow:  p(0.35,0.40),
                .leftWrist:  p(0.68,0.55), .rightWrist:  p(0.32,0.55),
                .leftHip:  p(0.55,0.55), .rightHip:  p(0.45,0.55),
                .leftKnee: p(0.55,0.75), .rightKnee: p(0.45,0.42),  // 右膝を上げる（画面右）
                .leftAnkle: p(0.55,0.95), .rightAnkle: p(0.45,0.32),
            ]

        case .leftLegUp:
            return [
                .nose: p(0.50,0.08), .neck: p(0.50,0.18),
                .leftShoulder:  p(0.60,0.25), .rightShoulder: p(0.40,0.25),
                .leftElbow:  p(0.65,0.40), .rightElbow:  p(0.35,0.40),
                .leftWrist:  p(0.68,0.55), .rightWrist:  p(0.32,0.55),
                .leftHip:  p(0.55,0.55), .rightHip:  p(0.45,0.55),
                .leftKnee: p(0.55,0.42), .rightKnee: p(0.45,0.75),  // 左膝を上げる（画面左）
                .leftAnkle: p(0.55,0.32), .rightAnkle: p(0.45,0.95),
            ]

        // Lv3 ─────────────────────────────────────────
        case .rightLunge:
            return [
                .nose: p(0.50,0.12), .neck: p(0.50,0.22),
                .leftShoulder:  p(0.60,0.30), .rightShoulder: p(0.40,0.30),
                .leftElbow:  p(0.65,0.45), .rightElbow:  p(0.35,0.45),
                .leftWrist:  p(0.68,0.58), .rightWrist:  p(0.32,0.58),
                .leftHip:  p(0.57,0.58), .rightHip:  p(0.43,0.58),
                .leftKnee: p(0.57,0.85), .rightKnee: p(0.35,0.72),  // 右膝が前に出る（画面右）
                .leftAnkle: p(0.57,0.97), .rightAnkle: p(0.35,0.90),
            ]

        case .leftLunge:
            return [
                .nose: p(0.50,0.12), .neck: p(0.50,0.22),
                .leftShoulder:  p(0.60,0.30), .rightShoulder: p(0.40,0.30),
                .leftElbow:  p(0.65,0.45), .rightElbow:  p(0.35,0.45),
                .leftWrist:  p(0.68,0.58), .rightWrist:  p(0.32,0.58),
                .leftHip:  p(0.57,0.58), .rightHip:  p(0.43,0.58),
                .leftKnee: p(0.65,0.72), .rightKnee: p(0.43,0.85),  // 左膝が前に出る（画面左）
                .leftAnkle: p(0.65,0.90), .rightAnkle: p(0.43,0.97),
            ]

        case .armsUpRightLegUp:
            return [
                .nose: p(0.50,0.08), .neck: p(0.50,0.18),
                .leftShoulder:  p(0.60,0.25), .rightShoulder: p(0.40,0.25),
                .leftElbow:  p(0.62,0.12), .rightElbow:  p(0.38,0.12),
                .leftWrist:  p(0.62,0.02), .rightWrist:  p(0.38,0.02),
                .leftHip:  p(0.55,0.55), .rightHip:  p(0.45,0.55),
                .leftKnee: p(0.55,0.75), .rightKnee: p(0.45,0.42),  // 右膝を上げる
                .leftAnkle: p(0.55,0.95), .rightAnkle: p(0.45,0.35),
            ]

        case .armsUpLeftLegUp:
            return [
                .nose: p(0.50,0.08), .neck: p(0.50,0.18),
                .leftShoulder:  p(0.60,0.25), .rightShoulder: p(0.40,0.25),
                .leftElbow:  p(0.62,0.12), .rightElbow:  p(0.38,0.12),
                .leftWrist:  p(0.62,0.02), .rightWrist:  p(0.38,0.02),
                .leftHip:  p(0.55,0.55), .rightHip:  p(0.45,0.55),
                .leftKnee: p(0.55,0.42), .rightKnee: p(0.45,0.75),  // 左膝を上げる
                .leftAnkle: p(0.55,0.35), .rightAnkle: p(0.45,0.95),
            ]

        case .starPose:
            return [
                .nose: p(0.50,0.07), .neck: p(0.50,0.17),
                .leftShoulder:  p(0.62,0.24), .rightShoulder: p(0.38,0.24),
                .leftElbow:  p(0.82,0.16), .rightElbow:  p(0.18,0.16),
                .leftWrist:  p(0.95,0.05), .rightWrist:  p(0.05,0.05),
                .leftHip:  p(0.55,0.55), .rightHip:  p(0.45,0.55),
                .leftKnee: p(0.70,0.73), .rightKnee: p(0.30,0.73),
                .leftAnkle: p(0.80,0.95), .rightAnkle: p(0.20,0.95),
            ]
        }
    }

    func calculateScore(observation: VNHumanBodyPoseObservation) -> Int {
        let names: [VNHumanBodyPoseObservation.JointName] = [
            .nose, .neck, .leftShoulder, .rightShoulder,
            .leftElbow, .rightElbow, .leftWrist, .rightWrist,
            .leftHip, .rightHip, .leftKnee, .rightKnee, .leftAnkle, .rightAnkle
        ]
        var current: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
        for j in names {
            guard let pt = try? observation.recognizedPoint(j), pt.confidence > 0.3 else { continue }
            current[j] = CGPoint(x: pt.location.x, y: 1 - pt.location.y)
        }
        guard current.count >= 4 else { return 0 }
        return Int(PoseEstimator().score(current: current, target: targetJoints) * 100)
    }

    private func p(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x, y: y) }
}
