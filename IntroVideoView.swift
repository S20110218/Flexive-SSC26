import SwiftUI
import AVKit

struct IntroVideoView: View {
    @Binding var isPresented: Bool
    @State private var player: AVPlayer?
    @State private var dontShowAgain: Bool = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // 動画プレイヤー
            if let player = player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
            } else {
                // 動画が見つからない場合のフォールバック
                VStack(spacing: 16) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.white.opacity(0.5))
                    Text("Failed to load video")
                        .foregroundColor(.white.opacity(0.7))
                        .font(.subheadline)
                }
            }

            // オーバーレイUI
            VStack {
                // 上部: 「次回から表示しない」チェックボックス
                HStack {
                    Spacer()
                    Button(action: {
                        dontShowAgain.toggle()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: dontShowAgain ? "checkmark.square.fill" : "square")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                            Text("Don't show again")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.55))
                        .cornerRadius(20)
                    }
                    .padding(.top, 56)
                    .padding(.trailing, 20)
                }

                Spacer()

                // 下部: スキップボタン
                HStack {
                    Spacer()
                    Button(action: {
                        dismissIntro()
                    }) {
                        HStack(spacing: 8) {
                            Text("Skip")
                                .font(.system(size: 16, weight: .bold))
                            Image(systemName: "forward.fill")
                                .font(.system(size: 14))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [.blue, .purple]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(25)
                        .shadow(color: .blue.opacity(0.4), radius: 8, x: 0, y: 4)
                    }
                    .padding(.bottom, 48)
                    .padding(.trailing, 24)
                }
            }
        }
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            player?.pause()
        }
    }

    private func setupPlayer() {
        // 動画ファイル名を "intro_video" (拡張子 .mp4) として検索
        // Swift Playgrounds ではプロジェクト内に動画ファイルを追加してください
        if let url = Bundle.main.url(forResource: "intro_video", withExtension: "mp4") {
            let avPlayer = AVPlayer(url: url)
            self.player = avPlayer
            avPlayer.play()

            // 動画終了時に自動で閉じる
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: avPlayer.currentItem,
                queue: .main
            ) { _ in
                dismissIntro()
            }
        }
    }

    private func dismissIntro() {
        if dontShowAgain {
            UserDefaults.standard.set(true, forKey: "introVideoSkipped")
        }
        player?.pause()
        isPresented = false
    }
}
