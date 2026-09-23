#if os(iOS)
import UIKit
import SceneKit

/// Root UIViewController for the SkateCity SceneKit game loop.
/// Drop a UIViewControllerRepresentable wrapper around this in SwiftUI (see ContentView).
final class GameViewController: UIViewController {

    // MARK: - Scene graph
    private var sceneView:  SCNView!
    private var scene:      SCNScene!
    private var boardNode:  SCNNode!
    private var cameraNode: SCNNode!

    // MARK: - Engine systems (RemasteredGraphicsManager is static — no instance needed)
    private var physicsTicker:  PerformancePhysicsTicker!
    private var comboManager:   SkateComboManager!
    private var grindBalance:   GrindBalanceSystem!
    private var skateInputView: SkateInputView!
    private var ragdoll:        SkaterRagdollController?
    private var wasGrinding = false

    // MARK: - HUD
    private var comboHUD:   SkateComboHUD!
    private var scoreLabel: UILabel!
    private var comboLabel: UILabel!

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        buildSceneView()
        buildScene()
        buildHUD()
        bindInputCallbacks()
        wireComboCallbacks()
        SeshFMAudioEngine.shared.start()
    }

    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }

    // MARK: - Scene construction

    private func buildSceneView() {
        scene = SCNScene()

        sceneView = SCNView(frame: view.bounds)
        sceneView.autoresizingMask         = [.flexibleWidth, .flexibleHeight]
        sceneView.scene                    = scene
        sceneView.delegate                 = self
        sceneView.antialiasingMode         = .multisampling4X
        sceneView.preferredFramesPerSecond = 120
        sceneView.showsStatistics          = false
        sceneView.backgroundColor          = .black
        sceneView.rendersContinuously      = true
        view.addSubview(sceneView)
    }

    private func buildScene() {
        buildLighting()
        SkateCityMapBuilder.build(into: scene)
        buildSkateboardNode()
        buildCamera()

        physicsTicker = PerformancePhysicsTicker()
        comboManager  = SkateComboManager()
        grindBalance  = GrindBalanceSystem()

        // Ragdoll — rigs once board node is built; no-op until avatar GLB is loaded
        ragdoll = SkaterRagdollController(skaterNode: boardNode)
        ragdoll?.rigCoreBodySegments(in: scene)

        // Single pipeline call stamps PBR on every node via enumerateChildNodes.
        // Node names (set by SkateCityMapBuilder) drive per-role texture routing.
        RemasteredGraphicsManager.setupRemasteredPipeline(for: scene, targetNode: scene.rootNode)
    }

    // MARK: Lighting

    private func buildLighting() {
        // Sun — directional, casts shadows
        let sunNode  = SCNNode()
        let sunLight = SCNLight()
        sunLight.type              = .directional
        sunLight.intensity         = 1800
        sunLight.temperature       = 6500
        sunLight.castsShadow       = true
        sunLight.shadowRadius      = 3
        sunLight.shadowSampleCount = 16
        sunLight.shadowMapSize     = CGSize(width: 2048, height: 2048)
        sunLight.shadowMode        = .deferred
        sunLight.orthographicScale = 30
        sunNode.light = sunLight
        sunNode.eulerAngles = SCNVector3(-Float.pi / 4, Float.pi / 5, 0)
        scene.rootNode.addChildNode(sunNode)

        // Ambient fill
        let ambientNode  = SCNNode()
        let ambientLight = SCNLight()
        ambientLight.type      = .ambient
        ambientLight.intensity = 400
        ambientLight.color     = UIColor(white: 0.9, alpha: 1)
        ambientNode.light = ambientLight
        scene.rootNode.addChildNode(ambientNode)
    }

    // MARK: Skateboard node

    private func buildSkateboardNode() {
        boardNode = SCNNode()
        boardNode.name = "board"
        boardNode.position = SCNVector3(0, 0.5, 0)

        let deckGeo  = SCNBox(width: 0.21, height: 0.02, length: 0.82, chamferRadius: 0.005)
        let deckNode = SCNNode(geometry: deckGeo)
        deckNode.name = "deck"
        boardNode.addChildNode(deckNode)

        for zOffset in [-0.30, 0.30] as [Float] {
            let truckGeo  = SCNBox(width: 0.20, height: 0.03, length: 0.04, chamferRadius: 0.002)
            let truckNode = SCNNode(geometry: truckGeo)
            truckNode.name = "truck"
            truckNode.position = SCNVector3(0, -0.025, zOffset)
            boardNode.addChildNode(truckNode)

            for xOffset in [-0.09, 0.09] as [Float] {
                let wheelGeo  = SCNCylinder(radius: 0.028, height: 0.025)
                let wheelNode = SCNNode(geometry: wheelGeo)
                wheelNode.name = "wheel"
                wheelNode.position = SCNVector3(xOffset, -0.014, zOffset)
                wheelNode.eulerAngles.z = Float.pi / 2
                boardNode.addChildNode(wheelNode)
            }
        }

        let physicsShape = SCNPhysicsShape(
            geometry: SCNBox(width: 0.21, height: 0.08, length: 0.82, chamferRadius: 0),
            options: nil)
        boardNode.physicsBody = SCNPhysicsBody(type: .dynamic, shape: physicsShape)
        boardNode.physicsBody?.mass           = 1.5
        boardNode.physicsBody?.friction       = 0.6
        boardNode.physicsBody?.restitution    = 0.1
        boardNode.physicsBody?.angularDamping = 0.85
        boardNode.physicsBody?.allowsResting  = false

        scene.rootNode.addChildNode(boardNode)
    }

    // MARK: Camera

    private func buildCamera() {
        cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView        = 65
        cameraNode.camera?.zNear              = 0.1
        cameraNode.camera?.zFar               = 300
        cameraNode.camera?.wantsHDR           = true
        cameraNode.camera?.bloomIntensity      = 0.4
        cameraNode.camera?.motionBlurIntensity = 0.3
        cameraNode.position      = SCNVector3(0, 2.5, 4.5)
        cameraNode.eulerAngles.x = -0.25
        boardNode.addChildNode(cameraNode)
    }

    // MARK: - HUD & Input

    private func buildHUD() {
        skateInputView = SkateInputView(frame: view.bounds)
        skateInputView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        skateInputView.backgroundColor  = .clear
        view.addSubview(skateInputView)

        // SpriteKit overlay — handles trick names, multipliers, bail flash
        comboHUD = SkateComboHUD(size: sceneView.bounds.size)
        sceneView.overlaySKScene = comboHUD

        // UILabel career score (top-left, above the SpriteKit canvas)
        scoreLabel = makeLabel(font: .monospacedDigitSystemFont(ofSize: 22, weight: .bold), align: .left)
        comboLabel = makeLabel(font: .monospacedDigitSystemFont(ofSize: 14, weight: .regular), align: .left)

        view.addSubview(scoreLabel)
        view.addSubview(comboLabel)

        NSLayoutConstraint.activate([
            scoreLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            scoreLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),

            comboLabel.topAnchor.constraint(equalTo: scoreLabel.bottomAnchor, constant: 2),
            comboLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
        ])
    }

    private func makeLabel(font: UIFont, align: NSTextAlignment) -> UILabel {
        let lbl = UILabel()
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.font          = font
        lbl.textColor     = .white
        lbl.textAlignment = align
        lbl.numberOfLines = 0
        lbl.layer.shadowColor   = UIColor.black.cgColor
        lbl.layer.shadowRadius  = 3
        lbl.layer.shadowOpacity = 0.8
        lbl.layer.shadowOffset  = .zero
        return lbl
    }

    // MARK: - Callback wiring

    private func bindInputCallbacks() {
        skateInputView.onStanceChanged = { [weak self] stick in
            guard let self else { return }
            let lateralForce = SCNVector3(Double(stick.x) * 8, 0, 0)
            boardNode.physicsBody?.applyForce(lateralForce, asImpulse: false)
        }

        skateInputView.onTrickPopped = { [weak self] trick, velocity in
            guard let self else { return }
            let points = TrickRegistry.basePoints(for: trick) + Int(velocity * 0.5)
            comboManager.addTrickToCombo(name: trick.rawValue, basePoints: points)
            boardNode.physicsBody?.applyForce(
                SCNVector3(0, Double(5 + velocity * 0.3), 0), asImpulse: true)
            comboHUD.flashTrick(trick.rawValue)
            SeshFMAudioEngine.shared.playTrickSFX(for: trick)
        }
    }

    private func wireComboCallbacks() {
        comboManager.onComboUIUpdate = { [weak self] base, mult, time, tricks in
            guard let self else { return }
            DispatchQueue.main.async {
                self.comboHUD.updateHUD(basePoints: base, multiplier: mult,
                                        timeRemaining: time, tricks: tricks)
                self.comboLabel.text = mult > 1 ? "×\(mult) combo active" : ""
            }
        }
        comboManager.onComboLandSuccess = { [weak self] score in
            guard let self else { return }
            DispatchQueue.main.async {
                let career = self.comboManager.totalCareerScore
                self.scoreLabel.text = "Score: \(career)"
                ProfilePersistenceManager.shared.appendCareerPoints(score)
                let tricks = self.comboManager.activeTricksInCombo.map { $0.name }
                ProfilePersistenceManager.shared.evaluateAndRecordNewComboLine(score: score, tricks: tricks)
                SeshFMAudioEngine.shared.playLandingSFX()
            }
        }
        comboManager.onComboBail = { [weak self] in
            guard let self else { return }
            // Eject ragdoll with current board momentum
            let vel = self.boardNode?.physicsBody?.velocity ?? .init(0, 0, 0)
            self.ragdoll?.eject(boardVelocity: vel)
            DispatchQueue.main.async {
                self.comboHUD.showBail()
                self.comboLabel.text = ""
                SeshFMAudioEngine.shared.playBailSFX()
            }
        }
    }
}

// MARK: - SCNSceneRendererDelegate

extension GameViewController: SCNSceneRendererDelegate {

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        guard let board = boardNode else { return }

        // Sub-tick physics (60 Hz raycast inside 120 FPS render loop)
        physicsTicker.tickEngineUpdate(at: time, boardNode: board)

        let isGrinding = comboManager.currentState == .balancing

        // Grind loop audio state transitions
        if isGrinding && !wasGrinding {
            SeshFMAudioEngine.shared.startGrindLoop()
        } else if !isGrinding && wasGrinding {
            SeshFMAudioEngine.shared.stopGrindLoop()
        }
        wasGrinding = isGrinding

        // Grind balance (only active while in balancing state)
        if isGrinding {
            grindBalance.updateGrindBalance(
                deltaTime:     1.0 / 120.0,
                currentTime:   time,
                leftJoystickY: skateInputView.leftStickOutput.y
            )
            if grindBalance.isWrecked {
                comboManager.bailCurrentCombo()
                grindBalance.resetSystem()
            }
        }

        // Combo clock
        if !physicsTicker.optimalIsGrounded {
            comboManager.updateComboClock(deltaTime: 1.0 / 120.0)
        } else if comboManager.currentState == .tricking {
            comboManager.landCurrentCombo()
        }

        // Align board tilt to slope normal
        if physicsTicker.optimalIsGrounded {
            let n = physicsTicker.cachedGroundNormal
            board.eulerAngles.x = Float(atan2(Double(n.z), Double(n.y)))
            board.eulerAngles.z = Float(-atan2(Double(n.x), Double(n.y)))
        }
    }
}
#endif
