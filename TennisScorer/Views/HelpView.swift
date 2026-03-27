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
                            body: "The watch face is divided into three tap zones:\n• Blue (left half) — Player A wins the point\n• Green (right half) — Player B wins the point\n• Brown / bottom area — opens the control menu\n• Tapping the score area reads the score aloud"
                        )

                        HelpParagraph(
                            heading: "Pinch Gestures",
                            body: "Single pinch — server wins the point.\nDouble pinch (two quick pinches within 400 ms) — receiver wins the point."
                        )

                        HelpParagraph(
                            heading: "Enabling Hand Gestures",
                            body: "On your Apple Watch: Settings → Accessibility → Interaction and Dexterity → Hand Gestures → turn on. Requires watchOS 9 or later."
                        )

                        HelpParagraph(
                            heading: "Ambient Mode",
                            body: "When your wrist drops, the watch enters always-on ambient mode showing the current score in a low-power display. Raise your wrist to return to the full interactive view."
                        )
                    }
                }

                HelpSectionCard(title: "Phone Scoring", iconName: "iphone") {
                    VStack(alignment: .leading, spacing: 12) {
                        HelpParagraph(
                            heading: "Awarding Points",
                            body: "Tap the large Player A (blue) or Player B (green) button to award a point to that player. A spring animation confirms the tap."
                        )

                        HelpParagraph(
                            heading: "Undo",
                            body: "Tap the circular-arrow button in the bottom-left to undo the last point. Undo is unlimited during the match."
                        )

                        HelpParagraph(
                            heading: "Point Tags",
                            body: "Select a tag before awarding a point to classify it for statistics:\n• Normal — standard rally point\n• Ace — unreturned serve\n• DF — double fault\n• Win — outright winner\n• UE — unforced error"
                        )

                        HelpParagraph(
                            heading: "Serve Speed",
                            body: "Tap the speedometer icon to enter the serve speed in km/h. The speed is saved with the next point you record."
                        )

                        HelpParagraph(
                            heading: "Ending the Match",
                            body: "Tap the X in the top-left to close the scoring screen. The match continues in the background and is accessible from the Live tab. To permanently end a match, use the End Match button on the Live tab."
                        )
                    }
                }

                HelpSectionCard(title: "Setup", iconName: "plus.circle") {
                    VStack(alignment: .leading, spacing: 12) {
                        HelpParagraph(
                            heading: "Match Formats",
                            body: "• Best of 3 — standard format; first to win 2 sets. Tiebreak at 6-6.\n• Best of 5 — Grand Slam format; first to win 3 sets.\n• Short Sets — first to 4 games per set; tiebreak at 3-3.\n• No-Ad — standard sets but sudden death at deuce (no advantage games).\n• Tiebreak Only — a single 7-point (or 10-point) tiebreak decides the match."
                        )

                        HelpParagraph(
                            heading: "Coin Toss",
                            body: "Tap the Coin Toss button to randomly select the first server. The result is applied automatically to the first-server selection."
                        )
                    }
                }

                HelpSectionCard(title: "Live Tab", iconName: "bolt.fill") {
                    VStack(alignment: .leading, spacing: 12) {
                        HelpParagraph(
                            heading: "Real-Time Display",
                            body: "The Live tab shows the current score card in real time, including set scores, current game score, the serving indicator, and the match situation badge (Match Point, Break Point, etc.)."
                        )

                        HelpParagraph(
                            heading: "Score on Phone",
                            body: "Tap 'Score on Phone' to open the full PhoneScoringView sheet and enter points manually while watching the match."
                        )

                        HelpParagraph(
                            heading: "Chromecast",
                            body: "Tap the cast icon (top-right) to cast the score to a Chromecast-enabled TV on your local network. See the Chromecast section for details."
                        )
                    }
                }

                HelpSectionCard(title: "Voice Callouts", iconName: "speaker.wave.2") {
                    VStack(alignment: .leading, spacing: 12) {
                        HelpParagraph(
                            heading: "Modes",
                            body: "• Off — no voice announcements.\n• Score Only — announces the current score after each point (e.g. 'Thirty fifteen').\n• Score + Situation — score plus any active situation (e.g. 'Match point').\n• Full (with Names) — complete call including player names (e.g. 'Federer leads, thirty fifteen')."
                        )

                        HelpParagraph(
                            heading: "Changing the Mode",
                            body: "Change the voice mode globally in Settings → Defaults → Voice Callouts. You can also override it per match in the Setup screen."
                        )
                    }
                }

                HelpSectionCard(title: "Chromecast", iconName: "tv") {
                    VStack(alignment: .leading, spacing: 12) {
                        HelpParagraph(
                            heading: "How to Cast",
                            body: "Make sure your iPhone and Chromecast device are on the same Wi-Fi network. Tap the cast icon (circle.radiowaves.right) in the Live tab. Select your Chromecast from the list."
                        )

                        HelpParagraph(
                            heading: "What Displays on TV",
                            body: "The TV shows a large-format score overlay with:\n• Player names and set scores\n• Current game score in large text\n• The current server indicator\n• Situation badge (Match Point, etc.)\n• Match timer"
                        )

                        HelpParagraph(
                            heading: "Stopping the Cast",
                            body: "Tap the cast icon again and select 'Stop Casting', or disconnect directly from your Chromecast device."
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
    let body: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(heading)
                .font(.subheadline.bold())
                .foregroundStyle(.primary)

            Text(body)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        HelpView()
    }
}
