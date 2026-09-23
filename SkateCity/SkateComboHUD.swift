import SpriteKit

/// SpriteKit overlay scene mounted on SCNView.overlaySKScene.
/// Receives data from SkateComboManager via onComboUIUpdate.
///
/// Wire-up in GameViewController.buildHUD():
///   let hud = SkateComboHUD(size: scnView.bounds.size)
///   scnView.overlaySKScene = hud
///   comboManager.onComboUIUpdate = { base, mult, time, tricks in
///       hud.updateHUD(basePoints: base, multiplier: mult,
///                     timeRemaining: time, tricks: tricks)
///   }
final class SkateComboHUD: SKScene {

    // MARK: - Nodes

    private let scoreLabel      = SKLabelNode(fontNamed: "Impact")
    private let multiplierLabel = SKLabelNode(fontNamed: "Impact")
    private let trickListLabel  = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
    private let flashLabel      = SKLabelNode(fontNamed: "HelveticaNeue-Heavy")

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        scaleMode            = .resizeFill
        isUserInteractionEnabled = false
        backgroundColor      = .clear
        setupNodes()
    }

    private func setupNodes() {
        scoreLabel.fontSize                = 42
        scoreLabel.fontColor               = .white
        scoreLabel.horizontalAlignmentMode = .right
        scoreLabel.position                = CGPoint(x: size.width * 0.48, y: 90)
        scoreLabel.zPosition               = 10
        addChild(scoreLabel)

        multiplierLabel.fontSize                = 50
        multiplierLabel.fontColor               = .systemYellow
        multiplierLabel.horizontalAlignmentMode = .left
        multiplierLabel.position                = CGPoint(x: size.width * 0.52, y: 86)
        multiplierLabel.zPosition               = 10
        addChild(multiplierLabel)

        trickListLabel.fontSize                = 18
        trickListLabel.fontColor               = .lightGray
        trickListLabel.horizontalAlignmentMode = .center
        trickListLabel.position                = CGPoint(x: size.width / 2, y: 52)
        trickListLabel.zPosition               = 10
        addChild(trickListLabel)

        flashLabel.fontSize                = 28
        flashLabel.fontColor               = .white
        flashLabel.horizontalAlignmentMode = .center
        flashLabel.position                = CGPoint(x: size.width / 2, y: size.height * 0.38)
        flashLabel.zPosition               = 10
        flashLabel.alpha                   = 0
        addChild(flashLabel)
    }

    // MARK: - Public API

    /// Matches the SkateComboManager.onComboUIUpdate closure signature directly.
    func updateHUD(basePoints: Int, multiplier: Int,
                   timeRemaining: TimeInterval, tricks: [String]) {
        if multiplier == 0 {
            scoreLabel.text      = ""
            multiplierLabel.text = ""
            trickListLabel.text  = ""
            return
        }

        scoreLabel.text      = "\(basePoints)"
        multiplierLabel.text = "×\(multiplier)"
        trickListLabel.text  = tricks.joined(separator: " + ")

        // Pop-scale burst on each new trick registration
        guard scoreLabel.action(forKey: "pop") == nil else { return }
        scoreLabel.run(
            .sequence([.scale(to: 1.25, duration: 0.05), .scale(to: 1.0, duration: 0.10)]),
            withKey: "pop"
        )
    }

    /// Flashes trick name at the screen centre — called alongside onTrickPopped.
    func flashTrick(_ name: String) {
        flashLabel.removeAllActions()
        flashLabel.text      = name.uppercased()
        flashLabel.fontColor = .white
        flashLabel.alpha     = 1
        flashLabel.run(.sequence([
            .wait(forDuration: 0.55),
            .fadeOut(withDuration: 0.85)
        ]))
    }

    /// Flashes "BAILED" in red — called alongside onComboBail.
    func showBail() {
        flashLabel.removeAllActions()
        flashLabel.text      = "BAILED"
        flashLabel.fontColor = .red
        flashLabel.alpha     = 1
        flashLabel.run(.sequence([
            .wait(forDuration: 0.7),
            .fadeOut(withDuration: 0.5),
            .run { [weak self] in self?.flashLabel.fontColor = .white }
        ]))
    }
}
