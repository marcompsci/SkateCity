//  GameModel.swift
//  Shared game state for SwiftUI screens + HUD. The 3D engine writes into this.

import SwiftUI
import Combine

enum GameMode: String, CaseIterable, Identifiable {
    case session = "2-Min Session"
    case freeSkate = "Free Skate"
    var id: String { rawValue }
}

enum GoalID: String, CaseIterable {
    case score, skate, spin540, combo5, bigCombo, grind
}

struct Goal: Identifiable {
    let id: GoalID
    let title: String
    var done = false
}

@MainActor
final class GameModel: ObservableObject {
    enum Screen { case menu, loading, playing, results }

    @Published var screen: Screen = .menu
    @Published var mode: GameMode = .session
    @Published var quality: GraphicsQuality = .ultra
    @Published var skaterIndex = 0

    // HUD
    @Published var score = 0
    @Published var comboText = ""
    @Published var comboValue = 0
    @Published var comboMultiplier = 0
    @Published var message: String?
    @Published var timeLeft: Int = 120
    @Published var balance: Double?
    @Published var speedKmh = 0
    @Published var letters: [Bool] = Array(repeating: false, count: 5)
    @Published var goals: [Goal] = GameModel.freshGoals()
    @Published var isPaused = false
    @Published var bestScore: Int = UserDefaults.standard.integer(forKey: "skatecity.best")

    let input = InputState()
    weak var engine: GameEngine?
    private var messageToken = 0

    static func freshGoals() -> [Goal] {
        [
            Goal(id: .score, title: "Score 15,000 points"),
            Goal(id: .skate, title: "Collect S-K-A-T-E"),
            Goal(id: .spin540, title: "Land a 540 spin"),
            Goal(id: .combo5, title: "Land a 5-trick combo"),
            Goal(id: .bigCombo, title: "Bank a 5,000 point combo"),
            Goal(id: .grind, title: "Grind for 4 seconds straight")
        ]
    }

    var skater: SkaterStyle { SkaterStyle.roster[skaterIndex % SkaterStyle.roster.count] }

    func beginLoading() {
        score = 0
        comboText = ""
        comboValue = 0
        comboMultiplier = 0
        message = nil
        balance = nil
        letters = Array(repeating: false, count: 5)
        goals = GameModel.freshGoals()
        timeLeft = mode == .session ? 120 : 0
        isPaused = false
        input.reset()
        screen = .loading
    }

    func endGame() {
        engine?.stop()
        if score > bestScore {
            bestScore = score
            UserDefaults.standard.set(score, forKey: "skatecity.best")
        }
        screen = .results
    }

    func quitToMenu() {
        engine?.stop()
        screen = .menu
    }

    func flash(_ text: String) {
        messageToken &+= 1
        let token = messageToken
        message = text
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            if let self, self.messageToken == token { self.message = nil }
        }
    }

    func completeGoal(_ id: GoalID) {
        guard let i = goals.firstIndex(where: { $0.id == id }), !goals[i].done else { return }
        goals[i].done = true
        flash("GOAL: \(goals[i].title.uppercased())")
    }
}
