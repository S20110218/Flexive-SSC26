import SwiftUI

struct CameraView: View {
    @StateObject private var vm = HomeViewModel() // Using HomeViewModel
    
    var body: some View {
        ZStack {
            // カメラプレビュー（背景）
            CameraPreview(session: vm.captureSession)
                .edgesIgnoringSafeArea(.all)
            
            // 検出された体のスケルトン（緑色）
            SkeletonOverlayView(joints: vm.userJoints, color: .green)
                .edgesIgnoringSafeArea(.all)
            
            // ターゲットポーズのスケルトン（青色・半透明）
            // Assuming PoseTemplate has a 'joints' property
            SkeletonOverlayView(joints: vm.currentPoseTemplate.joints, color: .blue.opacity(0.5))
                .frame(width: 300, height: 500)
                .position(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2)
            
            VStack {
                Text("Score: \(vm.score, specifier: "%.0f")")
                    .foregroundColor(.white)
                    .font(.title)
                
                Button("Load Next Pose") {
                    vm.loadNextPose()
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
        .onAppear { vm.startSession() }
        .onDisappear { vm.stopSession() }
    }
}
