// Copyright © 2026 MAR / SkateCity. All rights reserved.
// Unauthorized reproduction, distribution, or modification is strictly prohibited.

#if os(iOS)
import UIKit
import SceneKit

/// Root UIViewController for the SkateCity SceneKit game loop.
final class GameViewController: UIViewController {

    // MARK: - Scene graph
    private var sceneView:   SCNView!
    private var scene:       SCNScene!
    private var boardNode:   SCNNode!
    private var cameraNode:  SCNNode!
    private var sparkNode:   SCNNode!

    // MARK: - Engine systems
    private var physicsTicker:  PerformancePhysicsTicker!
    private var comboManager:   SkateComboManager!
    private var grindBalance:   GrindBalanceSystem!
    private var skateInputView: SkateInputView!
    private var ragdoll:        SkaterRagdollController?
    private var wasGrinding = false

    // MARK: - Avatar systems
    private var avatarModel:    AvatarModel!
    private var skateboardModel: SkateboardModel!
    private var animController: AnimationController!
    private var lodManager:     CharacterLODManager!
    private var lastRenderTime: TimeInterval = 0

    // MARK: - Graphics
    private var currentQuality: GraphicsQuality = .high
    private var shaderMaterials: [SCNMaterial]  = []

    // MARK: - HUD
    private var comboHUD:     SkateComboHUD!
    private var scoreLabel:   UILabel!
    private var comboLabel:   UILabel!
    private var todButton:    UIButton!
    private var qualityButton: UIButton!

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

    override var prefersStatusBarHidden:           Bool { true }
    override var prefersHomeIndicatorAutoHidden:   Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }

    // MARK: - Scene construction

    private func buildSceneView() {
        scene = SCNScene()

        sceneView = SCNView(frame: view.bounds)
        sceneView.autoresizingMask    = [.flexibleWidth, .flexibleHeight]
        sceneView.scene               = scene
        sceneView.delegate            = self
        sceneView.showsStatistics     = false
        sceneView.backgroundColor     = .black
        sceneView.rendersContinuously = true
        view.addSubview(sceneView)
    }

    private func buildScene() {
        // Full Ultra pipeline: lighting, IBL, quality-tier camera config
        UltraGraphicsManager.shared.setup(scene: scene, scnView: sceneView, quality: currentQuality)

        SkateCityMapBuilder.build(into: scene)
        buildSkateboardNode()
        buildAvatarSystems()
        buildCamera()

        physicsTicker = PerformancePhysicsTicker()
        comboManager  = SkateComboManager()
        grindBalance  = GrindBalanceSystem()

        // Grind sparks particle node — parented to the board
        let sparks = UltraGraphicsManager.shared.makeGrindSparks()
        sparkNode  = SCNNode()
        sparkNode.addParticleSystem(sparks)
        boardNode.addChildNode(sparkNode)
        sparkNode.isHidden = true

        // Walk hierarchy, apply world-space shader materials
        UltraGraphicsManager.shared.applyMaterials(to: scene.rootNode, shaderMats: &shaderMaterials)
        UltraGraphicsManager.shared.registerShaderMaterials(shaderMaterials)

        // Ragdoll — rigs once board node is built
        ragdoll = SkaterRagdollController(skaterNode: boardNode)
        ragdoll?.rigCoreBodySegments(in: scene)

        // ACES post-processing technique
        if let technique = UltraGraphicsManager.shared.makePostFXTechnique(quality: currentQuality) {
            sceneView.technique = technique
        }
    }

    // MARK: Skateboard node

    private func buildSkateboardNode() {
        boardNode = SCNNode()
        boardNode.name = "board"
        boardNode.position = SCNVector3(0, 0.5, 0)

        let deckGeo  = SCNBox(width: 0.21, height: 0.02, length: 0.82, chamferRadius: 0.005)
        let deckMat  = Mat.pbr(0x2A2A2A, rough: 0.9)   // grip tape top
        let bottomMat = Mat.make(0xFFFFFF, rough: 0.5)   // graphic underside
        deckGeo.materials = [deckMat, deckMat, deckMat, deckMat, deckMat, bottomMat]
        let deckNode = SCNNode(geometry: deckGeo); deckNode.name = "deck"
        boardNode.addChildNode(deckNode)

        for zOffset in [-0.30, 0.30] as [Float] {
            let truckGeo  = SCNBox(width: 0.20, height: 0.03, length: 0.04, chamferRadius: 0.002)
            truckGeo.materials = [Mat.pbr(0xAAB2BC, rough: 0.35, metal: 0.85)]
            let truckNode = SCNNode(geometry: truckGeo); truckNode.name = "truck"
            truckNode.position = SCNVector3(0, -0.025, zOffset)
            boardNode.addChildNode(truckNode)

            for xOffset in [-0.09, 0.09] as [Float] {
                let wheelGeo  = SCNCylinder(radius: 0.028, height: 0.025)
                wheelGeo.materials = [Mat.pbr(0xF6EFE0, rough: 0.65)]
                let wheelNode = SCNNode(geometry: wheelGeo); wheelNode.name = "wheel"
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
        boardNode.castsShadow = true
        scene.rootNode.addChildNode(boardNode)
    }

    // MARK: Avatar + skateboard model

    private func buildAvatarSystems() {
        // Skateboard visual model (separate from physics boardNode)
        skateboardModel = SkateboardModel()
        boardNode.addChildNode(skateboardModel.boardRoot)

        // Avatar model — sits on top of the board
        avatarModel = AvatarModel()
        avatarModel.rootNode.position = SCNVector3(0, 0.12, 0)
        boardNode.addChildNode(avatarModel.rootNode)

        // Apply saved wardrobe profile
        if let data = UserDefaults.standard.data(forKey: "skaterWardrobeProfile"),
           let profile = try? JSONDecoder().decode(SkaterWardrobeProfile.self, from: data) {
            avatarModel.apply(profile: profile)
            skateboardModel.apply(profile: profile)
        } else {
            avatarModel.apply(profile: SkaterWardrobeProfile())
            skateboardModel.apply(profile: SkaterWardrobeProfile())
        }

        // Animation + LOD systems
        animController = AnimationController(avatar: avatarModel)
        lodManager     = CharacterLODManager()
    }

    // MARK: Camera

    private func buildCamera() {
        cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        UltraGraphicsManager.shared.configureCamera(cameraNode.camera!, quality: currentQuality)
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

        comboHUD = SkateComboHUD(size: sceneView.bounds.size)
        sceneView.overlaySKScene = comboHUD

        scoreLabel = makeLabel(font: .monospacedDigitSystemFont(ofSize: 22, weight: .bold),   align: .left)
        comboLabel = makeLabel(font: .monospacedDigitSystemFont(ofSize: 14, weight: .regular), align: .left)
        view.addSubview(scoreLabel)
        view.addSubview(comboLabel)

        // Top-right pills: Time of Day | Quality
        todButton     = makePillButton(title: "Day",  action: #selector(cycleTOD))
        qualityButton = makePillButton(title: "High", action: #selector(cycleQuality))
        view.addSubview(todButton)
        view.addSubview(qualityButton)

        NSLayoutConstraint.activate([
            scoreLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            scoreLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            comboLabel.topAnchor.constraint(equalTo: scoreLabel.bottomAnchor, constant: 2),
            comboLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),

            qualityButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            qualityButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            todButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            todButton.trailingAnchor.constraint(equalTo: qualityButton.leadingAnchor, constant: -8),
        ])
    }

    private func makeLabel(font: UIFont, align: NSTextAlignment) -> UILabel {
        let lbl = UILabel()
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.font = font; lbl.textColor = .white; lbl.textAlignment = align; lbl.numberOfLines = 0
        lbl.layer.shadowColor = UIColor.black.cgColor; lbl.layer.shadowRadius = 3
        lbl.layer.shadowOpacity = 0.8; lbl.layer.shadowOffset = .zero
        return lbl
    }

    private func makePillButton(title: String, action: Selector) -> UIButton {
        let btn = UIButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 11, weight: .heavy)
        btn.setTitleColor(.white, for: .normal)
        btn.backgroundColor = UIColor(white: 1, alpha: 0.18)
        btn.layer.cornerRadius = 11
        btn.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        btn.addTarget(self, action: action, for: .touchUpInside)
        return btn
    }

    // MARK: - TOD / Quality cycling

    @objc private func cycleTOD() {
        UltraGraphicsManager.shared.cycleTimeOfDay()
        todButton.setTitle(UltraGraphicsManager.shared.timeOfDay.label, for: .normal)
    }

    @objc private func cycleQuality() {
        switch currentQuality {
        case .low:   currentQuality = .high
        case .high:  currentQuality = .ultra
        case .ultra: currentQuality = .low
        }
        qualityButton.setTitle(currentQuality.rawValue, for: .normal)
        if let cam = cameraNode?.camera {
            UltraGraphicsManager.shared.configureCamera(cam, quality: currentQuality)
        }
        UltraGraphicsManager.shared.configureView(sceneView, quality: currentQuality)
        // Re-apply or remove post-processing technique
        sceneView.technique = UltraGraphicsManager.shared.makePostFXTechnique(quality: currentQuality)
    }

    // MARK: - Callback wiring

    private func bindInputCallbacks() {
        skateInputView.onStanceChanged = { [weak self] stick in
            guard let self else { return }
            let lateralForce = SCNVector3(Double(stick.x) * 8, 0, 0)
            boardNode.physicsBody?.applyForce(lateralForce, asImpulse: false)
            animController?.leanInput = stick.x
            skateboardModel?.steer(input: stick.x)
        }

        skateInputView.onTrickPopped = { [weak self] trick, velocity in
            guard let self else { return }
            let points = TrickRegistry.basePoints(for: trick) + Int(velocity * 0.5)
            comboManager.addTrickToCombo(name: trick.rawValue, basePoints: points)
            boardNode.physicsBody?.applyForce(
                SCNVector3(0, Double(5 + velocity * 0.3), 0), asImpulse: true)
            comboHUD.flashTrick(trick.rawValue)
            SeshFMAudioEngine.shared.playTrickSFX(for: trick)

            // Drive avatar animation from trick type
            switch trick {
            case .ollie:     animController?.transition(to: .ollie)
            case .kickflip:  animController?.transition(to: .kickflip)
            case .heelflip:  animController?.transition(to: .heelflip)
            case .popShuvit: animController?.transition(to: .popShuvit)
            default:         animController?.transition(to: .ollie)
            }
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
                self.scoreLabel.text = "Score: \(self.comboManager.totalCareerScore)"
                ProfilePersistenceManager.shared.appendCareerPoints(score)
                let tricks = self.comboManager.activeTricksInCombo.map { $0.name }
                ProfilePersistenceManager.shared.evaluateAndRecordNewComboLine(score: score, tricks: tricks)
                SeshFMAudioEngine.shared.playLandingSFX()
            }
        }
        comboManager.onComboBail = { [weak self] in
            guard let self else { return }
            let vel = self.boardNode?.physicsBody?.velocity ?? .init(0, 0, 0)
            self.ragdoll?.eject(boardVelocity: vel)
            self.animController?.transition(to: .bail)
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

        let dt = lastRenderTime == 0 ? 0.016 : Float(min(time - lastRenderTime, 0.05))
        lastRenderTime = time

        physicsTicker.tickEngineUpdate(at: time, boardNode: board)

        // Skateboard visual — wheel spin proportional to physics velocity
        let vel = board.physicsBody?.velocity ?? .init(0, 0, 0)
        let speed = Float(sqrt(vel.x*vel.x + vel.z*vel.z))
        skateboardModel?.tickWheels(speed: speed, deltaTime: dt)

        // Avatar animation update
        if let anim = animController {
            anim.forwardBob = min(speed / 8.0, 1.0)
            anim.boardSurfaceY = Float(board.position.y) + 0.095
            anim.update(deltaTime: dt)

            // Switch cruise/idle based on movement
            if speed > 1.5 && anim.state == .idle {
                anim.transition(to: .cruise)
            } else if speed < 0.5 && anim.state == .cruise {
                anim.transition(to: .idle)
            }
        }

        // LOD update (once per 6 frames is enough)
        if let cam = cameraNode, let lod = lodManager, let av = avatarModel, let sb = skateboardModel {
            let newLOD = lod.evaluate(cameraPosition: cam.worldPosition, avatarPosition: board.worldPosition)
            if newLOD != lod.currentLOD {
                lod.apply(lod: newLOD, to: av)
                lod.apply(lod: newLOD, to: sb)
            }
        }

        let isGrinding = comboManager.currentState == .balancing

        // Grind spark visibility + audio loop transitions + avatar state
        if isGrinding && !wasGrinding {
            sparkNode?.isHidden = false
            SeshFMAudioEngine.shared.startGrindLoop()
            animController?.transition(to: .grind)
        } else if !isGrinding && wasGrinding {
            sparkNode?.isHidden = true
            SeshFMAudioEngine.shared.stopGrindLoop()
            animController?.transition(to: .cruise)
        }
        wasGrinding = isGrinding

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

        // Board tilt alignment to slope
        if physicsTicker.optimalIsGrounded {
            let n = physicsTicker.cachedGroundNormal
            board.eulerAngles.x = Float(atan2(Double(n.z), Double(n.y)))
            board.eulerAngles.z = Float(-atan2(Double(n.x), Double(n.y)))
        }
    }
}
#endif
