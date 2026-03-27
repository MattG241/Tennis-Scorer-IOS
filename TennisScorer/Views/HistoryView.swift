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

    var body: some View {
        NavigationStack {
            Group {
                if completedMatches.isEmpty {
                    emptyStateView
                } else {
                    List {
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

            // Final score
            Text(finalScoreLabel)
                .font(.caption.bold())
                .foregroundStyle(TennisColors.courtGreenDark)

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
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    HistoryView()
}
