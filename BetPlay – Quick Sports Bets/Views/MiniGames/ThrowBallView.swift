import SwiftUI

struct ThrowBallView: View {
    @EnvironmentObject private var profileService: ProfileService
    @State private var meter: Double = 0
    @State private var isRunning = false
    @State private var submitted = false
    @State private var success = false
    @State private var timer: Timer?
    @State private var movingForward = true

    var body: some View {
        VStack(spacing: 16) {
            Text("Hit the green zone to win")
                .font(.headline)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 20)
                GeometryReader { geo in
                    let width = geo.size.width
                    // wider green success zone in the center
                    Capsule()
                        .fill(Color.green.opacity(0.35))
                        .frame(width: width * 0.35, height: 20)
                        .position(x: width * 0.5, y: 10)
                }
                Capsule()
                    .fill(.tint)
                    .frame(width: 8, height: 24)
                    .offset(x: CGFloat(meter))
            }
            .frame(height: 24)

            HStack {
                Button(isRunning ? "Stop" : "Start") { toggle() }
                    .buttonStyle(.borderedProminent)
                    .disabled(submitted)
            }

            if submitted {
                Text(success ? "Win! +20 points and +0.03 multiplier" : "Miss — no reward")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .navigationTitle("Throw the Ball")
        .onAppear { startIfNeeded() }
    }

    private func startIfNeeded() {
        guard timer == nil else { return }
        isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            let speed: Double = 180.0 * 0.016 // ~180 px/sec
            if movingForward {
                meter += speed
                if meter >= 300 { meter = 300; movingForward = false }
            } else {
                meter -= speed
                if meter <= 0 { meter = 0; movingForward = true }
            }
        }
    }

    private func toggle() {
        if isRunning {
            // stop immediately
            isRunning = false
            timer?.invalidate()
            timer = nil
            // instantly calculate result and apply reward
            submit()
        } else {
            startIfNeeded()
        }
    }

    private func submit() {
        // Success when stopped in the central green zone
        let position = meter
        success = position > 80 && position < 220
        submitted = true
        let result = MiniGameResult(
            id: UUID(),
            type: .throwBall,
            success: success,
            rewardMultiplierDelta: success ? 0.03 : 0.0,
            bonusPoints: success ? 20 : 0,
            createdAt: Date()
        )
        profileService.applyMiniGameResult(result)
        isRunning = false
        timer?.invalidate()
        timer = nil
    }
}

#Preview {
    ThrowBallView()
}


