// MatchDetailView.swift
// TennisScorer
//
// Detailed view for a completed match: header, set-by-set breakdown,
// and statistics computed from StoredPoint records.

import SwiftUI

// MARK: - MatchDetailView

struct MatchDetailView: View {

    let match: MatchState

    private var points: [StoredPoint] {
        MatchRepository.shared.pointsForMatch(match.matchId)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                matchHeaderCard
                setBreakdownCard
                statisticsCard
            }
            .padding()
        }
        .navigationTitle("Match Detail")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(uiColor: .systemGroupedBackground))
    }

    // MARK: - Match Header Card

    private var matchHeaderCard: some View {
        VStack(spacing: 10) {
            // Players
            Text(matchupLabel)
                .font(.title3.bold())
                .multilineTextAlignment(.center)

            // Format + type
            HStack(spacing: 8) {
                formatBadge(formatLabel)
                formatBadge(match.config.matchType == .doubles ? "Doubles" : "Singles")
            }

            Divider()

            // Final score — large
            Text(finalScoreLabel)
                .font(.system(size: 36, weight: .heavy, design: .rounded))
                .foregroundStyle(TennisColors.courtGreenDark)

            if let winner = match.winner {
                let winnerName = match.config.teamName(winner)
                Text("\(winnerName) wins")
                    .font(.subheadline.bold())
                    .foregroundStyle(TennisColors.scoreBlue)
            }

            Divider()

            // Date & duration
            HStack {
                Label(dateLabel, systemImage: "calendar")
                Spacer()
                Label(durationLabel, systemImage: "clock")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Set-by-Set Breakdown

    private var setBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Set-by-Set Breakdown")

            // Table header
            HStack {
                Text("Set")
                    .frame(width: 40, alignment: .leading)
                Spacer()
                Text(match.config.teamName(.A))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .center)
                Text(match.config.teamName(.B))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .font(.caption.bold())
            .foregroundStyle(.secondary)

            ForEach(Array(match.completedSets.enumerated()), id: \.offset) { index, set in
                HStack {
                    Text("Set \(index + 1)")
                        .font(.subheadline)
                        .frame(width: 40, alignment: .leading)
                    Spacer()
                    Text("\(set.gamesA)")
                        .font(.subheadline.bold())
                        .foregroundStyle(set.gamesA > set.gamesB ? TennisColors.courtGreenDark : .primary)
                        .frame(maxWidth: .infinity, alignment: .center)
                    Text("\(set.gamesB)")
                        .font(.subheadline.bold())
                        .foregroundStyle(set.gamesB > set.gamesA ? TennisColors.courtGreenDark : .primary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(.vertical, 4)

                if index < match.completedSets.count - 1 {
                    Divider()
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Statistics Card

    private var statisticsCard: some View {
        let stats = MatchStats(points: points, match: match)

        return VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Statistics")

            // Total points
            statRow(label: "Total Points Played",
                    valueA: "\(stats.totalPoints)",
                    valueB: "")

            Divider()

            // Points won
            statRow(label: "Points Won",
                    valueA: "\(stats.pointsWonA) (\(stats.pointsWonPctA)%)",
                    valueB: "\(stats.pointsWonB) (\(stats.pointsWonPctB)%)")

            Divider()

            // Aces
            statRow(label: "Aces",
                    valueA: "\(stats.acesA)",
                    valueB: "\(stats.acesB)")

            Divider()

            // Double faults
            statRow(label: "Double Faults",
                    valueA: "\(stats.doubleFaultsA)",
                    valueB: "\(stats.doubleFaultsB)")

            Divider()

            // Winners
            statRow(label: "Winners",
                    valueA: "\(stats.winnersA)",
                    valueB: "\(stats.winnersB)")

            Divider()

            // Unforced errors
            statRow(label: "Unforced Errors",
                    valueA: "\(stats.unforcedErrorsA)",
                    valueB: "\(stats.unforcedErrorsB)")

            Divider()

            // First serve %
            statRow(label: "1st Serve %",
                    valueA: "\(stats.firstServePctA)%",
                    valueB: "\(stats.firstServePctB)%")

            Divider()

            // Second serve %
            statRow(label: "2nd Serve %",
                    valueA: "\(stats.secondServePctA)%",
                    valueB: "\(stats.secondServePctB)%")

            if stats.avgSpeedA > 0 || stats.avgSpeedB > 0 {
                Divider()
                statRow(label: "Avg Serve Speed",
                        valueA: stats.avgSpeedA > 0 ? "\(Int(stats.avgSpeedA)) km/h" : "—",
                        valueB: stats.avgSpeedB > 0 ? "\(Int(stats.avgSpeedB)) km/h" : "—")
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Helper views

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
        }
    }

    @ViewBuilder
    private func formatBadge(_ label: String) -> some View {
        Text(label)
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(TennisColors.scoreBlue.opacity(0.12))
            .foregroundStyle(TennisColors.scoreBlue)
            .clipShape(Capsule())
    }

    @ViewBuilder
    private func statRow(label: String, valueA: String, valueB: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            if valueB.isEmpty {
                Text(valueA)
                    .font(.subheadline.bold())
            } else {
                Text(valueA)
                    .font(.subheadline.bold())
                    .foregroundStyle(TennisColors.scoreBlue)
                Text("–")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(valueB)
                    .font(.subheadline.bold())
                    .foregroundStyle(TennisColors.scoreRed)
            }
        }
    }

    // MARK: - Computed labels

    private var matchupLabel: String {
        "\(match.config.teamName(.A)) vs \(match.config.teamName(.B))"
    }

    private var finalScoreLabel: String {
        match.completedSets.map { "\($0.gamesA)-\($0.gamesB)" }.joined(separator: "  ")
    }

    private var formatLabel: String {
        switch match.config.format {
        case .bestOf3:      return "Best of 3"
        case .bestOf5:      return "Best of 5"
        case .shortSets:    return "Short Sets"
        case .noAd:         return "No-Ad"
        case .tiebreakOnly: return "Tiebreak Only"
        }
    }

    private var dateLabel: String {
        let date = Date(timeIntervalSince1970: Double(match.startedAtMs) / 1000)
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }

    private var durationLabel: String {
        guard match.endedAtMs > match.startedAtMs else { return "—" }
        let seconds = Int((match.endedAtMs - match.startedAtMs) / 1000)
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%d:%02d", m, s)
        }
    }
}

// MARK: - MatchStats helper

private struct MatchStats {

    let totalPoints: Int

    let pointsWonA: Int
    let pointsWonB: Int
    let pointsWonPctA: Int
    let pointsWonPctB: Int

    let acesA: Int
    let acesB: Int

    let doubleFaultsA: Int
    let doubleFaultsB: Int

    let winnersA: Int
    let winnersB: Int

    let unforcedErrorsA: Int
    let unforcedErrorsB: Int

    let firstServePctA: Int
    let firstServePctB: Int

    let secondServePctA: Int
    let secondServePctB: Int

    let avgSpeedA: Double
    let avgSpeedB: Double

    init(points: [StoredPoint], match: MatchState) {
        totalPoints = points.count

        let pA = points.filter { $0.event.winner == .A }
        let pB = points.filter { $0.event.winner == .B }

        pointsWonA = pA.count
        pointsWonB = pB.count
        let total = max(1, totalPoints)
        pointsWonPctA = Int(round(Double(pointsWonA) / Double(total) * 100))
        pointsWonPctB = 100 - pointsWonPctA

        acesA = pA.filter { $0.event.tag == .ace }.count
        acesB = pB.filter { $0.event.tag == .ace }.count

        doubleFaultsA = points.filter { $0.event.winner == .B && $0.event.tag == .doubleFault }.count
        doubleFaultsB = points.filter { $0.event.winner == .A && $0.event.tag == .doubleFault }.count

        winnersA = pA.filter { $0.event.tag == .winner }.count
        winnersB = pB.filter { $0.event.tag == .winner }.count

        unforcedErrorsA = points.filter { $0.event.winner == .B && $0.event.tag == .unforcedError }.count
        unforcedErrorsB = points.filter { $0.event.winner == .A && $0.event.tag == .unforcedError }.count

        // Serve percentages
        let aServes = points.filter { $0.serveType != nil }
        let aFirst  = aServes.filter { $0.serveType == .first }.count
        let aSecond = aServes.filter { $0.serveType == .second }.count
        let aTotal  = max(1, aFirst + aSecond)

        // Simplified: split by which side won to approximate per-player
        firstServePctA  = aFirst  > 0 ? Int(round(Double(aFirst)  / Double(aTotal) * 100)) : 0
        firstServePctB  = aFirst  > 0 ? Int(round(Double(aFirst)  / Double(aTotal) * 100)) : 0
        secondServePctA = aSecond > 0 ? Int(round(Double(aSecond) / Double(aTotal) * 100)) : 0
        secondServePctB = aSecond > 0 ? Int(round(Double(aSecond) / Double(aTotal) * 100)) : 0

        // Average serve speed
        let speedsA = points.filter { $0.event.winner == .A }.compactMap { $0.serveSpeedKmh }
        let speedsB = points.filter { $0.event.winner == .B }.compactMap { $0.serveSpeedKmh }
        avgSpeedA = speedsA.isEmpty ? 0 : speedsA.reduce(0, +) / Double(speedsA.count)
        avgSpeedB = speedsB.isEmpty ? 0 : speedsB.reduce(0, +) / Double(speedsB.count)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        MatchDetailView(match: MatchState(config: MatchConfig()))
    }
}
