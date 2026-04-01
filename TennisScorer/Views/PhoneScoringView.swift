// PhoneScoringView.swift
// TennisScorer
//
// Full-screen scoring interface with large tap targets for each player,
// point tag chips, undo, serve speed, and a match-won overlay.

import SwiftUI

// MARK: - PhoneScoringView

struct PhoneScoringView: View {

    @ObservedObject var viewModel: PhoneScoringViewModel
    @ObservedObject private var walkoutPlayer = WalkoutPlayer.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showDismissAlert = false
    @State private var showSpeedInput = false

    // Press-animation scale per player
    @State private var scaleA: CGFloat = 1.0
    @State private var scaleB: CGFloat = 1.0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(uiColor: .systemBackground).ignoresSafeArea()

                VStack(spacing: 0) {
                    // TOP ~28%: Score card
                    scoreCardSection
                        .frame(height: geo.size.height * (hasWalkoutSongs ? 0.25 : 0.28))

                    // Walkout music bar (if songs configured)
                    if hasWalkoutSongs {
                        walkoutBar
                            .frame(height: geo.size.height * 0.06)
                    }

                    // MIDDLE ~50%: Player tap buttons
                    playerButtonSection
                        .frame(height: geo.size.height * (hasWalkoutSongs ? 0.47 : 0.50))

                    // BOTTOM ~22%: Control bar
                    controlBarSection
                        .frame(height: geo.size.height * 0.22)
                }

                // Match won overlay
                if viewModel.isMatchOver {
                    matchWonOverlay
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.isMatchOver)
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .navigationTitle(matchTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .onAppear  { UIApplication.shared.isIdleTimerDisabled = true  }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    if viewModel.isMatchOver {
                        dismiss()
                    } else {
                        showDismissAlert = true
                    }
                } label: {
                    Image(systemName: "xmark")
                        .fontWeight(.semibold)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                CastButtonView()
                    .frame(width: 24, height: 24)
            }
        }
        .alert("Leave Scoring?", isPresented: $showDismissAlert) {
            Button("Leave", role: .destructive) { dismiss() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("The match is still in progress. You can resume it from the Live tab.")
        }
        .sheet(isPresented: $showSpeedInput) {
            SpeedInputSheet(speedKmh: viewModel.lastServeSpeedKmh) { speed in
                viewModel.lastServeSpeedKmh = speed
            }
        }
    }

    // MARK: - Score Card

    private var scoreCardSection: some View {
        let state = viewModel.matchState
        let config = state.config

        return VStack(spacing: 6) {
            // Set scores table
            HStack(spacing: 0) {
                // Player A row
                VStack(alignment: .leading, spacing: 4) {
                    playerNameLabel(config.teamName(.A), isServing: state.server == .A)
                    playerNameLabel(config.teamName(.B), isServing: state.server == .B)
                }
                Spacer()

                // Completed sets
                ForEach(Array(state.completedSets.enumerated()), id: \.offset) { _, set in
                    VStack(spacing: 4) {
                        Text("\(set.gamesA)")
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                        Text("\(set.gamesB)")
                            .font(.subheadline.bold())
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .frame(width: 28)
                }

                // Current set games
                VStack(spacing: 4) {
                    Text("\(state.currentGamesA)")
                        .font(.subheadline.bold())
                        .foregroundStyle(TennisColors.tennisBall)
                    Text("\(state.currentGamesB)")
                        .font(.subheadline.bold())
                        .foregroundStyle(TennisColors.tennisBall.opacity(0.7))
                }
                .frame(width: 28)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            // Current point score
            Button {
                viewModel.speakScore()
            } label: {
                Text(viewModel.currentPointScore)
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                    .foregroundStyle(TennisColors.tennisBall)
            }
            .buttonStyle(.plain)

            // Situation badge
            SituationBadge(situation: viewModel.gameSituation)

            // Match timer
            Text(viewModel.matchDuration)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
                .monospacedDigit()

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .background(TennisColors.courtGreenDark)
    }

    @ViewBuilder
    private func playerNameLabel(_ name: String, isServing: Bool) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isServing ? TennisColors.tennisBall : Color.clear)
                .frame(width: 7, height: 7)
            Text(name)
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .lineLimit(1)
        }
    }

    // MARK: - Player Buttons

    private var playerButtonSection: some View {
        let config = viewModel.matchState.config
        let isAServing = viewModel.matchState.server == .A
        let isBServing = viewModel.matchState.server == .B

        return HStack(spacing: 0) {
            // Player A button
            ScoringPlayerButton(
                playerName: config.teamName(.A),
                isServing: isAServing,
                backgroundColor: TennisColors.scoreBlue,
                scale: $scaleA
            ) {
                awardPoint(to: .A)
            }

            // Player B button
            ScoringPlayerButton(
                playerName: config.teamName(.B),
                isServing: isBServing,
                backgroundColor: TennisColors.courtGreenDark,
                scale: $scaleB
            ) {
                awardPoint(to: .B)
            }
        }
    }

    // MARK: - Control Bar

    private var controlBarSection: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 0) {
                // Undo button
                Button {
                    viewModel.undoLastPoint()
                } label: {
                    Image(systemName: "arrow.uturn.backward.circle")
                        .font(.title2)
                        .foregroundStyle(viewModel.canUndo ? .primary : .tertiary)
                        .frame(width: 56, height: 56)
                }
                .disabled(!viewModel.canUndo)

                // Point tag chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        // 1st / 2nd serve toggle
                        ServeTypeChip(
                            label: "1st",
                            isSelected: viewModel.selectedServeType == .first
                        ) { viewModel.selectedServeType = .first }

                        ServeTypeChip(
                            label: "2nd",
                            isSelected: viewModel.selectedServeType == .second
                        ) { viewModel.selectedServeType = .second }

                        Rectangle()
                            .fill(Color(uiColor: .separator))
                            .frame(width: 1, height: 20)
                            .padding(.horizontal, 2)

                        // Point outcome tags (excluding Normal — it's the implicit default)
                        ForEach(PointTag.allCases.filter { $0 != .normal }, id: \.self) { tag in
                            PointTagChip(
                                tag: tag,
                                isSelected: viewModel.selectedPointTag == tag
                            ) {
                                viewModel.selectedPointTag = (viewModel.selectedPointTag == tag) ? .normal : tag
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                }

                // Serve speed
                Button {
                    showSpeedInput = true
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "speedometer")
                            .font(.title3)
                        if let speed = viewModel.lastServeSpeedKmh {
                            Text("\(Int(speed))")
                                .font(.caption2.bold())
                        }
                    }
                    .foregroundStyle(.primary)
                    .frame(width: 56, height: 56)
                }
            }
            .padding(.horizontal, 4)
            .frame(maxHeight: .infinity)
        }
        .background(Color(uiColor: .secondarySystemBackground))
    }

    // MARK: - Match Won Overlay

    private var matchWonOverlay: some View {
        ZStack {
            Color.black.opacity(0.75).ignoresSafeArea()

            VStack(spacing: 20) {
                Text("🏆")
                    .font(.system(size: 72))

                Text("Match Won!")
                    .font(.title.bold())
                    .foregroundStyle(.white)

                if let winner = viewModel.matchState.winner {
                    let winnerName = winner == .A
                        ? viewModel.matchState.config.teamName(.A)
                        : viewModel.matchState.config.teamName(.B)
                    Text(winnerName)
                        .font(.title2.bold())
                        .foregroundStyle(TennisColors.tennisBall)
                }

                Text(finalScoreText)
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.85))

                ShareLink(item: overlayShareText) {
                    Label("Share Result", systemImage: "square.and.arrow.up")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
                .tint(.white)

                HStack(spacing: 16) {
                    Button("New Match") {
                        viewModel.requestNewMatch()
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)

                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(TennisColors.courtGreenDark)
                }
                .padding(.top, 4)
            }
            .padding(32)
            .background(Color(uiColor: .systemBackground).opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Walkout Bar

    private var hasWalkoutSongs: Bool {
        viewModel.matchState.config.walkoutSongA != nil || viewModel.matchState.config.walkoutSongB != nil
    }

    private var walkoutBar: some View {
        let config = viewModel.matchState.config
        return HStack(spacing: 8) {
            Image(systemName: "music.note")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let songA = config.walkoutSongA {
                Button {
                    if walkoutPlayer.isPlaying && walkoutPlayer.currentSong == songA {
                        walkoutPlayer.stop()
                    } else {
                        walkoutPlayer.play(songA)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: walkoutPlayer.isPlaying && walkoutPlayer.currentSong == songA ? "stop.fill" : "play.fill")
                            .font(.caption2)
                        Text(config.teamName(.A))
                            .font(.caption2)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(TennisColors.scoreBlue.opacity(0.15))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            if let songB = config.walkoutSongB {
                Button {
                    if walkoutPlayer.isPlaying && walkoutPlayer.currentSong == songB {
                        walkoutPlayer.stop()
                    } else {
                        walkoutPlayer.play(songB)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: walkoutPlayer.isPlaying && walkoutPlayer.currentSong == songB ? "stop.fill" : "play.fill")
                            .font(.caption2)
                        Text(config.teamName(.B))
                            .font(.caption2)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(TennisColors.courtGreenDark.opacity(0.15))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            if walkoutPlayer.isPlaying {
                Button {
                    walkoutPlayer.stop()
                } label: {
                    Image(systemName: "stop.circle")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .secondarySystemBackground))
    }

    // MARK: - Helpers

    private var matchTitle: String {
        let cfg = viewModel.matchState.config
        return "\(cfg.teamName(.A)) vs \(cfg.teamName(.B))"
    }

    private var finalScoreText: String {
        let sets = viewModel.matchState.completedSets
        return sets.map { "\($0.gamesA)-\($0.gamesB)" }.joined(separator: "  ")
    }

    private var overlayShareText: String {
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
        lines += ["", "Scored with Tennis Scorer"]
        return lines.joined(separator: "\n")
    }

    private func awardPoint(to side: PlayerSide) {
        // Stop walkout music on first point scored
        walkoutPlayer.stop()

        // Haptic feedback
        let haptic = UIImpactFeedbackGenerator(style: .medium)
        haptic.impactOccurred()

        // Spring press animation
        let scaleBinding = side == .A ? $scaleA : $scaleB
        withAnimation(.spring(response: 0.12, dampingFraction: 0.7)) {
            scaleBinding.wrappedValue = 0.96
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.13) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                scaleBinding.wrappedValue = 1.0
            }
        }
        viewModel.awardPoint(to: side)
    }
}

// MARK: - ScoringPlayerButton

private struct ScoringPlayerButton: View {

    let playerName: String
    let isServing: Bool
    let backgroundColor: Color
    @Binding var scale: CGFloat
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                backgroundColor

                VStack(spacing: 12) {
                    Text(playerName)
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)

                    // Always reserve space for the badge to prevent layout jumps.
                    Text("SERVING")
                        .font(.caption.bold())
                        .foregroundStyle(TennisColors.tennisBall)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .overlay(
                            Capsule()
                                .stroke(TennisColors.tennisBall, lineWidth: 1)
                        )
                        .opacity(isServing ? 1 : 0)

                    // +1 indicator circle (decorative)
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                            .frame(width: 44, height: 44)
                        Text("+1")
                            .font(.subheadline.bold())
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .padding()
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scaleEffect(scale)
    }
}

// MARK: - PointTagChip

private struct PointTagChip: View {

    let tag: PointTag
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(tagLabel)
                .font(.caption.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? chipColor : Color(uiColor: .tertiarySystemBackground))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var tagLabel: String {
        switch tag {
        case .normal:       return "Normal"
        case .ace:          return "Ace"
        case .doubleFault:  return "DF"
        case .winner:       return "Win"
        case .unforcedError: return "UE"
        }
    }

    private var chipColor: Color {
        switch tag {
        case .normal:       return .gray
        case .ace:          return TennisColors.tennisBall
        case .doubleFault:  return TennisColors.scoreRed
        case .winner:       return TennisColors.scoreBlue
        case .unforcedError: return .orange
        }
    }
}

// MARK: - ServeTypeChip

private struct ServeTypeChip: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.caption.bold())
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isSelected ? TennisColors.courtGreenDark : Color(uiColor: .tertiarySystemBackground))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - SpeedInputSheet

private struct SpeedInputSheet: View {

    let speedKmh: Double?
    let onSave: (Double?) -> Void

    @State private var text: String = ""
    @Environment(\.dismiss) private var dismiss

    init(speedKmh: Double?, onSave: @escaping (Double?) -> Void) {
        self.speedKmh = speedKmh
        self.onSave = onSave
        _text = State(initialValue: speedKmh.map { String(Int($0)) } ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Serve Speed (km/h)") {
                    TextField("e.g. 180", text: $text)
                        .keyboardType(.numberPad)
                }
                Section {
                    Button("Clear Speed") {
                        onSave(nil)
                        dismiss()
                    }
                    .foregroundStyle(.red)
                }
            }
            .navigationTitle("Serve Speed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(Double(text))
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.fraction(0.35)])
    }
}
