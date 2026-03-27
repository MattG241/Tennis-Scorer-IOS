// SetupView.swift
// TennisScorer
//
// Match setup form: player names, format, first server, voice mode and coin toss.

import SwiftUI

// MARK: - SetupView

struct SetupView: View {

    @EnvironmentObject var mainViewModel: MainViewModel
    @EnvironmentObject var settings: AppSettings

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

    // Coin toss
    @State private var coinRotation: Double = 0
    @State private var isTossing: Bool = false
    @State private var tossResultLabel: String? = nil

    // Start match sheet
    @State private var showPhoneScoring = false

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

                    if matchType == .doubles {
                        TextField("Player A2 name (partner)", text: $playerA2)
                            .autocorrectionDisabled()
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    TextField("Player B name", text: $playerB)
                        .autocorrectionDisabled()

                    if matchType == .doubles {
                        TextField("Player B2 name (partner)", text: $playerB2)
                            .autocorrectionDisabled()
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: matchType)

                // MARK: Format
                Section("Format") {
                    Button {
                        cycleFormat()
                    } label: {
                        HStack {
                            Text("Format")
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(formatDisplayName(format))
                                .foregroundStyle(TennisColors.scoreBlue)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
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

                // MARK: Voice Callouts
                Section("Voice Callouts") {
                    Picker("Voice Mode", selection: $voiceMode) {
                        ForEach(VoiceCalloutMode.allCases, id: \.self) { mode in
                            Text(mode.displayLabel).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                }

                // MARK: Start Match
                Section {
                    Button {
                        startMatch()
                    } label: {
                        Text("Start Match")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(TennisColors.courtGreenDark)
                    .disabled(!canStart)
                }
            }
            .navigationTitle("Setup")
            .onAppear { applyDefaults() }
        }
        .sheet(isPresented: $showPhoneScoring) {
            if let scoringVM = mainViewModel.scoringViewModel {
                PhoneScoringView(viewModel: scoringVM)
            }
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

    private func cycleFormat() {
        let all = MatchFormat.allCases
        guard let idx = all.firstIndex(of: format) else { return }
        format = all[(idx + 1) % all.count]
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

        // 5 full rotations (1800°) in 1.2 s, then snap to 0.
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

    private func startMatch() {
        let config = MatchConfig(
            playerA:     effectivePlayerA,
            playerB:     effectivePlayerB,
            playerA2:    matchType == .doubles ? playerA2 : "",
            playerB2:    matchType == .doubles ? playerB2 : "",
            format:      format,
            firstServer: firstServer,
            matchType:   matchType
        )
        mainViewModel.startNewMatch(config: config)
        selectedTab = .live
        showPhoneScoring = true
    }
}

// MARK: - Preview

#Preview {
    SetupView(selectedTab: .constant(.setup))
        .environmentObject(MainViewModel())
        .environmentObject(AppSettings.shared)
}
