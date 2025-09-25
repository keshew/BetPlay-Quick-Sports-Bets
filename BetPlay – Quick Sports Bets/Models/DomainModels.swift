import Foundation

enum MatchOutcome: String, Codable, CaseIterable, Identifiable {
    case homeWin
    case draw
    case awayWin
    var id: String { rawValue }
}

enum EventStatus: String, Codable, Identifiable {
    case upcoming
    case ongoing
    case finished
    var id: String { rawValue }
}

struct SportsEvent: Identifiable, Codable, Hashable {
    let id: UUID
    let title: String
    let startDate: Date
    let homeTeam: String
    let awayTeam: String
    let odds: Odds
    var status: EventStatus
    var resolvedOutcome: MatchOutcome?
}

struct Odds: Codable, Hashable {
    let homeWin: Double
    let draw: Double
    let awayWin: Double
}

enum BetStatus: String, Codable, Identifiable {
    case placed
    case won
    case lost
    var id: String { rawValue }
}

struct Bet: Identifiable, Codable, Hashable {
    let id: UUID
    let eventId: UUID
    let outcome: MatchOutcome
    let stake: Double
    let multiplier: Double
    let createdAt: Date
    var status: BetStatus
    var payout: Double?

    enum CodingKeys: String, CodingKey {
        case id, eventId, outcome, stake, multiplier, createdAt, status, payout
    }

    init(id: UUID, eventId: UUID, outcome: MatchOutcome, stake: Double, multiplier: Double, createdAt: Date, status: BetStatus, payout: Double?) {
        self.id = id
        self.eventId = eventId
        self.outcome = outcome
        self.stake = stake
        self.multiplier = multiplier
        self.createdAt = createdAt
        self.status = status
        self.payout = payout
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.eventId = try container.decode(UUID.self, forKey: .eventId)
        self.outcome = try container.decode(MatchOutcome.self, forKey: .outcome)
        self.stake = try container.decode(Double.self, forKey: .stake)
        self.multiplier = try container.decode(Double.self, forKey: .multiplier)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.status = try container.decodeIfPresent(BetStatus.self, forKey: .status) ?? .placed
        self.payout = try container.decodeIfPresent(Double.self, forKey: .payout)
    }
}

enum MiniGameType: String, Codable, CaseIterable, Identifiable {
    case guessTheScore
    case throwBall
    var id: String { rawValue }
}

struct MiniGameResult: Identifiable, Codable, Hashable {
    let id: UUID
    let type: MiniGameType
    let success: Bool
    let rewardMultiplierDelta: Double
    let bonusPoints: Int
    let createdAt: Date
}

struct Mission: Identifiable, Codable, Hashable {
    let id: UUID
    let title: String
    let description: String
    let goalCount: Int
    var progressCount: Int
    let rewardPoints: Int
    let rewardMultiplier: Double
    var claimed: Bool? // nil/false — не забрано; true — награда получена

    var isCompleted: Bool { progressCount >= goalCount }
}

struct UserProfile: Codable {
    var displayName: String
    var totalPoints: Int
    var baseMultiplier: Double
    var currentMultiplierBonus: Double
    var betsHistory: [Bet]
    var miniGameHistory: [MiniGameResult]
    var missions: [Mission]

    var effectiveMultiplier: Double { baseMultiplier + currentMultiplierBonus }
}


