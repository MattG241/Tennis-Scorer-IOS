import SwiftUI

struct MatchControlView: View {

    @EnvironmentObject var viewModel: WatchMatchViewModel

    @State private var showConfirmEnd      = false
    @State private var gestureFlashVisible = false
    @State private var gestureFlashLabel   = ""

    // MARK: - Colors
    private let scoreBlue      = Color(red: 0.051, green: 0.278, blue: 0.631)
    private let courtGreenDark = Color(red: 0.106, green: 0.369, blue: 0.125)
    private let tennisBall     = Color(red: 0.804, green: 0.863, blue: 0.224)
    private let undoBrown      = Color(red: 0.243, green: 0.152, blue: 0.137)
    private let headerBg       = Color(red: 0.118, green: 0.118, blue: 0.118)

    var body: some View {
        GeometryReader { geo in
            let totalH    = geo.size.height
            let headerH   = totalH * 0.28
            let buttonsH  = totalH * 0.50
            let bottomH   = totalH * 0.22

            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // ── TOP: Score header (28%) ──────────────────────────
                    scoreHeader
                        .frame(height: headerH)

                    // ── MIDDLE: Point buttons (50%) ──────────────────────
                    pointButtons(height: buttonsH)
                        .frame(height: buttonsH)

                    // ── BOTTOM: Undo / End bar (22%) ─────────────────────
                    undoBar
                        .frame(height: bottomH)
                }

                // Overlay: background tap gestures for server / receiver
                backgroundGestureOverlay(totalH: totalH, headerH: headerH, bottomH: bottomH)

                // Overlay: gesture flash pill
                if gestureFlashVisible {
                    gestureFlashPill
                }

                // Overlay: confirm end dialog
                if showConfirmEnd {
                    ConfirmEndView(
                        onConfirm: {
                            showConfirmEnd = false
                            viewModel.endMatchAndReset()
                        },
                        onCancel: {
                            showConfirmEnd = false
                        }
                    )
                    .transition(.opacity)
                }
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Score header

    private var scoreHeader: some View {
        let state = viewModel.state
        let situation = viewModel.situation

        return VStack(spacing: 2) {
            // Situation badge
            if let badge = situationBadge(situation) {
                Text(badge.label)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(badge.color)
                    .cornerRadius(4)
            }

            // Set scores
            if let state = state {
                Text(ScoreFormatter.setScores(state))
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }

            // Games
            if let state = state {
                Text(ScoreFormatter.games(state))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(tennisBall)
            }

            // Points
            HStack(spacing: 4) {
                if let state = state {
                    Text(ScoreFormatter.points(state))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }

                // Speaker button
                Button(action: { viewModel.speakScoreNow() }) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Color.gray.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 6)
        .padding(.top, 4)
        .background(headerBg)
    }

    // MARK: - Point buttons

    @ViewBuilder
    private func pointButtons(height: CGFloat) -> some View {
        let state = viewModel.state
        let isAServing = state?.isServing(.A) ?? true

        HStack(spacing: 2) {
            // Player A button
            Button(action: { viewModel.pointA() }) {
                VStack(spacing: 3) {
                    servingDot(visible: isAServing)
                    Text(state?.config.playerA ?? "P1")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(scoreBlue)
            }
            .buttonStyle(.plain)

            // Player B button
            Button(action: { viewModel.pointB() }) {
                VStack(spacing: 3) {
                    servingDot(visible: !isAServing)
                    Text(state?.config.playerB ?? "P2")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(courtGreenDark)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Serving dot

    @ViewBuilder
    private func servingDot(visible: Bool) -> some View {
        Circle()
            .fill(tennisBall)
            .frame(width: 6, height: 6)
            .opacity(visible ? 1 : 0)
    }

    // MARK: - Undo bar

    private var undoBar: some View {
        HStack {
            Button(action: { viewModel.undo() }) {
                Text("Undo")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .onLongPressGesture(minimumDuration: 0.8) {
                showConfirmEnd = true
            }

            VStack(spacing: 1) {
                Text("Hold to end")
                    .font(.system(size: 9))
                    .foregroundColor(Color.gray.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            // Long press on the entire bar also triggers end
            .onLongPressGesture(minimumDuration: 0.8) {
                showConfirmEnd = true
            }
        }
        .frame(maxWidth: .infinity)
        .background(undoBrown)
    }

    // MARK: - Background gesture overlay
    // Single tap on background = server point, double tap = receiver point
    // These are placed in the middle section area so they don't overlap
    // the explicit point buttons (which sit on top in the Z-order).
    // We use a transparent hit-test passthrough layer below the buttons.

    @ViewBuilder
    private func backgroundGestureOverlay(totalH: CGFloat, headerH: CGFloat, bottomH: CGFloat) -> some View {
        let middleH = totalH - headerH - bottomH

        VStack {
            Spacer().frame(height: headerH)

            ZStack {
                // Double tap = receiver (higher priority, checked first)
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        awardReceiverPoint()
                        showGestureFlash(label: receiverName)
                    }

                // Single tap = server
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(count: 1) {
                        awardServerPoint()
                        showGestureFlash(label: serverName)
                    }
            }
            .frame(height: middleH)
            .allowsHitTesting(false) // buttons on top capture taps; this only fires in empty space

            Spacer().frame(height: bottomH)
        }
    }

    // MARK: - Gesture flash pill

    private var gestureFlashPill: some View {
        VStack {
            Spacer()
            HStack(spacing: 4) {
                Text("✓")
                    .font(.system(size: 11, weight: .bold))
                Text(gestureFlashLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.black.opacity(0.75))
            .cornerRadius(12)
            .transition(.opacity)
            Spacer()
        }
        .allowsHitTesting(false)
    }

    // MARK: - Situation badge helpers

    private struct SituationBadgeInfo {
        let label: String
        let color: Color
    }

    private func situationBadge(_ situation: GameSituation) -> SituationBadgeInfo? {
        switch situation.type {
        case .matchPoint:   return SituationBadgeInfo(label: "MP", color: .red)
        case .setPoint:     return SituationBadgeInfo(label: "SP", color: .orange)
        case .breakPoint:   return SituationBadgeInfo(label: "BP", color: .yellow)
        case .gamePoint:    return SituationBadgeInfo(label: "GP", color: Color(red: 0.804, green: 0.863, blue: 0.224))
        default:            return nil
        }
    }

    // MARK: - Gesture helpers

    private var serverName: String {
        guard let state = viewModel.state else { return "Server" }
        return state.isServing(.A) ? state.config.playerA : state.config.playerB
    }

    private var receiverName: String {
        guard let state = viewModel.state else { return "Receiver" }
        return state.isServing(.A) ? state.config.playerB : state.config.playerA
    }

    private func awardServerPoint() {
        guard let state = viewModel.state else { return }
        if state.isServing(.A) { viewModel.pointA() } else { viewModel.pointB() }
    }

    private func awardReceiverPoint() {
        guard let state = viewModel.state else { return }
        if state.isServing(.A) { viewModel.pointB() } else { viewModel.pointA() }
    }

    private func showGestureFlash(label: String) {
        gestureFlashLabel = label
        withAnimation(.easeIn(duration: 0.15)) {
            gestureFlashVisible = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            withAnimation(.easeOut(duration: 0.2)) {
                gestureFlashVisible = false
            }
        }
    }
}
