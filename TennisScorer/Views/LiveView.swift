// LiveView.swift
// TennisScorer
//
// Shows the current match score card or an empty state when no match is active.
// Supports scoring from iPhone or Apple Watch, and shows a completion card
// with share options when a match finishes.

import SwiftUI

// MARK: - ScoringDevice

private enum ScoringDevice: String, CaseIterable {
    case phone = "Phone"
    case watch = "Watch"
}

// MARK: - LiveView

struct LiveView: View {

    @EnvironmentObject var mainViewModel: MainViewModel
    @ObservedObject private var watchSync = WatchSyncManager.shared
    @Binding var selectedTab: AppTab

    @State private var showEndMatchAlert  = false
    @State private var showPhoneScoring   = false
    @State private var showWatchStatus    = false

    var body: some View {
        NavigationStack {
            Group {
                if let scoringVM = mainViewModel.scoringViewModel {
                    ActiveMatchView(
                        viewModel:         scoringVM,
                        selectedTab:       $selectedTab,
                        showPhoneScoring:  $showPhoneScoring,
                        showEndMatchAlert: $showEndMatchAlert
                    )
                } else {
                    EmptyMatchView(selectedTab: $selectedTab)
                }
            }
            .navigationTitle("Live")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let vm = mainViewModel.scoringViewModel, !vm.isMatchOver {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        HStack(spacing: 12) {
                            CastButtonView()
                                .frame(width: 24, height: 24)
                            Button { showWatchStatus = true } label: {
                                Image(systemName: watchSync.isWatchReachable
                                      ? "applewatch.radiowaves.left.and.right"
                                      : "applewatch")
                                    .foregroundStyle(watchSync.isWatchReachable
                                                     ? TennisColors.courtGreenDark
                                                     : .secondary)
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showPhoneScoring) {
            if let vm = mainViewModel.scoringViewModel {
                PhoneScoringView(viewModel: vm)
            }
        }
        .alert("End Match?", isPresented: $showEndMatchAlert) {
            Button("End Match", role: .destructive) { mainViewModel.endMatch() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The current match will be saved and marked as complete.")
        }
        .alert("Apple Watch", isPresented: $showWatchStatus) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(watchSync.isWatchReachable
                 ? "Watch is connected and ready to score."
                 : "Watch is not reachable. Make sure the Tennis Scorer app is open on your Watch.")
        }
    }
}

// MARK: - EmptyMatchView

private struct EmptyMatchView: View {

    @Binding var selectedTab: AppTab
    @EnvironmentObject var mainViewModel: MainViewModel

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground).ignoresSafeArea()
            VStack(spacing: 20) {
                // Resume card — shown when a match was left in progress
                if let pending = mainViewModel.inProgressMatch {
                    resumeCard(for: pending)
                        .padding(.horizontal, 24)
                }

                Text("🎾")
                    .font(.system(size: 64))
                Text("No active match")
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
                Text("Set up a new match to get started.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Start a Match") {
                    selectedTab = .setup
                }
                .buttonStyle(.borderedProminent)
                .tint(TennisColors.courtGreenDark)
            }
            .padding(.horizontal, 32)
        }
    }

    @ViewBuilder
    private func resumeCard(for match: MatchState) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Match in Progress", systemImage: "clock.arrow.circlepath")
                .font(.caption.bold())
                .foregroundStyle(TennisColors.tennisBall)

            Text("\(match.config.teamName(.A)) vs \(match.config.teamName(.B))")
                .font(.subheadline.bold())
                .lineLimit(1)

            let sets = match.completedSets.map { "\($0.gamesA)-\($0.gamesB)" }.joined(separator: "  ")
            if !sets.isEmpty {
                Text(sets)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                mainViewModel.resumeMatch(match)
            } label: {
                Text("Resume Match")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(TennisColors.courtGreenDark)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(TennisColors.courtGreenDark.opacity(0.4), lineWidth: 1)
        )
    }
}

// MARK: - ActiveMatchView

private struct ActiveMatchView: View {

    @ObservedObject var viewModel: PhoneScoringViewModel
    @ObservedObject private var speaker = ScoreSpeaker.shared
    @Binding var selectedTab: AppTab
    @Binding var showPhoneScoring: Bool
    @Binding var showEndMatchAlert: Bool
    @EnvironmentObject var mainViewModel: MainViewModel

    @State private var scoringDevice: ScoringDevice = .phone

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: 16) {
                    ScoreCardView(viewModel: viewModel)
                        .padding(.horizontal)

                    if viewModel.isMatchOver {
                        MatchCompletedCard(viewModel: viewModel, selectedTab: $selectedTab)
                            .padding(.horizontal)
                    } else {
                        scoringControls
                    }
                }
                .padding(.top)
            }
            .background(Color(uiColor: .systemBackground))

            // Score announcement banner
            if let announcement = speaker.announcementText {
                Text("🔊  \(announcement)")
                    .font(.subheadline.bold())
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .shadow(radius: 4)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.3), value: announcement)
            }
        }
    }

    private var scoringControls: some View {
        VStack(spacing: 12) {
            // Phone / Watch picker
            Picker("Score on", selection: $scoringDevice) {
                ForEach(ScoringDevice.allCases, id: \.self) { device in
                    Text(device.rawValue).tag(device)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .onChange(of: scoringDevice) { device in
                WatchSyncManager.shared.sendScoringMode(device == .phone ? "phone" : "watch")
            }

            if scoringDevice == .phone {
                Button {
                    showPhoneScoring = true
                } label: {
                    Label("Score on Phone", systemImage: "hand.tap.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(TennisColors.scoreBlue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal)
            } else {
                WatchScoringCard()
                    .padding(.horizontal)
            }

            Button(role: .destructive) {
                showEndMatchAlert = true
            } label: {
                Label("End Match", systemImage: "stop.circle")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(uiColor: .secondarySystemBackground))
                    .foregroundStyle(.red)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - MatchCompletedCard

private struct MatchCompletedCard: View {

    @ObservedObject var viewModel: PhoneScoringViewModel
    @Binding var selectedTab: AppTab
    @EnvironmentObject var mainViewModel: MainViewModel

    var body: some View {
        VStack(spacing: 16) {
            // Header
            VStack(spacing: 8) {
                Text("🏆")
                    .font(.system(size: 52))
                Text("Match Complete")
                    .font(.title2.bold())
                if let winner = viewModel.matchState.winner {
                    Text("\(viewModel.matchState.config.teamName(winner)) wins!")
                        .font(.headline)
                        .foregroundStyle(TennisColors.tennisBall)
                }
                Text(finalScoreText)
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(TennisColors.courtGreenDark)
            }

            Divider()

            // Share result
            ShareLink(item: shareText) {
                Label("Share Result", systemImage: "square.and.arrow.up")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(uiColor: .tertiarySystemBackground))
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            // View stats
            NavigationLink {
                MatchDetailView(match: viewModel.matchState)
            } label: {
                Label("View Stats", systemImage: "chart.bar.fill")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(TennisColors.scoreBlue.opacity(0.1))
                    .foregroundStyle(TennisColors.scoreBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            // New match
            Button {
                mainViewModel.clearCompletedMatch()
                selectedTab = .setup
            } label: {
                Label("New Match", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(TennisColors.courtGreenDark)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var finalScoreText: String {
        viewModel.matchState.completedSets.map { "\($0.gamesA)-\($0.gamesB)" }.joined(separator: "  ")
    }

    private var shareText: String {
        let state  = viewModel.matchState
        let config = state.config
        var lines  = [
            "🎾 Tennis Match Result",
            "",
            "\(config.teamName(.A)) vs \(config.teamName(.B))",
            "Score: \(finalScoreText)",
        ]
        if let winner = state.winner {
            lines.append("\(config.teamName(winner)) wins!")
        }
        lines += ["", "Format: \(formatLabel(config.format))", "Scored with Tennis Scorer"]
        return lines.joined(separator: "\n")
    }

    private func formatLabel(_ format: MatchFormat) -> String {
        switch format {
        case .bestOf3:      return "Best of 3"
        case .bestOf5:      return "Best of 5"
        case .shortSets:    return "Short Sets"
        case .noAd:         return "No-Ad"
        case .tiebreakOnly: return "Tiebreak Only"
        }
    }
}

// MARK: - WatchScoringCard

private struct WatchScoringCard: View {
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "applewatch")
                .font(.system(size: 30))
                .foregroundStyle(TennisColors.courtGreenDark)
            VStack(alignment: .leading, spacing: 4) {
                Text("Scoring on Watch")
                    .font(.headline)
                Text("Use your Apple Watch to award points. The score syncs automatically.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(TennisColors.courtGreenDark.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14)
            .stroke(TennisColors.courtGreenDark.opacity(0.25), lineWidth: 1))
    }
}

// MARK: - ScoreCardView

struct ScoreCardView: View {

    @ObservedObject var viewModel: PhoneScoringViewModel

    var body: some View {
        let state  = viewModel.matchState
        let config = state.config

        VStack(spacing: 12) {
            SetScoresRow(state: state)
            Divider().background(Color.white.opacity(0.3))
            PlayerScoreRow(name: config.teamName(.A), isServing: state.server == .A && !viewModel.isMatchOver, gamesInSet: state.currentGamesA)
            PlayerScoreRow(name: config.teamName(.B), isServing: state.server == .B && !viewModel.isMatchOver, gamesInSet: state.currentGamesB)
            if !viewModel.isMatchOver {
                Divider().background(Color.white.opacity(0.3))
                Text(viewModel.currentPointScore)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(TennisColors.tennisBall)
                SituationBadge(situation: viewModel.gameSituation)
            }
            Text(viewModel.matchDuration)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
                .monospacedDigit()
        }
        .padding()
        .background(TennisColors.courtGreenDark)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 4)
    }
}

// MARK: - SetScoresRow

private struct SetScoresRow: View {
    let state: MatchState

    var body: some View {
        HStack {
            Text("Sets")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
            Spacer()
            ForEach(Array(state.completedSets.enumerated()), id: \.offset) { _, set in
                VStack(spacing: 2) {
                    Text("\(set.gamesA)").font(.caption.bold()).foregroundStyle(.white)
                    Text("\(set.gamesB)").font(.caption.bold()).foregroundStyle(.white.opacity(0.7))
                }
                .frame(width: 24)
            }
            if state.winner == nil {
                VStack(spacing: 2) {
                    Text("\(state.currentGamesA)").font(.caption.bold()).foregroundStyle(TennisColors.tennisBall)
                    Text("\(state.currentGamesB)").font(.caption.bold()).foregroundStyle(TennisColors.tennisBall.opacity(0.7))
                }
                .frame(width: 24)
            }
        }
    }
}

// MARK: - PlayerScoreRow

private struct PlayerScoreRow: View {
    let name: String
    let isServing: Bool
    let gamesInSet: Int

    var body: some View {
        HStack {
            Circle()
                .fill(isServing ? TennisColors.tennisBall : Color.clear)
                .frame(width: 8, height: 8)
            Text(name)
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .lineLimit(1)
            Spacer()
            Text("\(gamesInSet)")
                .font(.subheadline.bold())
                .foregroundStyle(.white)
        }
    }
}

// MARK: - SituationBadge

struct SituationBadge: View {
    let situation: GameSituation

    var body: some View {
        if situation.type != .none {
            Text(situationLabel)
                .font(.caption.bold())
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(badgeColor.opacity(0.2))
                .foregroundStyle(badgeColor)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(badgeColor, lineWidth: 1))
        }
    }

    private var situationLabel: String {
        switch situation.type {
        case .none:       return ""
        case .matchPoint: return "MATCH POINT"
        case .setPoint:   return "SET POINT"
        case .breakPoint: return "BREAK POINT"
        case .gamePoint:  return "GAME POINT"
        }
    }

    private var badgeColor: Color {
        switch situation.type {
        case .none:       return .clear
        case .matchPoint: return TennisColors.matchPointGold
        case .setPoint:   return TennisColors.tennisBall
        case .breakPoint: return TennisColors.scoreRed
        case .gamePoint:  return .white
        }
    }
}

// MARK: - Preview

struct LiveView_Previews: PreviewProvider {
    static var previews: some View {
        LiveView(selectedTab: .constant(.live))
            .environmentObject(MainViewModel())
            .environmentObject(AppSettings.shared)
    }
}
