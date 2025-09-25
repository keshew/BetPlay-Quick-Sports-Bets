import SwiftUI

struct BettingView: View {
    @EnvironmentObject private var eventsService: EventsService
    @EnvironmentObject private var profileService: ProfileService
    @StateObject private var viewModel: BettingViewModel
    @State private var showConfirm = false
    @State private var pendingMode: String = "classic"

    init() {
        // ViewModel будет создан в onAppear, когда доступны EnvironmentObject
        _viewModel = StateObject(wrappedValue: BettingViewModel(eventsService: EventsService(), profileService: ProfileService()))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                List {
                    Section("Events") {
                        ForEach(eventsService.events) { event in
                            Button {
                                viewModel.selectedEvent = event
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text(event.title)
                                                .font(.headline)
                                            if viewModel.selectedEvent?.id == event.id {
                                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.tint)
                                            }
                                        }
                                        Text(event.startDate, style: .time)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(statusLabel(for: event.status))
                                            .font(.caption2)
                                            .foregroundStyle(event.status == .finished ? .green : (event.status == .ongoing ? .orange : .secondary))
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing) {
                                        Text("H \(String(format: "%.2f", event.odds.homeWin))")
                                        Text("D  \(String(format: "%.2f", event.odds.draw))")
                                        Text("A \(String(format: "%.2f", event.odds.awayWin))")
                                    }
                                    .font(.caption)
                                }
                            }
                            .disabled(event.status != .upcoming)
                        }
                    }

                    if let event = viewModel.selectedEvent {
                        Section("Outcome") {
                            Picker("Outcome", selection: $viewModel.selectedOutcome) {
                                Text("H").tag(MatchOutcome.homeWin)
                                Text("D").tag(MatchOutcome.draw)
                                Text("A").tag(MatchOutcome.awayWin)
                            }
                            .pickerStyle(.segmented)
                        }

                        Section("Stake") {
                            Stepper(value: $viewModel.stake, in: 1...1000, step: 5) {
                                Text("Amount: \(Int(viewModel.stake))")
                            }
                            let odds = odds(for: event, outcome: viewModel.selectedOutcome)
                            let multiplier = profileService.profile.effectiveMultiplier
                            let potential = viewModel.stake * odds * multiplier
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Odds: \(String(format: "%.2f", odds))")
                                Text("Multiplier: \(String(format: "%.2f", multiplier))")
                                Text("Potential Payout: \(String(format: "%.2f", potential))")
                                Text("Your Points: \(profileService.profile.totalPoints)")
                                    .foregroundStyle(profileService.profile.totalPoints < Int(viewModel.stake) ? .red : .secondary)
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }

                        Section {
                            HStack {
                                Button("BET") {
                                    pendingMode = "classic"
                                    showConfirm = true
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(profileService.profile.betsHistory.contains { $0.eventId == event.id } || profileService.profile.totalPoints < Int(viewModel.stake))
                            }
                        }
                        Section("My bets for event") {
                            let bets = profileService.profile.betsHistory.filter { $0.eventId == event.id }
                            if bets.isEmpty {
                                Text("No bets yet")
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(bets, id: \.id) { bet in
                                    HStack {
                                        Text("\(label(for: bet.outcome)) • \(Int(bet.stake))")
                                        Spacer()
                                        Text(betStatusLabel(bet))
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Bets")
            .onAppear {
                viewModel.rebind(eventsService: eventsService, profileService: profileService)
                if viewModel.selectedEvent == nil {
                    if let lastBet = profileService.profile.betsHistory.sorted(by: { $0.createdAt > $1.createdAt }).first,
                       let ev = eventsService.events.first(where: { $0.id == lastBet.eventId }) {
                        viewModel.selectedEvent = ev
                    } else {
                        viewModel.selectedEvent = eventsService.events.first
                    }
                }
            }
            .confirmationDialog("Confirm bet?", isPresented: $showConfirm, titleVisibility: .visible) {
                Button("Confirm") {
                    viewModel.placeClassicBet()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
}

#Preview {
    BettingView()
}

private func label(for outcome: MatchOutcome) -> String {
    switch outcome {
    case .homeWin: return "H"
    case .draw: return "D"
    case .awayWin: return "A"
    }
}

private func odds(for event: SportsEvent, outcome: MatchOutcome) -> Double {
    switch outcome {
    case .homeWin: return event.odds.homeWin
    case .draw: return event.odds.draw
    case .awayWin: return event.odds.awayWin
    }
}

private func statusLabel(for status: EventStatus) -> String {
    switch status {
    case .upcoming: return "Soon"
    case .ongoing: return "Live"
    case .finished: return "Finished"
    }
}

private func betStatusLabel(_ bet: Bet) -> String {
    switch bet.status {
    case .placed: return "Placed"
    case .won: return "Win: \(Int(bet.payout ?? 0))"
    case .lost: return "Lost"
    }
}

// вспомогательная функция больше не нужна — логика перенесена в .disabled(...)

#Preview {
    BettingView()
}


