import Foundation
import Combine

final class EventsService: ObservableObject {
    @Published private(set) var events: [SportsEvent] = []
    private var timer: AnyCancellable?

    init() {
        if let saved = LocalPersistence.shared.loadEvents() {
            events = saved
        } else {
            seed()
            LocalPersistence.shared.saveEvents(events)
        }
        startAutoProgress()
    }

    private func seed() {
        let now = Date()
        let first = now.addingTimeInterval(90 * 60) // ~ +1h30m
        let second = now.addingTimeInterval(130 * 60) // ~ +2h10m
        events = makeBatch(with: [
            ("Real vs Barca", "Real", "Barca", first,
             Odds(homeWin: 1.9, draw: 3.2, awayWin: 2.1)),
            ("Lakers vs Celtics", "LAL", "BOS", second,
             Odds(homeWin: 1.7, draw: 15.0, awayWin: 2.3))
        ])
    }

    private func startAutoProgress() {
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                let now = Date()
                for index in self.events.indices {
                    switch self.events[index].status {
                    case .upcoming:
                        if now >= self.events[index].startDate { self.events[index].status = .ongoing }
                    case .ongoing:
                        // Result available 10 minutes after start
                        if now >= self.events[index].startDate.addingTimeInterval(10 * 60) {
                            self.events[index].status = .finished
                            self.events[index].resolvedOutcome = [MatchOutcome.homeWin, .draw, .awayWin].randomElement()!
                        }
                    case .finished:
                        break
                    }
                }
                LocalPersistence.shared.saveEvents(self.events)

                // If at least two events are Live and there are no upcoming ones, schedule next batch
                let ongoingCount = self.events.filter { $0.status == .ongoing }.count
                let upcomingCount = self.events.filter { $0.status == .upcoming }.count
                if ongoingCount >= 2 && upcomingCount == 0 {
                    self.scheduleNextBatch(after: now)
                }
            }
    }

    private func scheduleNextBatch(after now: Date) {
        // Next batch in ~ +1h and +2h from now
        let a = now.addingTimeInterval(60 * 60)
        let b = now.addingTimeInterval(120 * 60)
        let batch = makeBatch(with: [
            ("Dortmund vs Bayern", "BVB", "FCB", a,
             Odds(homeWin: 2.4, draw: 3.4, awayWin: 2.2)),
            ("PSG vs OM", "PSG", "OM", b,
             Odds(homeWin: 1.6, draw: 3.6, awayWin: 4.2))
        ])
        events.append(contentsOf: batch)
        LocalPersistence.shared.saveEvents(events)
    }

    private func makeBatch(with tuples: [(String, String, String, Date, Odds)]) -> [SportsEvent] {
        tuples.map { title, home, away, start, odds in
            SportsEvent(
                id: UUID(),
                title: title,
                startDate: start,
                homeTeam: home,
                awayTeam: away,
                odds: odds,
                status: .upcoming,
                resolvedOutcome: nil
            )
        }
    }
}

final class ProfileService: ObservableObject {
    @Published private(set) var profile: UserProfile
    private var eventsCancellable: AnyCancellable?
    private let miniPlaysPerDay = 3
    private var missionsTimer: AnyCancellable?

    init() {
        if let saved = LocalPersistence.shared.loadProfile() {
            profile = saved
        } else {
            profile = UserProfile(
                displayName: "Guest",
                totalPoints: 1000,
                baseMultiplier: 1.0,
                currentMultiplierBonus: 0.0,
                betsHistory: [],
                miniGameHistory: [],
                missions: [
                    Mission(id: UUID(), title: "Place 3 bets", description: "Any outcomes", goalCount: 3, progressCount: 0, rewardPoints: 50, rewardMultiplier: 0.1, claimed: false),
                    Mission(id: UUID(), title: "Win a mini-game", description: "Any", goalCount: 1, progressCount: 0, rewardPoints: 20, rewardMultiplier: 0.05, claimed: false)
                ]
            )
        }

        // Initialize missions reset date if missing
        if LocalPersistence.shared.getMissionsLastReset() == nil {
            LocalPersistence.shared.setMissionsLastReset(Date())
        }
    }

    func addBet(_ bet: Bet) {
        profile.betsHistory.append(bet)
        incrementMissionProgress(titleContains: "Place 3 bets")
        save()
    }

    // Try to deduct points and save the bet atomically
    @discardableResult
    func tryPlaceBet(_ bet: Bet) -> Bool {
        let cost = Int(bet.stake.rounded())
        guard profile.totalPoints >= cost else { return false }
        profile.totalPoints -= cost
        addBet(bet)
        return true
    }

    func resolveBets(for event: SportsEvent) {
        guard event.status == .finished, let outcome = event.resolvedOutcome else { return }
        for index in profile.betsHistory.indices {
            if profile.betsHistory[index].eventId == event.id && profile.betsHistory[index].status == .placed {
                if profile.betsHistory[index].outcome == outcome {
                    let odds: Double
                    switch outcome {
                    case .homeWin: odds =  event.odds.homeWin
                    case .draw: odds = event.odds.draw
                    case .awayWin: odds = event.odds.awayWin
                    }
                    let payout = profile.betsHistory[index].stake * odds * profile.betsHistory[index].multiplier
                    profile.betsHistory[index].status = .won
                    profile.betsHistory[index].payout = payout
                    profile.totalPoints += Int(payout.rounded())
                } else {
                    profile.betsHistory[index].status = .lost
                    profile.betsHistory[index].payout = 0
                }
            }
        }
        save()
    }

    func applyMiniGameResult(_ result: MiniGameResult) {
        profile.miniGameHistory.append(result)
        profile.currentMultiplierBonus += result.rewardMultiplierDelta
        profile.totalPoints += result.bonusPoints
        incrementMissionProgress(titleContains: "Win a mini-game")
        save()
    }

    private func incrementMissionProgress(titleContains needle: String) {
        for index in profile.missions.indices {
            if profile.missions[index].title.contains(needle) && !profile.missions[index].isCompleted {
                profile.missions[index].progressCount += 1
            }
        }
    }

    private func save() {
        LocalPersistence.shared.saveProfile(profile)
    }

    func bindToEvents(_ eventsService: EventsService) {
        eventsCancellable = eventsService.$events
            .sink { [weak self] events in
                guard let self else { return }
                for event in events where event.status == .finished {
                    self.resolveBets(for: event)
                }
            }
    }

    // MARK: - Mini-games daily limit (per game type)
    func canPlayMiniGame(_ type: MiniGameType) -> Bool {
        var stats = LocalPersistence.shared.getMiniGameStats()
        let today = Self.dateKey(Date())
        if stats?.date != today { stats = LocalPersistence.MiniGameDailyStats(date: today, counts: [:]) }
        let count = stats?.counts[type.rawValue] ?? 0
        return count < miniPlaysPerDay
    }

    func remainingMiniGamePlays(_ type: MiniGameType) -> Int {
        var stats = LocalPersistence.shared.getMiniGameStats()
        let today = Self.dateKey(Date())
        if stats?.date != today { stats = LocalPersistence.MiniGameDailyStats(date: today, counts: [:]) }
        let count = stats?.counts[type.rawValue] ?? 0
        return max(0, miniPlaysPerDay - count)
    }

    func registerMiniGamePlay(_ type: MiniGameType) {
        var stats = LocalPersistence.shared.getMiniGameStats()
        let today = Self.dateKey(Date())
        if stats?.date != today { stats = LocalPersistence.MiniGameDailyStats(date: today, counts: [:]) }
        var counts = stats?.counts ?? [:]
        counts[type.rawValue] = (counts[type.rawValue] ?? 0) + 1
        let newStats = LocalPersistence.MiniGameDailyStats(date: today, counts: counts)
        LocalPersistence.shared.setMiniGameStats(newStats)
    }

    private static func dateKey(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    // MARK: - Daily missions reset
    func resetDailyMissionsIfNeeded(now: Date = Date()) {
        let last = LocalPersistence.shared.getMissionsLastReset() ?? now
        if now.timeIntervalSince(last) >= 24 * 60 * 60 {
            resetMissions()
            LocalPersistence.shared.setMissionsLastReset(now)
        }
    }

    func nextMissionsResetDate() -> Date {
        let last = LocalPersistence.shared.getMissionsLastReset() ?? Date()
        return last.addingTimeInterval(24 * 60 * 60)
    }

    private func resetMissions() {
        for index in profile.missions.indices {
            profile.missions[index].progressCount = 0
            profile.missions[index].claimed = false
        }
        save()
    }
    
    func claimMission(_ id: UUID) {
        guard let index = profile.missions.firstIndex(where: { $0.id == id }) else { return }
        // Только если миссия выполнена и ещё не была заявлена
        guard profile.missions[index].isCompleted && !(profile.missions[index].claimed ?? false) else { return }
        
        profile.missions[index].claimed = true
        
        // Начисляем награду: очки и бонус умножителя
        profile.totalPoints += profile.missions[index].rewardPoints
        profile.currentMultiplierBonus += profile.missions[index].rewardMultiplier
        
        save()
        
        AnalyticsService.track("MissionClaimed", params: ["id": id.uuidString, "title": profile.missions[index].title])
    }
}

final class LocalPersistence {
    static let shared = LocalPersistence()
    private let key = "betplay.profile.v1"
    private let miniStatsKey = "betplay.minigame.stats.v2"
    private let missionsLastResetKey = "betplay.missions.last_reset"
    private let eventsKey = "betplay.events.v1"

    func saveProfile(_ profile: UserProfile) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(profile) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func loadProfile() -> UserProfile? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(UserProfile.self, from: data)
    }

    struct MiniGameDailyStats: Codable {
        let date: String
        let counts: [String: Int]
    }

    // MARK: - Mini-games daily plays (per game)
    func getMiniGameStats() -> MiniGameDailyStats? {
        if let data = UserDefaults.standard.data(forKey: miniStatsKey) {
            return try? JSONDecoder().decode(MiniGameDailyStats.self, from: data)
        }
        return nil
    }

    func setMiniGameStats(_ stats: MiniGameDailyStats) {
        if let data = try? JSONEncoder().encode(stats) {
            UserDefaults.standard.set(data, forKey: miniStatsKey)
        }
    }

    // MARK: - Missions last reset
    func getMissionsLastReset() -> Date? {
        UserDefaults.standard.object(forKey: missionsLastResetKey) as? Date
    }

    func setMissionsLastReset(_ date: Date) {
        UserDefaults.standard.set(date, forKey: missionsLastResetKey)
    }

    // MARK: - Events persistence
    func saveEvents(_ events: [SportsEvent]) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(events) {
            UserDefaults.standard.set(data, forKey: eventsKey)
        }
    }

    func loadEvents() -> [SportsEvent]? {
        guard let data = UserDefaults.standard.data(forKey: eventsKey) else { return nil }
        return try? JSONDecoder().decode([SportsEvent].self, from: data)
    }
}

enum AnalyticsService {
    static func track(_ event: String, params: [String: Any] = [:]) {
        // Placeholder
        print("[Analytics]", event, params)
    }
}


