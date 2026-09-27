// Copyright © 2026 MAR / SkateCity. All rights reserved.
// Unauthorized reproduction, distribution, or modification is strictly prohibited.

import Foundation

struct CompletedTrick {
    let name: String
    let basePoints: Int
}

enum ComboState {
    case idle, tricking, balancing
}

class SkateComboManager {
    private(set) var totalCareerScore:      Int = 0
    private(set) var currentComboBasePoints: Int = 0
    private(set) var currentMultiplier:     Int = 0
    private(set) var activeTricksInCombo:   [CompletedTrick] = []
    private(set) var currentState:          ComboState = .idle

    private let maxComboWindowDuration: TimeInterval = 1.5
    private var comboTimerRemaining:    TimeInterval = 0.0

    var onComboUIUpdate:    ((Int, Int, TimeInterval, [String]) -> Void)?
    var onComboLandSuccess: ((Int) -> Void)?
    var onComboBail:        (() -> Void)?

    func updateComboClock(deltaTime: TimeInterval) {
        guard currentState != .idle else { return }

        // Active trick/balance states keep the window alive
        if currentState == .balancing || currentState == .tricking {
            comboTimerRemaining = maxComboWindowDuration
            sendUIUpdate()
            return
        }

        comboTimerRemaining -= deltaTime
        if comboTimerRemaining <= 0 {
            landCurrentCombo()
        } else {
            sendUIUpdate()
        }
    }

    func addTrickToCombo(name: String, basePoints: Int) {
        if currentState == .idle {
            currentState      = .tricking
            currentMultiplier = 1
        }

        // THPS-style duplicate decay: each repeat of the same trick loses 25% value
        let dupeCount     = activeTricksInCombo.filter { $0.name == name }.count
        let penaltyFactor = max(0.2, 1.0 - (Float(dupeCount) * 0.25))
        let finalPoints   = Int(Float(basePoints) * penaltyFactor)

        activeTricksInCombo.append(CompletedTrick(name: name, basePoints: finalPoints))
        currentComboBasePoints += finalPoints
        currentMultiplier      += 1
        comboTimerRemaining     = maxComboWindowDuration
        sendUIUpdate()
    }

    func startBalanceStance() {
        if currentState == .idle {
            currentMultiplier      = 1
            currentComboBasePoints = 0
        }
        currentState        = .balancing
        comboTimerRemaining = maxComboWindowDuration
    }

    func exitBalanceStance() {
        guard currentState == .balancing else { return }
        currentState = .tricking
    }

    func landCurrentCombo() {
        guard currentMultiplier > 0 else { return }
        let finalScore = currentComboBasePoints * currentMultiplier
        totalCareerScore += finalScore
        onComboLandSuccess?(finalScore)
        resetComboEngine()
    }

    func bailCurrentCombo() {
        guard currentState != .idle else { return }
        onComboBail?()
        resetComboEngine()
    }

    private func resetComboEngine() {
        currentComboBasePoints = 0
        currentMultiplier      = 0
        activeTricksInCombo.removeAll()
        comboTimerRemaining = 0.0
        currentState        = .idle
        sendUIUpdate()
    }

    private func sendUIUpdate() {
        onComboUIUpdate?(
            currentComboBasePoints,
            currentMultiplier,
            comboTimerRemaining,
            activeTricksInCombo.map { $0.name }
        )
    }
}
