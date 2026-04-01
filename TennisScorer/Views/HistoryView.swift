// HistoryView.swift
// TennisScorer
//
// List of completed matches with swipe-to-delete and tap to view detail.

import SwiftUI

// MARK: - HistoryView

struct HistoryView: View {

    @ObservedObject private var repository = MatchRepository.shared

    @State private var matchToDelete: MatchState? = nil
    @State private var showDeleteConfirm = false

    private var completedMatches: [MatchState] {
        repository.allMatches
            .filter { $0.winner != nil }
            .sorted { $0.startedAtMs > $1.startedAtMs }
    }

    private var abandonedMatches: [MatchState] {
        repository.allMatches
            .filter { $0.winner == nil }
            .sorted { $0.startedAtMs > $1.startedAtMs }
    }

    var body: some View {
        NavigationStack {
            Group {
                if completedMatches.isEmpty && abandonedMatches.isEmpty {
                    emptyStateView
                } else {
                    List {
                        if !abandonedMatches.isEmpty {
                            Section("In Progress") {
                                ForEach(abandonedMatches) { match in
                                    MatchHistoryRow(match: match)
                                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                            Button(role: .destructive) {
                                                matchToDelete = match
                                                showDeleteConfirm = true
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                        }

                        if !completedMatches.isEmpty {
                            Section("Completed") {
                                ForEach(completedMatches) { match in
                                    NavigationLink {
                                        MatchDetailView(match: match)
                                    } label: {
                                        MatchHistoryRow(match: match)
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) {
                                            matchToDelete = match
                                            showDeleteConfirm = true
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                        ShareLink(item: shareText(for: match)) {
                                            Label("Share", systemImage: "square.and.arrow.up")
                                        }
                                        .tint(TennisColors.scoreBlue)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("History")
            .onAppear {
                repository.loadAll()
            }
        }
        .alert("Delete Match?", isPresented: $showDeleteConfirm, presenting: matchToDelete) { match in
            Button("Delete", role: .destructive) {
                repository.deleteMatch(match.matchId)
            }
            Button("Cancel", role: .cancel) { }
        } message: { match in
            Text("Delete the match between \(match.config.teamName(.A)) and \(match.config.teamName(.B))? This cannot be undone.")
        }
    }

    // MARK: - Share helper

    private func shareText(for match: MatchState) -> String {
        let sets = match.completedSets.map { "\($0.gamesA)-\($0.gamesB)" }.joined(separator: "  ")
        var lines = [
            "🎾 Tennis Match Result",
            "",
            "\(match.config.teamName(.A)) vs \(match.config.teamName(.B))",
            "Score: \(sets)",
        ]
        if let winner = match.winner {
            lines.append("\(match.config.teamName(winner)) wins!")
        }
        lines += ["", "Scored with Tennis Scorer"]
        return lines.joined(separator: "\n")
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Text("🎾")
                .font(.system(size: 56))
            Text("No completed matches yet")
                .font(.title3.bold())
            Text("Finish a match to see it here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - MatchHistoryRow

struct MatchHistoryRow: View {

    let match: MatchState

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                // Matchup
                Text(matchupLabel)
                    .font(.subheadline.bold())
                    .lineLimit(1)

                Spacer()

                // Format badge
                Text(formatLabel)
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(TennisColors.scoreBlue.opacity(0.15))
                    .foregroundStyle(TennisColors.scoreBlue)
                    .clipShape(Capsule())
            }

            // Final score + winner
            HStack(spacing: 6) {
                Text(finalScoreLabel)
                    .font(.caption.bold())
                    .foregroundStyle(TennisColors.courtGreenDark)

                if let winner = match.winner {
                    Text("·")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(match.config.teamName(winner)) wins")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            // Date
            Text(dateLabel)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var matchupLabel: String {
        "\(match.config.teamName(.A)) vs \(match.config.teamName(.B))"
    }

    private var finalScoreLabel: String {
        let sets = match.completedSets
        if sets.isEmpty { return "—" }
        return sets.map { "\($0.gamesA)-\($0.gamesB)" }.joined(separator: "  ")
    }

    private var formatLabel: String {
        switch match.config.format {
        case .bestOf3:      return "Bo3"
        case .bestOf5:      return "Bo5"
        case .shortSets:    return "Short"
        case .noAd:         return "No-Ad"
        case .tiebreakOnly: return "TB"
        }
    }

    private var dateLabel: String {
        let date = Date(timeIntervalSince1970: Double(match.startedAtMs) / 1000)
        return Self.rowDateFormatter.string(from: date)
    }

    private static let rowDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()
}

// MARK: - Preview

struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        HistoryView()
    }
}
