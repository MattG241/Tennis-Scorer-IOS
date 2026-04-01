// SplashScreenView.swift
// TennisScorer
//
// Animated launch screen shown on first open.

import SwiftUI

struct SplashScreenView: View {

    let onFinished: () -> Void

    // Ball
    @State private var ballScale:    CGFloat = 0.15
    @State private var ballOpacity:  Double  = 0
    @State private var ballY:        CGFloat = -30
    @State private var ballRotation: Double  = -20

    // Title block
    @State private var titleOpacity: Double  = 0
    @State private var titleY:       CGFloat = 28

    // Baseline accent — expands like a service-line reveal
    @State private var lineWidth:    CGFloat = 0

    // Exit
    @State private var exitOpacity:  Double  = 1

    var body: some View {
        ZStack {
            TennisColors.courtGreenDark.ignoresSafeArea()

            VStack(spacing: 24) {

                // MARK: Tennis ball
                Text("🎾")
                    .font(.system(size: 90))
                    .scaleEffect(ballScale)
                    .opacity(ballOpacity)
                    .offset(y: ballY)
                    .rotationEffect(.degrees(ballRotation))

                // MARK: Title block
                VStack(spacing: 8) {
                    Text("Tennis Scorer")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    // Expanding baseline accent
                    RoundedRectangle(cornerRadius: 2)
                        .fill(TennisColors.tennisBall)
                        .frame(width: lineWidth, height: 3)

                    Text("Every point counts.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .tracking(0.5)
                }
                .opacity(titleOpacity)
                .offset(y: titleY)
            }
        }
        .opacity(exitOpacity)
        .onAppear { runAnimation() }
    }

    // MARK: - Animation sequence

    private func runAnimation() {
        // 1. Ball bounces in (spring gives natural overshoot/settle)
        withAnimation(.spring(response: 0.52, dampingFraction: 0.52)) {
            ballScale    = 1.0
            ballOpacity  = 1.0
            ballY        = 0
            ballRotation = 0
        }

        // 2. Title block rises into place
        withAnimation(.easeOut(duration: 0.42).delay(0.22)) {
            titleOpacity = 1.0
            titleY       = 0
        }

        // 3. Baseline expands outward like the court line being drawn
        withAnimation(.easeOut(duration: 0.35).delay(0.50)) {
            lineWidth = 130
        }

        // 4. Whole splash fades out, revealing main app underneath
        withAnimation(.easeInOut(duration: 0.38).delay(1.75)) {
            exitOpacity = 0
        }

        // 5. Remove from view hierarchy after fade completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.18) {
            onFinished()
        }
    }
}

// MARK: - Preview

struct SplashScreenView_Previews: PreviewProvider {
    static var previews: some View {
        SplashScreenView(onFinished: {})
    }
}
