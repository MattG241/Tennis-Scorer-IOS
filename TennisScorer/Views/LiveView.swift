// LiveView.swift
// TennisScorer
//
// Shows the current match score card or an empty state when no match is active.

import SwiftUI

// MARK: - LiveView

struct LiveView: View {

    @EnvironmentObject var mainViewModel: MainViewModel
    @Binding var selectedTab: AppTab

    @State private var showEndMatchAlert = false
    @State private var showPhoneScoring = false

    var body: some View {
        NavigationStack {
            Group {
                if let scoringVM = mainViewModel.scoringViewModel {
                    ActiveMatchView(
                        viewModel: scoringVM,
                        showPhoneScoring: $showPhoneScoring,
                        showEndMatchAlert: $showEndMatchAlert
                    )
                } else {
                    EmptyMatchView()
                }
            }
            .navigationTitle("Live")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if mainViewModel.scoringViewModel != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        // Cast button (placeholder)
                        Button {
                            // Cast action – wired up when Cast support is integrated
                        } label: {
                            Image(systemName: "circle.radiowaves.right")
                                .foregroundStyle(TennisColors.tennisBall)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showPhoneScoring) {
            if let scoringVM = mainViewModel.scoringViewModel {
                PhoneScoringView(viewModel: scoringVM)
            }
        }
        .alert("End Match?", isPresented: $showEndMatchAlert) {
            Button("End Match", role: .destructive) {
                mainViewModel.endMatch()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("The current match will be saved and marked as complete.")
        }
    }
}

// MARK: - EmptyMatchView

private struct EmptyMatchView: View {

    @State private var dotOpacity: Double = 0.3

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("🎾")
                    .font(.system(size: 64))

                Text("No active match")
                    .font(.title2.bold())
                    .foregroundStyle(.primary)

                Text("Start a match from Setup")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // Pulsing yellow dot
                Circle()
                    .fill(TennisColors.tennisBall)
                    .frame(width: 10, height: 10)
                    .opacity(dotOpacity)
                    .onAppear {
                        withAnimation(
                            .easeInOut(duration: 1.1)
                            .repeatForever(autoreverses: true)
                        ) {
                            dotOpacity = 1.0
                        }
                    }
            }
        }
    }
}

// MARK: - ActiveMatchView

private struct ActiveMatchView: View {

    @ObservedObject var viewModel: PhoneScoringViewModel
    @Binding var showPhoneScoring: Bool
    @Binding var showEndMatchAlert: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Score card
                ScoreCardView(viewModel: viewModel)
                    .padding(.horizontal)

                // Action buttons
                VStack(spacing: 12) {
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

                    Button(role: .destructive) {
                        showEndMatchAlert = true
                    } label: {
                        Label("End Match", systemImage: "trash")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(uiColor: .secondarySystemBackground))
                            .foregroundStyle(.red)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(.horizontal)
            }
            .padding(.top)
        }
        .background(Color(uiColor: .systemBackground))
    }
}

// MARK: - ScoreCardView

struct ScoreCardView: View {

    @ObservedObject var viewModel: PhoneScoringViewModel

    var body: some View {
        let state = viewModel.matchState
        let config = state.config

        VStack(spacing: 12) {
            // Set scores row
            SetScoresRow(state: state)

            Divider()
                .background(Color.white.opacity(0.3))

            // Player rows
            PlayerScoreRow(
                name: config.teamName(.A),
                isServing: state.server == .A,
                gamesInSet: state.currentGamesA
            )
            PlayerScoreRow(
                name: config.teamName(.B),
                isServing: state.server == .B,
                gamesInSet: state.currentGamesB
            )

            Divider()
                .background(Color.white.opacity(0.3))

            // Current point score
            Text(viewModel.currentPointScore)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(TennisColors.tennisBall)

            // Situation badge
            SituationBadge(situation: viewModel.gameSituation)

            // Match duration
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
                    Text("\(set.gamesA)")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                    Text("\(set.gamesB)")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.7))
                }
                .frame(width: 24)
            }
            // Current set
            VStack(spacing: 2) {
                Text("\(state.currentGamesA)")
                    .font(.caption.bold())
                    .foregroundStyle(TennisColors.tennisBall)
                Text("\(state.currentGamesB)")
                    .font(.caption.bold())
                    .foregroundStyle(TennisColors.tennisBall.opacity(0.7))
            }
            .frame(width: 24)
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
            if isServing {
                Circle()
                    .fill(TennisColors.tennisBall)
                    .frame(width: 8, height: 8)
            } else {
                Circle()
                    .fill(Color.clear)
                    .frame(width: 8, height: 8)
            }
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

#Preview {
    LiveView(selectedTab: .constant(.live))
        .environmentObject(MainViewModel())
        .environmentObject(AppSettings.shared)
}
