import Vision
import CoreGraphics

struct PoseTemplate: Sendable {
    let name: String
    let joints: [VNHumanBodyPoseObservation.JointName: CGPoint]
}
