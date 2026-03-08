import AVFoundation
import AudioToolbox
import SwiftUI

final class SoundPlayer: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = SoundPlayer()

    private var player: AVAudioPlayer?
    private var changePlayer: AVAudioPlayer?
    private var countdownPlayer: AVAudioPlayer?
    private let synthesizer = AVSpeechSynthesizer()

    private lazy var okSoundData: Data? = {
        let asset = NSDataAsset(name: "ok") ?? NSDataAsset(name: "OK")
        return asset?.data
    }()

    private lazy var changeSoundData: Data? = {
        let asset = NSDataAsset(name: "change") ?? NSDataAsset(name: "Change")
        return asset?.data
    }()

    private override init() {
        super.init()
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: .mixWithOthers)
        try? AVAudioSession.sharedInstance().setActive(true)
        synthesizer.delegate = self
    }

    // デリゲート：前フレーズ完了→次を読む（必ずメインスレッドで）
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.pendingPhrases.isEmpty else { return }
            let next = self.pendingPhrases.removeFirst()
            self.speak(next)
        }
    }

    // カウントダウンビープ（pitch: 高いほど高音）
    func playCountdownBeep(pitch: Float = 880, duration: Double = 0.12) {
        let sampleRate: Double = 44100
        let frameCount = Int(sampleRate * duration)
        var samples = [Int16](repeating: 0, count: frameCount)
        for i in 0..<frameCount {
            let t = Double(i) / sampleRate
            // フェードアウトで自然な音に
            let envelope = max(0, 1.0 - t / duration)
            samples[i] = Int16(32767 * envelope * sin(2 * .pi * Double(pitch) * t))
        }
        let data = samples.withUnsafeBytes { Data($0) }
        // WAVヘッダーを付けて AVAudioPlayer で再生
        var wav = Data()
        let dataSize = UInt32(data.count)
        let sampleRateU = UInt32(sampleRate)
        wav.append(contentsOf: "RIFF".utf8)
        wav.append(uint32LE: dataSize + 36)
        wav.append(contentsOf: "WAVEfmt ".utf8)
        wav.append(uint32LE: 16)       // chunk size
        wav.append(uint16LE: 1)        // PCM
        wav.append(uint16LE: 1)        // mono
        wav.append(uint32LE: sampleRateU)
        wav.append(uint32LE: sampleRateU * 2)  // byte rate
        wav.append(uint16LE: 2)        // block align
        wav.append(uint16LE: 16)       // bits per sample
        wav.append(contentsOf: "data".utf8)
        wav.append(uint32LE: dataSize)
        wav.append(data)
        do {
            countdownPlayer = try AVAudioPlayer(data: wav, fileTypeHint: AVFileType.wav.rawValue)
            countdownPlayer?.volume = 0.8
            countdownPlayer?.play()
        } catch {}
    }

    // GO! のファンファーレ（上昇音）
    func playGoSound() {
        let sampleRate: Double = 44100
        let duration: Double = 0.5
        let frameCount = Int(sampleRate * duration)
        var samples = [Int16](repeating: 0, count: frameCount)
        let pitches: [Float] = [660, 880, 1100]
        for i in 0..<frameCount {
            let t = Double(i) / sampleRate
            let pitchIdx = min(Int(t / (duration / Double(pitches.count))), pitches.count - 1)
            let pitch = Double(pitches[pitchIdx])
            let envelope = max(0, 1.0 - (t / duration) * 0.5)
            samples[i] = Int16(32767 * 0.7 * envelope * sin(2 * .pi * pitch * t))
        }
        let data = samples.withUnsafeBytes { Data($0) }
        var wav = Data()
        let dataSize = UInt32(data.count)
        let sampleRateU = UInt32(sampleRate)
        wav.append(contentsOf: "RIFF".utf8)
        wav.append(uint32LE: dataSize + 36)
        wav.append(contentsOf: "WAVEfmt ".utf8)
        wav.append(uint32LE: 16)
        wav.append(uint16LE: 1)
        wav.append(uint16LE: 1)
        wav.append(uint32LE: sampleRateU)
        wav.append(uint32LE: sampleRateU * 2)
        wav.append(uint16LE: 2)
        wav.append(uint16LE: 16)
        wav.append(contentsOf: "data".utf8)
        wav.append(uint32LE: dataSize)
        wav.append(data)
        do {
            countdownPlayer = try AVAudioPlayer(data: wav, fileTypeHint: AVFileType.wav.rawValue)
            countdownPlayer?.volume = 0.9
            countdownPlayer?.play()
        } catch {}
    }

    // ポーズ成功音（change.mp3 を流用。ok.m4a は使わない）
    func playOkSound() {
        playChangeSound()
    }

    // ポーズ切り替え音（change.mp3）
    func playChangeSound() {
        guard let changeSoundData else {
            #if DEBUG
            print("Sound asset 'change' not found. Skipping sound playback.")
            #endif
            return
        }
        do {
            changePlayer = try AVAudioPlayer(data: changeSoundData)
            changePlayer?.volume = 0.9
            changePlayer?.play()
        } catch {
            #if DEBUG
            print("Failed to play change sound: \(error.localizedDescription)")
            #endif
        }
    }

    // 複数フレーズを順番に読み上げる（"Practice Mode!" → ポーズ名など）
    func speakPoseSequence(_ phrases: [String]) {
        guard !phrases.isEmpty else { return }
        synthesizer.stopSpeaking(at: .immediate)
        pendingPhrases = Array(phrases.dropFirst())
        speak(phrases[0])
    }

    private var pendingPhrases: [String] = []

    private func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.58
        utterance.pitchMultiplier = 1.1
        utterance.volume = 1.0
        utterance.postUtteranceDelay = 0.3
        synthesizer.speak(utterance)
    }

    // ポーズ名を読み上げ（単発）
    func speakPose(_ announcementText: String) {
        synthesizer.stopSpeaking(at: .immediate)
        pendingPhrases = []
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.speak(announcementText)
        }
    }
}

// MARK: - WAV書き込みヘルパー
private extension Data {
    mutating func append(uint16LE value: UInt16) {
        var v = value.littleEndian
        append(Data(bytes: &v, count: 2))
    }
    mutating func append(uint32LE value: UInt32) {
        var v = value.littleEndian
        append(Data(bytes: &v, count: 4))
    }
}
