import AVFoundation

/// Plays the code-generated 8-bit WAVs. One AVAudioPlayer per effect.
final class SoundManager {
    static let shared = SoundManager()

    private var players: [String: AVAudioPlayer] = [:]
    private(set) var muted = false
    private var wakaFlip = false

    private init() {
        let names = ["intro", "waka1", "waka2", "siren", "fright", "eat_ghost",
                     "eat_fruit", "death", "extra", "eyes"]
        for name in names {
            guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else {
                continue
            }
            if let player = try? AVAudioPlayer(contentsOf: url) {
                player.prepareToPlay()
                players[name] = player
            }
        }
        for loop in ["siren", "fright", "eyes"] {
            players[loop]?.numberOfLoops = -1
            players[loop]?.volume = 0.4
        }
    }

    func toggleMute() {
        muted.toggle()
        if muted { stopLoops() }
    }

    func play(_ name: String) {
        guard !muted, let player = players[name] else { return }
        if player.isPlaying { player.currentTime = 0 } else { player.play() }
    }

    func waka() {
        wakaFlip.toggle()
        play(wakaFlip ? "waka1" : "waka2")
    }

    /// Keep exactly one background loop running: "siren", "fright",
    /// "eyes" or nil.
    func setLoop(_ name: String?) {
        for loop in ["siren", "fright", "eyes"] {
            let player = players[loop]
            if loop == name, !muted {
                if player?.isPlaying != true { player?.play() }
            } else if player?.isPlaying == true {
                player?.stop()
                player?.currentTime = 0
            }
        }
    }

    func stopLoops() { setLoop(nil) }
}
