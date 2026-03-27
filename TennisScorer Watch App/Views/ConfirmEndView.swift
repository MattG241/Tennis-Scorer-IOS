import SwiftUI

struct ConfirmEndView: View {

    let onConfirm: () -> Void
    let onCancel: () -> Void

    // MARK: - Colors
    private let darkBg      = Color(red: 0.102, green: 0.102, blue: 0.102)
    private let confirmGreen = Color(red: 0.106, green: 0.369, blue: 0.125)

    // Progress state for the hold-to-confirm button
    @State private var holdProgress: CGFloat = 0.0
    @State private var holdTimer: Timer? = nil
    private let holdDuration: Double = 1.0
    private let timerInterval: Double = 0.05

    var body: some View {
        ZStack {
            darkBg.ignoresSafeArea()

            VStack(spacing: 10) {
                Text("End match?")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)

                HStack(spacing: 8) {
                    // Hold-to-confirm button
                    ZStack {
                        // Progress ring background
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 3)
                            .frame(width: 50, height: 50)

                        // Progress ring fill
                        Circle()
                            .trim(from: 0, to: holdProgress)
                            .stroke(confirmGreen, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: 50, height: 50)
                            .animation(.linear(duration: timerInterval), value: holdProgress)

                        // Label
                        VStack(spacing: 0) {
                            Text("Hold")
                                .font(.system(size: 9, weight: .bold))
                            Text("Confirm")
                                .font(.system(size: 8))
                        }
                        .foregroundColor(.white)
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in startHold() }
                            .onEnded   { _ in cancelHold() }
                    )

                    // Cancel button
                    Button(action: onCancel) {
                        Text("Cancel")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Color.gray.opacity(0.35))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
        }
    }

    // MARK: - Hold logic

    private func startHold() {
        guard holdTimer == nil else { return }
        holdProgress = 0.0
        let increment = CGFloat(timerInterval / holdDuration)
        holdTimer = Timer.scheduledTimer(withTimeInterval: timerInterval, repeats: true) { timer in
            holdProgress += increment
            if holdProgress >= 1.0 {
                holdProgress = 1.0
                timer.invalidate()
                holdTimer = nil
                DispatchQueue.main.async {
                    onConfirm()
                }
            }
        }
    }

    private func cancelHold() {
        holdTimer?.invalidate()
        holdTimer = nil
        withAnimation(.easeOut(duration: 0.2)) {
            holdProgress = 0.0
        }
    }
}
