// SetupView.swift
// TennisScorer
//
// Match setup form: player names, format, first server, voice mode, voice picker and coin toss.

import SwiftUI

// MARK: - SetupView

struct SetupView: View {

    @EnvironmentObject var mainViewModel: MainViewModel
    @EnvironmentObject var settings: AppSettings
    @ObservedObject private var speaker = ScoreSpeaker.shared
    @ObservedObject private var watchSync = WatchSyncManager.shared
    @ObservedObject private var walkoutPlayer = WalkoutPlayer.shared

    @Binding var selectedTab: AppTab

    // MARK: Form state
    @State private var matchType: MatchType = .singles
    @State private var playerA: String = ""
    @State private var playerB: String = ""
    @State private var playerA2: String = ""
    @State private var playerB2: String = ""
    @State private var format: MatchFormat = .bestOf3
    @State private var firstServer: PlayerSide = .A
    @State private var voiceMode: VoiceCalloutMode = .withPlayerNames
    @State private var walkoutSongA: String? = nil
    @State private var walkoutSongB: String? = nil

    // Coin toss
    @State private var coinRotation: Double = 0
    @State private var isTossing: Bool = false
    @State private var tossResultLabel: String? = nil

    // Replace alert
    @State private var showReplaceAlert = false
    @State private var pendingAction: PendingStartAction? = nil

    private enum PendingStartAction {
        case phone
        case watch
    }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Match Type
                Section("Match Type") {
                    Picker("Type", selection: $matchType) {
                        Text("Singles").tag(MatchType.singles)
                        Text("Doubles").tag(MatchType.doubles)
                    }
                    .pickerStyle(.segmented)
                }

                // MARK: Player Names
                Section("Players") {
                    TextField("Player A name", text: $playerA)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.words)

                    if matchType == .doubles {
                        TextField("Player A2 name (partner)", text: $playerA2)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.words)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    TextField("Player B name", text: $playerB)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.words)

                    if matchType == .doubles {
                        TextField("Player B2 name (partner)", text: $playerB2)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.words)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: matchType)

                // MARK: Format
                Section("Format") {
                    Picker("Format", selection: $format) {
                        ForEach(MatchFormat.allCases, id: \.self) { f in
                            Text(formatDisplayName(f)).tag(f)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(TennisColors.scoreBlue)
                }

                // MARK: First Server
                Section("First Server") {
                    HStack(spacing: 12) {
                        serverButton(side: .A, label: displayName(.A))
                        serverButton(side: .B, label: displayName(.B))
                    }
                }

                // MARK: Coin Toss
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Text("🪙")
                                .font(.system(size: 44))
                                .rotation3DEffect(
                                    .degrees(coinRotation),
                                    axis: (x: 0, y: 1, z: 0)
                                )

                            Button(isTossing ? "Tossing…" : "Coin Toss") {
                                performCoinToss()
                            }
                            .disabled(isTossing)
                            .buttonStyle(.borderedProminent)
                            .tint(TennisColors.courtGreenDark)

                            if let result = tossResultLabel {
                                Text(result)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .transition(.opacity)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Coin Toss")
                }

                // MARK: Walkout Songs
                Section("Walkout Songs") {
                    let songs = walkoutPlayer.listSongs()

                    WalkoutSongPicker(
                        label: displayName(.A),
                        selection: $walkoutSongA,
                        songs: songs
                    )

                    if walkoutSongA != nil {
                        Button {
                            if walkoutPlayer.isPlaying && walkoutPlayer.currentSong == walkoutSongA {
                                walkoutPlayer.stop()
                            } else {
                                walkoutPlayer.play(walkoutSongA!)
                            }
                        } label: {
                            Label(
                                walkoutPlayer.isPlaying && walkoutPlayer.currentSong == walkoutSongA ? "Stop" : "Preview",
                                systemImage: walkoutPlayer.isPlaying && walkoutPlayer.currentSong == walkoutSongA ? "stop.fill" : "play.fill"
                            )
                            .font(.caption)
                        }
                    }

                    WalkoutSongPicker(
                        label: displayName(.B),
                        selection: $walkoutSongB,
                        songs: songs
                    )

                    if walkoutSongB != nil {
                        Button {
                            if walkoutPlayer.isPlaying && walkoutPlayer.currentSong == walkoutSongB {
                                walkoutPlayer.stop()
                            } else {
                                walkoutPlayer.play(walkoutSongB!)
                            }
                        } label: {
                            Label(
                                walkoutPlayer.isPlaying && walkoutPlayer.currentSong == walkoutSongB ? "Stop" : "Preview",
                                systemImage: walkoutPlayer.isPlaying && walkoutPlayer.currentSong == walkoutSongB ? "stop.fill" : "play.fill"
                            )
                            .font(.caption)
                        }
                    }
                }

                // MARK: Voice Callouts
                Section("Voice Callouts") {
                    Picker("Voice Mode", selection: $voiceMode) {
                        ForEach(VoiceCalloutMode.allCases, id: \.self) { mode in
                            Text(mode.displayLabel).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                }

                // MARK: Announcer Voice
                Section("Announcer Voice") {
                    Picker("Voice", selection: $speaker.selectedVoiceId) {
                        ForEach(speaker.availableVoices) { voice in
                            Text(voice.displayName).tag(voice.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: speaker.selectedVoiceId) { newValue in
                        speaker.setVoice(newValue)
                    }

                    Button {
                        speaker.previewVoice()
                    } label: {
                        Label("Preview Voice", systemImage: "speaker.wave.2")
                    }
                }

                // MARK: Start Match
                Section {
                    Button {
                        startMatch(action: .phone)
                    } label: {
                        Label("Score on Phone", systemImage: "iphone")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(TennisColors.courtGreenDark)
                    .disabled(!canStart)

                    Button {
                        startMatch(action: .watch)
                    } label: {
                        Label("Send to Watch", systemImage: "applewatch")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.bordered)
                    .tint(TennisColors.scoreBlue)
                    .disabled(!canStart)
                }
            }
            .navigationTitle("Setup")
            .onAppear { applyDefaults() }
        }
        .alert("Replace Active Match?", isPresented: $showReplaceAlert) {
            Button("Abandon & Start New", role: .destructive) {
                if let action = pendingAction {
                    doStartMatch(action: action)
                }
            }
            Button("Cancel", role: .cancel) { pendingAction = nil }
        } message: {
            Text("A match is already in progress. Starting a new one will abandon it.")
        }
    }

    // MARK: - Helpers

    private var canStart: Bool {
        !effectivePlayerA.isEmpty && !effectivePlayerB.isEmpty
    }

    private var effectivePlayerA: String {
        playerA.trimmingCharacters(in: .whitespaces).isEmpty ? "Player 1" : playerA
    }

    private var effectivePlayerB: String {
        playerB.trimmingCharacters(in: .whitespaces).isEmpty ? "Player 2" : playerB
    }

    private func displayName(_ side: PlayerSide) -> String {
        switch side {
        case .A: return effectivePlayerA
        case .B: return effectivePlayerB
        }
    }

    @ViewBuilder
    private func serverButton(side: PlayerSide, label: String) -> some View {
        let isSelected = firstServer == side
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                firstServer = side
            }
        } label: {
            Text("\(label) serves")
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isSelected ? TennisColors.courtGreenDark : Color(uiColor: .secondarySystemBackground))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func formatDisplayName(_ f: MatchFormat) -> String {
        switch f {
        case .bestOf3:      return "Best of 3"
        case .bestOf5:      return "Best of 5"
        case .shortSets:    return "Short Sets"
        case .noAd:         return "No-Ad"
        case .tiebreakOnly: return "Tiebreak Only"
        }
    }

    private func applyDefaults() {
        format    = settings.defaultFormat
        matchType = settings.defaultMatchType
        voiceMode = settings.voiceCalloutMode
    }

    private func performCoinToss() {
        guard !isTossing else { return }
        isTossing = true
        tossResultLabel = nil

        let totalDegrees: Double = 1800
        withAnimation(.easeInOut(duration: 1.2)) {
            coinRotation = totalDegrees
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) {
            coinRotation = 0
            let winner: PlayerSide = Bool.random() ? .A : .B
            withAnimation {
                firstServer = winner
                let name = winner == .A ? effectivePlayerA : effectivePlayerB
                tossResultLabel = "\(name) serves first"
            }
            isTossing = false
        }
    }

    private func buildConfig() -> MatchConfig {
        MatchConfig(
            playerA:      effectivePlayerA,
            playerB:      effectivePlayerB,
            playerA2:     matchType == .doubles ? playerA2 : "",
            playerB2:     matchType == .doubles ? playerB2 : "",
            format:       format,
            firstServer:  firstServer,
            matchType:    matchType,
            walkoutSongA: walkoutSongA,
            walkoutSongB: walkoutSongB
        )
    }

    private func startMatch(action: PendingStartAction) {
        if mainViewModel.scoringViewModel != nil {
            pendingAction = action
            showReplaceAlert = true
            return
        }
        doStartMatch(action: action)
    }

    private func doStartMatch(action: PendingStartAction) {
        let config = buildConfig()

        switch action {
        case .phone:
            mainViewModel.startNewMatch(config: config)
        case .watch:
            mainViewModel.startNewMatch(config: config)
            watchSync.sendMatchConfig(config)
        }

        // Reset form
        playerA = ""
        playerB = ""
        playerA2 = ""
        playerB2 = ""
        walkoutSongA = nil
        walkoutSongB = nil
        tossResultLabel = nil
        pendingAction = nil
        walkoutPlayer.stop()
        selectedTab = .live
    }
}

// MARK: - WalkoutSongPicker

private struct WalkoutSongPicker: View {
    let label: String
    @Binding var selection: String?
    let songs: [String]

    var body: some View {
        Picker(label, selection: $selection) {
            Text("None").tag(String?.none)
            ForEach(songs, id: \.self) { song in
                Text(song).tag(Optional(song))
            }
        }
        .pickerStyle(.menu)
    }
}

// MARK: - Preview

struct SetupView_Previews: PreviewProvider {
    static var previews: some View {
        SetupView(selectedTab: .constant(.setup))
            .environmentObject(MainViewModel())
            .environmentObject(AppSettings.shared)
    }
}
