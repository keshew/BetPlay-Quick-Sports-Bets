import Foundation
import Combine

final class BettingViewModel: ObservableObject {
    @Published var selectedEvent: SportsEvent?
    @Published var selectedOutcome: MatchOutcome = .homeWin
    @Published var stake: Double = 10

    var eventsService: EventsService
    var profileService: ProfileService

    init(eventsService: EventsService, profileService: ProfileService) {
        self.eventsService = eventsService
        self.profileService = profileService
        self.selectedEvent = eventsService.events.first
    }

    func placeClassicBet() {
        guard let event = selectedEvent else { return }
        let bet = Bet(
            id: UUID(),
            eventId: event.id,
            outcome: selectedOutcome,
            stake: stake,
            multiplier: profileService.profile.effectiveMultiplier,
            createdAt: Date(),
            status: .placed,
            payout: nil
        )
        guard profileService.tryPlaceBet(bet) else { return }
        AnalyticsService.track("place_bet", params: ["mode": "classic"]) 
    }

    // Turbo Bet удалён по требованиям

    func rebind(eventsService: EventsService, profileService: ProfileService) {
        self.eventsService = eventsService
        self.profileService = profileService
        if selectedEvent == nil {
            selectedEvent = eventsService.events.first
        }
    }
}

final class BlitzViewModel: ObservableObject {
    @Published var timeRemaining: Int = 60
    @Published var selectedEvents: Set<UUID> = []

    var eventsService: EventsService
    var profileService: ProfileService

    private var timer: AnyCancellable?

    init(eventsService: EventsService, profileService: ProfileService) {
        self.eventsService = eventsService
        self.profileService = profileService
    }

    func start() {
        timeRemaining = 60
        timer?.cancel()
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                if self.timeRemaining > 0 { self.timeRemaining -= 1 } else { self.timer?.cancel() }
            }
    }

    func stop() { timer?.cancel() }

    func rebind(eventsService: EventsService, profileService: ProfileService) {
        self.eventsService = eventsService
        self.profileService = profileService
    }
}


