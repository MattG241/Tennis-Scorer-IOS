import Foundation
import AVFoundation

class WalkoutPlayer: ObservableObject {
    static let shared = WalkoutPlayer()

    @Published var isPlaying: Bool = false
    @Published var currentSong: String? = nil

    private var player: AVAudioPlayer?

    private init() {}

    /// Returns all walkout song filenames from the app bundle's walkout_songs folder.
    func listSongs() -> [String] {
        guard let url = Bundle.main.url(forResource: "walkout_songs", withExtension: nil),
              let contents = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
        else { return [] }

        return contents
            .filter { $0.pathExtension.lowercased() == "mp3" }
            .map { $0.deletingPathExtension().lastPathComponent }
            .sorted()
    }

    /// Plays the named walkout song. Stops any currently playing song first.
    func play(_ filename: String) {
        stop()

        guard let url = Bundle.main.url(forResource: filename, withExtension: "mp3", subdirectory: "walkout_songs")
        else {
            print("[WalkoutPlayer] Song not found: \(filename)")
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, options: [.mixWithOthers])
            try session.setActive(true)

            player = try AVAudioPlayer(contentsOf: url)
            player?.play()
            isPlaying = true
            currentSong = filename
        } catch {
            print("[WalkoutPlayer] Playback error: \(error)")
        }
    }

    /// Stops any currently playing walkout song.
    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        currentSong = nil
    }
}
