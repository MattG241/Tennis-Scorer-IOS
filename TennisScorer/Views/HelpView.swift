// HelpView.swift
// TennisScorer
//
// Scrollable help reference mirroring the Android HelpScreen sections.
// Uses collapsible card-style sections with tennisBall-coloured headers.

import SwiftUI

// MARK: - HelpView

struct HelpView: View {

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HelpSectionCard(title: "Watch Scoring", iconName: "applewatch") {
                    VStack(alignment: .leading, spacing: 12) {
                        HelpParagraph(
                            heading: "Screen Zones",
                            description: "The watch face is divided into three tap zones:\n• Blue (left half) — Player A wins the point\n• Green (right half) — Player B wins the point\n• Brown / bottom area — opens the control menu\n• Tapping the score area reads the score aloud"
                        )

                        HelpParagraph(
                            heading: "Pinch Gestures",
                            description: "Single pinch — server wins the point.\nDouble pinch (two quick pinches within 400 ms) — receiver wins the point."
                        )

                        HelpParagraph(
                            heading: "Enabling Hand Gestures",
                            description: "On your Apple Watch: Settings → Accessibility → Interaction and Dexterity → Hand Gestures → turn on. Requires watchOS 9 or later."
                        )

                        HelpParagraph(
                            heading: "Ambient Mode",
                            description: "When your wrist drops, the watch enters always-on ambient mode showing the current score in a low-power display. Raise your wrist to return to the full interactive view."
                        )
                    }
                }

                HelpSectionCard(title: "Phone Scoring", iconName: "iphone") {
                    VStack(alignment: .leading, spacing: 12) {
                        HelpParagraph(
                            heading: "Awarding Points",
                            description: "Tap the large Player A (blue) or Player B (green) button to award a point. A haptic tap and spring animation confirm the input."
                        )

                        HelpParagraph(
                            heading: "Serve Type",
                            description: "Select 1st or 2nd before awarding a point to track serve type in your match statistics."
                        )

                        HelpParagraph(
                            heading: "Undo",
                            description: "Tap the undo button (bottom-left) to reverse the last point. Undo is unlimited during the match."
                        )

                        HelpParagraph(
                            heading: "Point Tags",
                            description: "Select a tag before awarding a point to classify it for statistics:\n• Ace — unreturned serve\n• DF — double fault\n• Win — outright winner\n• UE — unforced error"
                        )

                        HelpParagraph(
                            heading: "Serve Speed",
                            description: "Tap the speedometer icon to log the serve speed in km/h. The last speed is pre-filled for convenience — adjust or clear it each point."
                        )

                        HelpParagraph(
                            heading: "Closing the Scoring Screen",
                            description: "Tap the X to close the scoring sheet. The match continues and the Live tab shows the current score. To end a match early, use the End Match button on the Live tab."
                        )
                    }
                }

                HelpSectionCard(title: "Setup", iconName: "plus.circle") {
                    VStack(alignment: .leading, spacing: 12) {
                        HelpParagraph(
                            heading: "Match Formats",
                            description: "• Best of 3 — standard format; first to win 2 sets. Tiebreak at 6-6.\n• Best of 5 — Grand Slam format; first to win 3 sets.\n• Short Sets — first to 4 games per set; tiebreak at 3-3.\n• No-Ad — standard sets but sudden death at deuce (no advantage games).\n• Tiebreak Only — a single 7-point (or 10-point) tiebreak decides the match."
                        )

                        HelpParagraph(
                            heading: "Coin Toss",
                            description: "Tap the Coin Toss button to randomly select the first server. The result is applied automatically to the first-server selection."
                        )
                    }
                }

                HelpSectionCard(title: "Live Tab", iconName: "bolt.fill") {
                    VStack(alignment: .leading, spacing: 12) {
                        HelpParagraph(
                            heading: "Real-Time Display",
                            description: "The Live tab shows the current score in real time — set scores, current game, server indicator, and the match situation badge (Match Point, Break Point, etc.)."
                        )

                        HelpParagraph(
                            heading: "Score on Phone or Watch",
                            description: "Choose Phone or Watch using the segmented picker, then tap 'Score on Phone' or raise your wrist to score on Apple Watch."
                        )

                        HelpParagraph(
                            heading: "Watch Status",
                            description: "The watch icon in the top-right shows whether your Apple Watch is connected (green) or not reachable (grey). Tap it for details."
                        )

                        HelpParagraph(
                            heading: "Resuming a Match",
                            description: "If you close the app mid-match, a 'Resume Match' card appears on the Live tab the next time you open the app."
                        )
                    }
                }

                HelpSectionCard(title: "Voice Callouts", iconName: "speaker.wave.2") {
                    VStack(alignment: .leading, spacing: 12) {
                        HelpParagraph(
                            heading: "Modes",
                            description: "• Off — no voice announcements.\n• Score Only — announces the current score after each point (e.g. 'Thirty fifteen').\n• Score + Situation — score plus any active situation (e.g. 'Match point').\n• Full (with Names) — complete call including player names (e.g. 'Federer leads, thirty fifteen')."
                        )

                        HelpParagraph(
                            heading: "Changing the Mode",
                            description: "Change the voice mode globally in Settings → Defaults → Voice Callouts. You can also override it per match in the Setup screen."
                        )
                    }
                }

            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Help")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - HelpSectionCard

private struct HelpSectionCard<Content: View>: View {

    let title: String
    let iconName: String
    @ViewBuilder let content: () -> Content

    @State private var isExpanded: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: iconName)
                        .font(.subheadline.bold())
                        .foregroundStyle(TennisColors.courtGreenDark)
                        .frame(width: 20)

                    Text(title)
                        .font(.headline)
                        .foregroundStyle(TennisColors.tennisBall)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
            }
            .buttonStyle(.plain)

            // Content
            if isExpanded {
                Divider()
                    .padding(.horizontal, 16)

                content()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }
}

// MARK: - HelpParagraph

private struct HelpParagraph: View {

    let heading: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(heading)
                .font(.subheadline.bold())
                .foregroundStyle(.primary)

            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Preview

struct HelpView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            HelpView()
        }
    }
}
