import SwiftUI

struct GuessTheScoreView: View {
    @EnvironmentObject private var profileService: ProfileService
    @State private var selected: MatchOutcome = .homeWin
    @State private var submitted = false
    @State private var success = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Guess the match outcome")
                .font(.headline)

            Text("Attempts left today: \(profileService.remainingMiniGamePlays(.guessTheScore))")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Outcome", selection: $selected) {
                Text("H").tag(MatchOutcome.homeWin)
                Text("D").tag(MatchOutcome.draw)
                Text("A").tag(MatchOutcome.awayWin)
            }
            .pickerStyle(.segmented)

            Button(submitted ? (success ? "Success!" : "Miss") : "Confirm") {
                play()
            }
            .buttonStyle(.borderedProminent)
            .disabled(submitted || !profileService.canPlayMiniGame(.guessTheScore))

            if submitted {
                Text(success ? "You got +25 points and +0.05 multiplier" : "Try again tomorrow")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .navigationTitle("Guess the Score")
    }

    private func play() {
        guard profileService.canPlayMiniGame(.guessTheScore) else { return }
        profileService.registerMiniGamePlay(.guessTheScore)
        // For demo, consider Home (H) as the winning outcome
        success = (selected == .homeWin)
        submitted = true
        let result = MiniGameResult(
            id: UUID(),
            type: .guessTheScore,
            success: success,
            rewardMultiplierDelta: success ? 0.05 : 0.0,
            bonusPoints: success ? 25 : 0,
            createdAt: Date()
        )
        profileService.applyMiniGameResult(result)
    }
}

#Preview {
    GuessTheScoreView()
}


