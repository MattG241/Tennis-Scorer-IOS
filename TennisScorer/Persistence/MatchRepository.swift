import Foundation
import Combine

// MARK: - StoredPoint

struct StoredPoint: Codable, Identifiable {
    var id: Int
    var matchId: String
    var event: PointEvent
    var serveType: ServeType?
    var serveSpeedKmh: Double?
}

// MARK: - MatchRepository

class MatchRepository: ObservableObject {
    static let shared = MatchRepository()

    @Published var allMatches: [MatchState] = []

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private var matchesFileURL: URL {
        documentsURL.appendingPathComponent("matches.json")
    }

    private func pointsFileURL(for matchId: String) -> URL {
        documentsURL.appendingPathComponent("points_\(matchId).json")
    }

    private init() {
        encoder.outputFormatting = .prettyPrinted
    }

    // MARK: - Public API

    /// Loads all matches from disk. Call once at app start.
    func loadAll() {
        allMatches = loadMatches()
    }

    /// Upserts a match by matchId into the stored list.
    func saveMatchState(_ state: MatchState) {
        var matches = loadMatches()
        if let idx = matches.firstIndex(where: { $0.matchId == state.matchId }) {
            matches[idx] = state
        } else {
            matches.append(state)
        }
        saveMatches(matches)
        DispatchQueue.main.async {
            self.allMatches = matches
        }
    }

    /// Appends a point event to the per-match points file.
    func savePointEvent(_ event: PointEvent, serveType: ServeType?, speedKmh: Double?) {
        var points = loadPoints(for: event.matchId)
        let stored = StoredPoint(
            id: points.count,
            matchId: event.matchId,
            event: event,
            serveType: serveType,
            serveSpeedKmh: speedKmh
        )
        points.append(stored)
        savePoints(points, for: event.matchId)
    }

    /// Deletes a match and its associated points file.
    func deleteMatch(_ matchId: String) {
        var matches = loadMatches()
        matches.removeAll { $0.matchId == matchId }
        saveMatches(matches)
        DispatchQueue.main.async {
            self.allMatches = matches
        }
        let pointsURL = pointsFileURL(for: matchId)
        try? FileManager.default.removeItem(at: pointsURL)
    }

    /// Returns all stored points for a given match.
    func pointsForMatch(_ matchId: String) -> [StoredPoint] {
        loadPoints(for: matchId)
    }

    // MARK: - Private file I/O

    private func loadMatches() -> [MatchState] {
        guard FileManager.default.fileExists(atPath: matchesFileURL.path) else { return [] }
        do {
            let data = try Data(contentsOf: matchesFileURL)
            return try decoder.decode([MatchState].self, from: data)
        } catch {
            print("[MatchRepository] Failed to load matches: \(error)")
            return []
        }
    }

    private func saveMatches(_ matches: [MatchState]) {
        do {
            let data = try encoder.encode(matches)
            try data.write(to: matchesFileURL, options: .atomic)
        } catch {
            print("[MatchRepository] Failed to save matches: \(error)")
        }
    }

    private func loadPoints(for matchId: String) -> [StoredPoint] {
        let url = pointsFileURL(for: matchId)
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode([StoredPoint].self, from: data)
        } catch {
            print("[MatchRepository] Failed to load points for \(matchId): \(error)")
            return []
        }
    }

    private func savePoints(_ points: [StoredPoint], for matchId: String) {
        let url = pointsFileURL(for: matchId)
        do {
            let data = try encoder.encode(points)
            try data.write(to: url, options: .atomic)
        } catch {
            print("[MatchRepository] Failed to save points for \(matchId): \(error)")
        }
    }
}
