import Vision
import CoreGraphics

final class PoseTemplateRepository: @unchecked Sendable {

    static let shared = PoseTemplateRepository()

    private init() {}

    func random() -> PoseTemplate {
        templates.randomElement()!
    }

    func random(excludingName name: String) -> PoseTemplate {
        guard templates.count > 1 else {
            return random()
        }

        if let next = templates.filter({ $0.name != name }).randomElement() {
            return next
        }

        return random()
    }

    private let templates: [PoseTemplate] = [
        // 1. 基本の立ちポーズ
        PoseTemplate(
            name: "Stand Straight",
            joints: [
                .nose: CGPoint(x: 0.5, y: 0.15),
                .neck: CGPoint(x: 0.5, y: 0.2),
                .leftShoulder: CGPoint(x: 0.4, y: 0.25),
                .rightShoulder: CGPoint(x: 0.6, y: 0.25),
                .leftElbow: CGPoint(x: 0.35, y: 0.4),
                .rightElbow: CGPoint(x: 0.65, y: 0.4),
                .leftWrist: CGPoint(x: 0.32, y: 0.55),
                .rightWrist: CGPoint(x: 0.68, y: 0.55),
                .leftHip: CGPoint(x: 0.45, y: 0.55),
                .rightHip: CGPoint(x: 0.55, y: 0.55),
                .leftKnee: CGPoint(x: 0.45, y: 0.75),
                .rightKnee: CGPoint(x: 0.55, y: 0.75),
                .leftAnkle: CGPoint(x: 0.45, y: 0.95),
                .rightAnkle: CGPoint(x: 0.55, y: 0.95)
            ]
        ),
        
        // 2. 両腕を上げるポーズ
        PoseTemplate(
            name: "Arms Up",
            joints: [
                .nose: CGPoint(x: 0.5, y: 0.15),
                .neck: CGPoint(x: 0.5, y: 0.2),
                .leftShoulder: CGPoint(x: 0.4, y: 0.25),
                .rightShoulder: CGPoint(x: 0.6, y: 0.25),
                .leftElbow: CGPoint(x: 0.38, y: 0.15),
                .rightElbow: CGPoint(x: 0.62, y: 0.15),
                .leftWrist: CGPoint(x: 0.4, y: 0.05),
                .rightWrist: CGPoint(x: 0.6, y: 0.05),
                .leftHip: CGPoint(x: 0.45, y: 0.55),
                .rightHip: CGPoint(x: 0.55, y: 0.55),
                .leftKnee: CGPoint(x: 0.45, y: 0.75),
                .rightKnee: CGPoint(x: 0.55, y: 0.75),
                .leftAnkle: CGPoint(x: 0.45, y: 0.95),
                .rightAnkle: CGPoint(x: 0.55, y: 0.95)
            ]
        ),
        
        // 3. T-ポーズ（両腕を横に伸ばす）
        PoseTemplate(
            name: "T-Pose",
            joints: [
                .nose: CGPoint(x: 0.5, y: 0.15),
                .neck: CGPoint(x: 0.5, y: 0.2),
                .leftShoulder: CGPoint(x: 0.4, y: 0.25),
                .rightShoulder: CGPoint(x: 0.6, y: 0.25),
                .leftElbow: CGPoint(x: 0.2, y: 0.25),
                .rightElbow: CGPoint(x: 0.8, y: 0.25),
                .leftWrist: CGPoint(x: 0.05, y: 0.25),
                .rightWrist: CGPoint(x: 0.95, y: 0.25),
                .leftHip: CGPoint(x: 0.45, y: 0.55),
                .rightHip: CGPoint(x: 0.55, y: 0.55),
                .leftKnee: CGPoint(x: 0.45, y: 0.75),
                .rightKnee: CGPoint(x: 0.55, y: 0.75),
                .leftAnkle: CGPoint(x: 0.45, y: 0.95),
                .rightAnkle: CGPoint(x: 0.55, y: 0.95)
            ]
        ),
        
        // 4. 片足を上げるポーズ
        PoseTemplate(
            name: "One Leg Up",
            joints: [
                .nose: CGPoint(x: 0.5, y: 0.15),
                .neck: CGPoint(x: 0.5, y: 0.2),
                .leftShoulder: CGPoint(x: 0.4, y: 0.25),
                .rightShoulder: CGPoint(x: 0.6, y: 0.25),
                .leftElbow: CGPoint(x: 0.35, y: 0.4),
                .rightElbow: CGPoint(x: 0.65, y: 0.4),
                .leftWrist: CGPoint(x: 0.32, y: 0.55),
                .rightWrist: CGPoint(x: 0.68, y: 0.55),
                .leftHip: CGPoint(x: 0.45, y: 0.55),
                .rightHip: CGPoint(x: 0.55, y: 0.55),
                .leftKnee: CGPoint(x: 0.45, y: 0.75),
                .rightKnee: CGPoint(x: 0.55, y: 0.45),  // 右膝を上げる
                .leftAnkle: CGPoint(x: 0.45, y: 0.95),
                .rightAnkle: CGPoint(x: 0.55, y: 0.35)   // 右足首も上げる
            ]
        ),
        
        // 5. スクワットポーズ
        PoseTemplate(
            name: "Squat",
            joints: [
                .nose: CGPoint(x: 0.5, y: 0.25),
                .neck: CGPoint(x: 0.5, y: 0.3),
                .leftShoulder: CGPoint(x: 0.4, y: 0.35),
                .rightShoulder: CGPoint(x: 0.6, y: 0.35),
                .leftElbow: CGPoint(x: 0.35, y: 0.5),
                .rightElbow: CGPoint(x: 0.65, y: 0.5),
                .leftWrist: CGPoint(x: 0.32, y: 0.65),
                .rightWrist: CGPoint(x: 0.68, y: 0.65),
                .leftHip: CGPoint(x: 0.45, y: 0.65),
                .rightHip: CGPoint(x: 0.55, y: 0.65),
                .leftKnee: CGPoint(x: 0.4, y: 0.8),
                .rightKnee: CGPoint(x: 0.6, y: 0.8),
                .leftAnkle: CGPoint(x: 0.4, y: 0.95),
                .rightAnkle: CGPoint(x: 0.6, y: 0.95)
            ]
        ),
        
        // 6. ジャンピングジャック（腕と足を広げる）
        PoseTemplate(
            name: "Jumping Jack",
            joints: [
                .nose: CGPoint(x: 0.5, y: 0.15),
                .neck: CGPoint(x: 0.5, y: 0.2),
                .leftShoulder: CGPoint(x: 0.4, y: 0.25),
                .rightShoulder: CGPoint(x: 0.6, y: 0.25),
                .leftElbow: CGPoint(x: 0.25, y: 0.2),
                .rightElbow: CGPoint(x: 0.75, y: 0.2),
                .leftWrist: CGPoint(x: 0.15, y: 0.1),
                .rightWrist: CGPoint(x: 0.85, y: 0.1),
                .leftHip: CGPoint(x: 0.45, y: 0.55),
                .rightHip: CGPoint(x: 0.55, y: 0.55),
                .leftKnee: CGPoint(x: 0.35, y: 0.75),
                .rightKnee: CGPoint(x: 0.65, y: 0.75),
                .leftAnkle: CGPoint(x: 0.3, y: 0.95),
                .rightAnkle: CGPoint(x: 0.7, y: 0.95)
            ]
        )
    ]
}
