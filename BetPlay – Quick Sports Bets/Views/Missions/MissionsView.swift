import SwiftUI

struct MissionsView: View {
    @EnvironmentObject private var profileService: ProfileService
    @State private var now = Date()
    @State private var timer: Timer?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    let next = profileService.nextMissionsResetDate()
                    Text("Missions refresh in: \(countdownString(to: next))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ForEach(profileService.profile.missions) { mission in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(mission.title)
                                .font(.headline)
                            Spacer()
                            if mission.isCompleted {
                                Text(mission.claimed == true ? "Claimed" : "Ready")
                                    .font(.caption)
                                    .foregroundStyle(mission.claimed == true ? .green : .orange)
                            }
                        }
                        Text(mission.description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        ProgressView(value: Double(mission.progressCount), total: Double(mission.goalCount))
                        HStack {
                            Text("Reward: +\(mission.rewardPoints) points, +\(mission.rewardMultiplier, specifier: "%.2f") multiplier")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Claim") {
                                let id = mission.id
                                DispatchQueue.main.async {
                                    profileService.claimMission(id)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(!mission.isCompleted || (mission.claimed ?? false))
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Missions")
            .onAppear {
                profileService.resetDailyMissionsIfNeeded()
                timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                    now = Date()
                    profileService.resetDailyMissionsIfNeeded(now: now)
                }
            }
            .onDisappear {
                timer?.invalidate()
                timer = nil
            }
        }
    }
}

#Preview {
    MissionsView()
}

private func countdownString(to date: Date) -> String {
    let remaining = max(0, Int(date.timeIntervalSince(Date())))
    let h = remaining / 3600
    let m = (remaining % 3600) / 60
    let s = remaining % 60
    return String(format: "%02d:%02d:%02d", h, m, s)
}


