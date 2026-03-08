import SwiftUI

struct ResultView: View {
    let point: Int
    let onNext: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.2, green: 0.3, blue: 0.6),
                    Color(red: 0.4, green: 0.2, blue: 0.6)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Text("🎉")
                    .font(.system(size: 80))
                
                Text("SUCCESS!")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                VStack(spacing: 10) {
                    Text("Score")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text("\(point)")
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                        .foregroundColor(.yellow)
                }
                
                Button(action: onNext) {
                    HStack {
                        Text("Next Pose")
                            .font(.system(size: 24, weight: .semibold))
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 24))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 50)
                    .padding(.vertical, 20)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.green, Color.mint]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(30)
                    .shadow(color: .green.opacity(0.5), radius: 15, x: 0, y: 5)
                }
            }
        }
    }
}
