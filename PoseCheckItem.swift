import Vision

struct PoseCheckItem: Identifiable {
    let id = UUID()
    let name: String
    let joint: VNHumanBodyPoseObservation.JointName
    var isDetected: Bool = false
}
