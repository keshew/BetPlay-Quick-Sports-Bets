import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var profileService: ProfileService

    var body: some View {
        NavigationStack {
            List {
                Section("Profile") {
                    HStack {
                        Image(systemName: "person.crop.circle.fill").foregroundStyle(.tint)
                        Text(profileService.profile.displayName)
                    }
                    HStack {
                        Text("Points:")
                        Spacer()
                        Text("\(profileService.profile.totalPoints)")
                            .bold()
                    }
                    HStack {
                        Text("Multiplier:")
                        Spacer()
                        Text(String(format: "%.2f", profileService.profile.effectiveMultiplier))
                            .bold()
                    }
                }

                Section("Bet History") {
                    if profileService.profile.betsHistory.isEmpty {
                        Text("No bets yet").foregroundStyle(.secondary)
                    } else {
                        ForEach(profileService.profile.betsHistory.sorted(by: { $0.createdAt > $1.createdAt })) { bet in
                            VStack(alignment: .leading) {
                                Text("Stake: \(Int(bet.stake)) • \(bet.outcome.rawValue)")
                                Text("Status: \(statusText(bet))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Mini-Games") {
                    if profileService.profile.miniGameHistory.isEmpty {
                        Text("No results yet").foregroundStyle(.secondary)
                    } else {
                        ForEach(profileService.profile.miniGameHistory.sorted(by: { $0.createdAt > $1.createdAt })) { res in
                            VStack(alignment: .leading) {
                                Text("\(res.type.rawValue) • \(res.success ? "success" : "miss")")
                                Text("+\(res.bonusPoints) points, +\(String(format: "%.2f", res.rewardMultiplierDelta)) multiplier")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Profile")
        }
    }
}

private func statusText(_ bet: Bet) -> String {
    switch bet.status {
    case .placed: return "Placed"
    case .won: return "Win: \(Int(bet.payout ?? 0))"
    case .lost: return "Lost"
    }
}

#Preview {
    ProfileView()
}


