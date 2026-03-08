import SwiftUI

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

struct RootView: View {
    // UserDefaults で「次回から表示しない」を管理
    @State private var showIntro: Bool = !UserDefaults.standard.bool(forKey: "introVideoSkipped")

    var body: some View {
        ZStack {
            HomeView()

            if showIntro {
                IntroVideoView(isPresented: $showIntro)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: showIntro)
    }
}
