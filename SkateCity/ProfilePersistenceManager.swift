import Foundation
import SwiftData

// MARK: - SwiftData Models

@Model
final class SkateComboRecord {
    var id:                   UUID   = UUID()
    var scoreValue:           Int    = 0
    var dateAchieved:         Date   = Date()
    var trickSequenceSummary: String = ""

    init(scoreValue: Int, trickSequenceSummary: String) {
        self.scoreValue           = scoreValue
        self.trickSequenceSummary = trickSequenceSummary
    }
}

@Model
final class PlayerProfile {
    @Attribute(.unique) var profileID: String = "default_skater"
    var totalCareerScore: Int = 0
    @Relationship(deleteRule: .cascade) var highComboLines: [SkateComboRecord] = []
    init() {}
}

// MARK: - Manager

@MainActor
class ProfilePersistenceManager {
    static let shared = ProfilePersistenceManager()

    private var container: ModelContainer?
    private var context:   ModelContext?
    private(set) var activeProfile: PlayerProfile?

    private init() {
        guard let container = try? ModelContainer(
            for: Schema([PlayerProfile.self, SkateComboRecord.self])
        ) else { return }

        self.container = container
        let ctx = ModelContext(container)
        self.context = ctx

        let existing = try? ctx.fetch(FetchDescriptor<PlayerProfile>())
        if let profile = existing?.first {
            activeProfile = profile
        } else {
            let newProfile = PlayerProfile()
            ctx.insert(newProfile)
            activeProfile = newProfile
        }
    }

    func appendCareerPoints(_ points: Int) {
        activeProfile?.totalCareerScore += points
        try? context?.save()
    }

    func recordCombo(score: Int, trickList: [String]) {
        guard let profile = activeProfile else { return }
        let record = SkateComboRecord(
            scoreValue: score,
            trickSequenceSummary: trickList.joined(separator: " + ")
        )
        profile.highComboLines.append(record)
        try? context?.save()
    }

    /// Records a combo and prunes the leaderboard to the top 10 scores.
    func evaluateAndRecordNewComboLine(score: Int, tricks: [String]) {
        guard let profile = activeProfile, let context else { return }
        let record = SkateComboRecord(
            scoreValue: score,
            trickSequenceSummary: tricks.joined(separator: " → ")
        )
        profile.highComboLines.append(record)
        profile.highComboLines.sort { $0.scoreValue > $1.scoreValue }
        while profile.highComboLines.count > 10 {
            if let dropped = profile.highComboLines.popLast() {
                context.delete(dropped)
            }
        }
        try? context.save()
    }
}
