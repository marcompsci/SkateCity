//  GameEngine.swift
//  The heart of SkateCity: skate physics, trick system, grinds, manuals, combos, bails,
//  chase camera and cinematic rendering setup (HDR, bloom, SSAO, soft cascaded shadows, physical sky).
//
//  Physics is arcade-style (like THPS): a raycast "ground follower" that rides any surface,
//  launches off lips/copings, vert-assist on quarter pipes, and snap-to-rail grinding.

import SceneKit
import ModelIO
import UIKit
import simd

@MainActor
final class GameEngine: NSObject {

    // MARK: Scene
    let scene = SCNScene()
    let world: World
    let rig: SkaterRig
    let cameraNode = SCNNode()
    private weak var model: GameModel?
    private let input: InputState
    private var link: CADisplayLink?
    private var lastTime: CFTimeInterval = 0
    private var accumulator: Float = 0
    private let fixedDT: Float = 1.0 / 120.0
    private let hitOptions: [String: Any] = [
        SCNHitTestOption.categoryBitMask.rawValue: solidCategory,
        SCNHitTestOption.searchMode.rawValue: SCNHitTestSearchMode.closest.rawValue,
        SCNHitTestOption.ignoreHiddenNodes.rawValue: true
    ]

    // MARK: Tuning (tweak these to change the feel)
    private let gravity: Float = 13.5
    private let maxPushSpeed: Float = 10.5
    private let pushAccel: Float = 5.5
    private let ollieImpulse: Float = 5.6
    private let spinRate: Float = 7.2

    // MARK: Skater state
    enum Mode { case ground, air, grind, bail }
    private var mode: Mode = .ground
    private var pos: SIMD3<Float>
    private var heading: Float = 0
    private var speed: Float = 0
    private var vel = SIMD3<Float>(0, 0, 0)
    private var groundNormal = SIMD3<Float>(0, 1, 0)
    private var smoothNormal = SIMD3<Float>(0, 1, 0)
    private var lastVy: Float = 0
    private var ollieCharge: Float = 0
    private var prevOllieHeld = false
    private var pushPhase: Float = 0
    private var isPushing = false

    // Air
    private var airTime: Float = 0
    private var spinVel: Float = 0
    private var spinAccum: Float = 0
    private var flipKind: FlipKind?
    private var flipT: Float = 0
    private var grabKind: GrabKind?
    private var grabTime: Float = 0
    private var lastGrab: GrabKind = .melon
    private var airTricks = 0

    // Grind
    private var railIndex = -1
    private var railT: Float = 0
    private var railDir: Float = 1
    private var grindSpeed: Float = 0
    private var grindTime: Float = 0
    private var grindKind: GrindKind = .fiftyFifty
    private var lastRailIndex = -1
    private var railCooldown: Float = 0

    // Balance (grinds + manuals)
    private var balance: Float = 0
    private var balanceVel: Float = 0
    private var balanceDrift: Float = 0
    private var manualActive = false
    private var manualTime: Float = 0

    // Combo
    private var combo = ComboTracker()
    private var landGrace: Float = 0

    // Bail
    private var bailTimer: Float = 0
    private var bailProgress: Float = 0
    private var bailSlide = SIMD3<Float>(0, 0, 0)

    // Visual smoothing
    private var visualYaw: Float = 0
    private var camYaw: Float = 0
    private var camPos = SIMD3<Float>(0, 0, 0)
    private var landSquash: Float = 0
    private var pose = RigPose()
    private var yawOffset: Float = 0
    private var boardPitch: Float = 0

    // Session
    private let timed: Bool
    private var timeLeft: Float = 120
    private var ended = false
    private var hudTimer: Float = 0

    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)
    private let heavyHaptic = UIImpactFeedbackGenerator(style: .heavy)
    private let rigidHaptic = UIImpactFeedbackGenerator(style: .rigid)

    // MARK: - Setup

    init(view: SCNView, model: GameModel) {
        self.model = model
        self.input = model.input
        let w = World()
        self.world = w
        self.rig = SkaterRig(style: model.skater)
        self.timed = model.mode == .session
        self.pos = w.spawn
        super.init()
        setupScene(quality: model.quality)
        view.scene = scene
        view.pointOfView = cameraNode
        view.backgroundColor = .black
        view.antialiasingMode = model.quality == .ultra ? .multisampling4X : .multisampling2X
        view.preferredFramesPerSecond = 120
        view.rendersContinuously = true
        view.isPlaying = true
        camPos = pos + SIMD3(0, 2, -4.6)
        model.engine = self
        visuals(0.016)
    }

    private func setupScene(quality: GraphicsQuality) {
        let ultra = quality == .ultra
        scene.rootNode.addChildNode(world.root)
        scene.rootNode.addChildNode(rig.root)

        // Physically based sky (golden hour) used for background AND image-based lighting
        let sky = MDLSkyCubeTexture(name: "sky", channelEncoding: .float16,
                                    textureDimensions: vector_int2(512, 512),
                                    turbidity: 0.45, sunElevation: 0.62,
                                    upperAtmosphereScattering: 0.4, groundAlbedo: 0.35)
        sky.sunAzimuth = 2.3
        sky.update()
        scene.background.contents = sky
        scene.lightingEnvironment.contents = sky
        scene.lightingEnvironment.intensity = 1.3

        scene.fogStartDistance = 70
        scene.fogEndDistance = 340
        scene.fogDensityExponent = 1.3
        scene.fogColor = UIColor(red: 0.86, green: 0.74, blue: 0.64, alpha: 1)

        // Sun
        let sun = SCNLight()
        sun.type = .directional
        sun.intensity = 2200
        sun.temperature = 4700
        sun.castsShadow = true
        sun.shadowMode = .deferred
        sun.shadowSampleCount = ultra ? 16 : 4
        sun.shadowRadius = ultra ? 4 : 2
        sun.shadowMapSize = ultra ? CGSize(width: 4096, height: 4096) : CGSize(width: 2048, height: 2048)
        sun.shadowCascadeCount = ultra ? 4 : 2
        sun.maximumShadowDistance = 90
        sun.automaticallyAdjustsShadowProjection = true
        sun.shadowColor = UIColor(white: 0, alpha: 0.65)
        let sunNode = SCNNode()
        sunNode.light = sun
        sunNode.simdEulerAngles = SIMD3(-0.5, 2.3, 0)
        scene.rootNode.addChildNode(sunNode)

        // Soft sky fill
        let fill = SCNLight()
        fill.type = .ambient
        fill.intensity = 120
        fill.color = UIColor(red: 0.6, green: 0.7, blue: 1, alpha: 1)
        let fillNode = SCNNode()
        fillNode.light = fill
        scene.rootNode.addChildNode(fillNode)

        // Cinematic camera
        let cam = SCNCamera()
        cam.fieldOfView = 64
        cam.zNear = 0.05
        cam.zFar = 900
        cam.wantsHDR = true
        cam.wantsExposureAdaptation = true
        cam.exposureAdaptationBrighteningSpeedFactor = 0.5
        cam.exposureAdaptationDarkeningSpeedFactor = 0.5
        cam.bloomIntensity = 0.6
        cam.bloomThreshold = 0.85
        cam.bloomBlurRadius = 10
        cam.vignettingIntensity = 0.35
        cam.vignettingPower = 0.6
        cam.saturation = 1.08
        cam.contrast = 0.08
        if ultra {
            cam.screenSpaceAmbientOcclusionIntensity = 1.1
            cam.screenSpaceAmbientOcclusionRadius = 0.6
            cam.motionBlurIntensity = 0.3
            cam.colorFringeIntensity = 0.25
            cam.colorFringeStrength = 0.4
        }
        cameraNode.camera = cam
        scene.rootNode.addChildNode(cameraNode)
    }

    func start() {
        guard link == nil else { return }
        let l = CADisplayLink(target: self, selector: #selector(tick(_:)))
        l.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        l.add(to: .main, forMode: .common)
        link = l
        lastTime = 0
    }

    func stop() {
        link?.invalidate()
        link = nil
    }

    // MARK: - Loop

    @objc private func tick(_ l: CADisplayLink) {
        let now = l.timestamp
        guard lastTime > 0 else { lastTime = now; return }
        let frame = min(Float(now - lastTime), 0.1)
        lastTime = now
        input.poll()
        guard let model, !model.isPaused, !ended else { return }

        accumulator += frame
        while accumulator >= fixedDT {
            simulate(fixedDT)
            accumulator -= fixedDT
            if ended { return }
        }
        updateCity(frame)
        visuals(frame)
        publishHUD(frame)
    }

    private func simulate(_ dt: Float) {
        let ollieReleased = prevOllieHeld && !input.ollieHeld
        prevOllieHeld = input.ollieHeld

        switch mode {
        case .ground: simulateGround(dt, ollieReleased: ollieReleased)
        case .air: simulateAir(dt)
        case .grind: simulateGrind(dt, ollieReleased: ollieReleased)
        case .bail: simulateBail(dt)
        }

        if timed {
            timeLeft -= dt
            if timeLeft <= 0 && !ended {
                ended = true
                if combo.active && mode != .bail && mode != .air { bankCombo() }
                model?.timeLeft = 0
                model?.endGame()
            }
        }
    }

    // MARK: - Raycasts

    private struct Hit { let point: SIMD3<Float>; let normal: SIMD3<Float> }

    private func ray(_ from: SIMD3<Float>, _ to: SIMD3<Float>) -> Hit? {
        let results = scene.rootNode.hitTestWithSegment(from: SCNVector3(from.x, from.y, from.z),
                                                        to: SCNVector3(to.x, to.y, to.z), options: hitOptions)
        guard let h = results.first else { return nil }
        let n = h.simdWorldNormal
        return Hit(point: h.simdWorldCoordinates, normal: simd_length(n) > 0 ? simd_normalize(n) : SIMD3(0, 1, 0))
    }

    private func ground(_ x: Float, _ z: Float, top: Float, bottom: Float) -> Hit? {
        ray(SIMD3(x, top, z), SIMD3(x, bottom, z))
    }

    private func clampBounds(_ p: inout SIMD3<Float>) {
        p.x = max(-world.bounds, min(world.bounds, p.x))
        p.z = max(-world.bounds, min(world.bounds, p.z))
    }

    private func surfaceForward(_ n: SIMD3<Float>) -> SIMD3<Float> {
        let fwd = SIMD3<Float>(sin(heading), 0, cos(heading))
        let f = fwd - n * simd_dot(fwd, n)
        return simd_length(f) > 1e-4 ? simd_normalize(f) : fwd
    }

    // MARK: - Ground

    private func simulateGround(_ dt: Float, ollieReleased: Bool) {
        let s = input.stick

        if input.manualBuffered && !manualActive && speed > 1 { startManual() }
        if !manualActive && landGrace > 0 {
            landGrace -= dt
            if landGrace <= 0 { bankCombo() }
        }

        heading -= s.x * (manualActive ? 1.2 : 2.3) * dt
        var fs = surfaceForward(groundNormal)

        isPushing = false
        if !manualActive {
            if s.y > 0.35 && speed < maxPushSpeed && groundNormal.y > 0.95 {
                speed += pushAccel * s.y * dt
                isPushing = true
                pushPhase += dt * 7
            }
            if s.y < -0.5 && speed > 0 { speed = max(0, speed - 7 * dt) }
        }
        speed += -gravity * fs.y * dt
        speed -= speed * (manualActive ? 0.04 : 0.08) * dt
        if speed < -0.4 {           // rolled back down a ramp: switch to fakie
            heading += .pi
            speed = -speed
            fs = surfaceForward(groundNormal)
        }

        if manualActive {
            manualTime += dt
            updateBalance(dt, control: s.y, difficulty: 2.0 + manualTime * 0.3)
            if abs(balance) >= 1 { bail("MANUAL BAIL"); return }
            if speed < 0.6 { endManual(); bankCombo() }
        }

        // Wall check at knee height
        let step = fs * speed * dt
        let h2 = SIMD2<Float>(step.x, step.z)
        let hl = simd_length(h2)
        if hl > 1e-5 {
            let d = h2 / hl
            let from = pos + SIMD3(0, 0.45, 0)
            if let w = ray(from, from + SIMD3(d.x, 0, d.y) * (hl + 0.35)), w.normal.y < 0.3 {
                if abs(speed) > 8.5 { bail("SLAMMED!"); return }
                bounce(w.normal)
                return
            }
        }

        var np = pos + SIMD3(step.x, 0, step.z)
        clampBounds(&np)
        guard let g = ground(np.x, np.z, top: pos.y + 0.6, bottom: pos.y - 3) else {
            takeoff(vy: lastVy)
            return
        }
        if g.point.y - pos.y > 0.4 { bounce(-SIMD3(sin(heading), 0, cos(heading))); return }

        let nfs = surfaceForward(g.normal)
        let newVy = speed * nfs.y
        let drop = pos.y - g.point.y
        // Launch when the ground falls away (kicker lip) or curves under us (quarter-pipe coping)
        if drop > 0.3 || (lastVy > 2.2 && lastVy - newVy > 2.6) {
            takeoff(vy: lastVy)
            return
        }
        pos = SIMD3(np.x, g.point.y, np.z)
        groundNormal = g.normal
        lastVy = newVy

        if input.ollieHeld { ollieCharge = min(ollieCharge + dt, 0.5) }
        if ollieReleased { ollie() }
    }

    private func bounce(_ n: SIMD3<Float>) {
        let n2 = SIMD2<Float>(n.x, n.z)
        guard simd_length(n2) > 1e-4 else { speed *= 0.3; return }
        let nn = simd_normalize(n2)
        let f = SIMD2<Float>(sin(heading), cos(heading))
        let r = f - 2 * simd_dot(f, nn) * nn
        heading = atan2(r.x, r.y)
        speed *= 0.4
        lightHaptic.impactOccurred()
    }

    private func ollie() {
        let vy = max(lastVy, 0) + ollieImpulse + ollieCharge * 2.4
        ollieCharge = 0
        takeoff(vy: vy)
        lightHaptic.impactOccurred(intensity: 0.6)
    }

    private func takeoff(vy: Float) {
        let fs = surfaceForward(groundNormal)
        let fwd = SIMD3<Float>(sin(heading), 0, cos(heading))
        let hs = speed * simd_length(SIMD2<Float>(fs.x, fs.z))
        vel = SIMD3(fwd.x * hs, vy, fwd.z * hs)
        if groundNormal.y < 0.72 {
            // Vert assist: launch straight up so you come back down into the transition
            let nh = simd_normalize(SIMD2<Float>(groundNormal.x, groundNormal.z))
            var hv = SIMD2<Float>(vel.x, vel.z)
            hv -= nh * simd_dot(hv, nh)
            hv += nh * 0.6
            vel.x = hv.x; vel.z = hv.y
            vel.y = max(vel.y, speed * 0.95)
        }
        if manualActive { endManual() } else if landGrace > 0 { bankCombo() }
        enterAir()
    }

    private func enterAir() {
        mode = .air
        airTime = 0
        spinAccum = 0
        spinVel = 0
        airTricks = 0
        flipKind = nil
        grabKind = nil
        landGrace = 0
    }

    // MARK: - Air

    private func simulateAir(_ dt: Float) {
        airTime += dt
        vel.y -= gravity * dt
        let s = input.stick

        spinVel += (-s.x * spinRate - spinVel) * min(1, 10 * dt)
        heading += spinVel * dt
        spinAccum += spinVel * dt

        if input.consumeFlip(), flipKind == nil {
            if let g = grabKind { finishGrab(g) }
            flipKind = FlipKind.from(s)
            flipT = 0
        }
        if let f = flipKind {
            flipT += dt / f.duration
            if flipT >= 1 {
                combo.add(f.name, f.points)
                airTricks += 1
                flipKind = nil
            }
        }

        if input.grabHeld && flipKind == nil {
            if grabKind == nil { grabKind = GrabKind.from(s); lastGrab = grabKind!; grabTime = 0 }
            grabTime += dt
        } else if let g = grabKind {
            finishGrab(g)
        }

        if railCooldown > 0 { railCooldown -= dt }
        if input.grindBuffered && vel.y < 3 && tryStartGrind() { return }

        // Bump off walls
        let h2 = SIMD2<Float>(vel.x, vel.z)
        let hl = simd_length(h2)
        if hl > 0.05 {
            let d = h2 / hl
            let from = pos + SIMD3(0, 0.5, 0)
            if let w = ray(from, from + SIMD3(d.x, 0, d.y) * (hl * dt + 0.3)), w.normal.y < 0.3 {
                let n2 = simd_normalize(SIMD2<Float>(w.normal.x, w.normal.z))
                let r = h2 - 2 * simd_dot(h2, n2) * n2
                vel.x = r.x * 0.35
                vel.z = r.y * 0.35
            }
        }

        var np = pos + vel * dt
        clampBounds(&np)
        if vel.y <= 0, let g = ground(np.x, np.z, top: pos.y + 0.25, bottom: np.y - 0.6), np.y <= g.point.y {
            pos = SIMD3(np.x, g.point.y, np.z)
            land(g)
            return
        }
        pos = np
        if pos.y < -15 { respawn() }
    }

    private func finishGrab(_ g: GrabKind) {
        if grabTime > 0.12 {
            combo.add(g.name, g.points)
            combo.addBonus(Int(grabTime * 250))
            airTricks += 1
        }
        grabKind = nil
        grabTime = 0
    }

    private func land(_ g: Hit) {
        if flipKind != nil { bail("BOARD NOT UNDER FEET"); return }
        if let gr = grabKind { finishGrab(gr) }

        let n = g.normal
        let vp = vel - n * simd_dot(vel, n)
        let h2 = SIMD2<Float>(vp.x, vp.z)
        var travelYaw = heading
        if simd_length(h2) > 0.4 { travelYaw = atan2(h2.x, h2.y) }
        let diff = abs(wrapAngle(heading - travelYaw))
        if diff > 0.8 && diff < .pi - 0.8 { bail("LANDED SIDEWAYS"); return }

        let halfTurns = Int((abs(spinAccum) + 0.6) / .pi)
        if halfTurns >= 1 {
            let deg = halfTurns * 180
            let table = [0, 100, 250, 500, 900, 1400, 2000]
            combo.add("\(spinAccum > 0 ? "BS" : "FS") \(deg)", table[min(halfTurns, table.count - 1)])
            if deg >= 540 { model?.completeGoal(.spin540) }
        } else if airTricks == 0 && airTime > 1.1 {
            combo.add("Big Air", 150)
        }

        heading = travelYaw
        speed = simd_length(vp)
        groundNormal = n
        lastVy = speed * surfaceForward(n).y
        mode = .ground
        landSquash = min(1, abs(vel.y) / 10)
        vel = SIMD3(0, 0, 0)
        if input.manualBuffered && combo.active {
            startManual()
        } else if combo.active {
            landGrace = 0.35
        }
        lightHaptic.impactOccurred(intensity: 0.9)
    }

    // MARK: - Manual

    private func startManual() {
        input.consumeManual()
        manualActive = true
        manualTime = 0
        balance = Float.random(in: -0.1...0.1)
        balanceVel = 0
        balanceDrift = 0
        landGrace = 0
        combo.add("Manual", 100)
    }

    private func endManual() {
        guard manualActive else { return }
        manualActive = false
        combo.addBonus(Int(manualTime * 150))
    }

    private func updateBalance(_ dt: Float, control: Float, difficulty: Float) {
        balanceDrift = max(-1, min(1, balanceDrift + Float.random(in: -1...1) * dt * 3))
        balanceVel += (balance * difficulty + balanceDrift * 0.6) * dt
        balanceVel -= control * 3.4 * dt
        balanceVel *= (1 - 1.2 * dt)
        balance += balanceVel * dt
    }

    // MARK: - Grind

    private func tryStartGrind() -> Bool {
        var best: (index: Int, t: Float, dist: Float)?
        let v2 = SIMD2<Float>(vel.x, vel.z)
        let vl = simd_length(v2)
        guard vl > 1.2 else { return false }
        for (i, r) in world.rails.enumerated() {
            if i == lastRailIndex && railCooldown > 0 { continue }
            let ab = r.b - r.a
            let ab2 = SIMD2<Float>(ab.x, ab.z)
            let l2 = simd_length_squared(ab2)
            guard l2 > 1e-4 else { continue }
            let ap2 = SIMD2<Float>(pos.x - r.a.x, pos.z - r.a.z)
            let t = max(0, min(1, simd_dot(ap2, ab2) / l2))
            guard t > 0.02 && t < 0.98 else { continue }
            let c = r.a + ab * t
            let dxz = simd_length(SIMD2<Float>(pos.x - c.x, pos.z - c.z))
            let dy = pos.y - c.y
            guard dxz < 0.6, dy > -0.45, dy < 0.9 else { continue }
            let align = simd_dot(v2 / vl, simd_normalize(ab2))
            guard abs(align) > 0.4 else { continue }
            if best == nil || dxz < best!.dist { best = (i, t, dxz) }
        }
        guard let b = best else { return false }
        if flipKind != nil { bail("CAUGHT THE RAIL MID-FLIP"); return true }
        if let g = grabKind { finishGrab(g) }

        let r = world.rails[b.index]
        let dir = simd_normalize(r.b - r.a)
        let along = simd_dot(vel, dir)
        railDir = along >= 0 ? 1 : -1
        grindSpeed = max(3.5, abs(along) + 0.5)
        railIndex = b.index
        railT = b.t
        grindKind = GrindKind.from(input.stick)
        combo.add(grindKind.name(on: r.kind), grindKind.points)
        mode = .grind
        grindTime = 0
        balance = Float.random(in: -0.15...0.15)
        balanceVel = 0
        balanceDrift = 0
        input.consumeGrind()
        let ed = dir * railDir
        heading = atan2(ed.x, ed.z)
        rigidHaptic.impactOccurred()
        return true
    }

    private func simulateGrind(_ dt: Float, ollieReleased: Bool) {
        guard railIndex >= 0 && railIndex < world.rails.count else { enterAir(); return }
        let r = world.rails[railIndex]
        let ab = r.b - r.a
        let len = simd_length(ab)
        let dir = ab / len
        let exitDir = dir * railDir

        grindSpeed += -gravity * exitDir.y * dt * 0.8
        grindSpeed -= 0.25 * dt
        grindTime += dt
        updateBalance(dt, control: input.stick.x, difficulty: 2.2 + grindTime * 0.35)
        if abs(balance) >= 1 { endGrind(); bail("LOST BALANCE"); return }

        railT += railDir * grindSpeed * dt / len
        let lift: Float = grindKind == .boardslide ? 0.07 : 0.03
        if railT <= 0 || railT >= 1 || grindSpeed < 0.6 {
            railT = max(0, min(1, railT))
            pos = r.a + ab * railT + SIMD3(0, lift, 0)
            endGrind()
            vel = exitDir * max(grindSpeed, 1) + SIMD3(0, 1.8, 0)
            enterAir()
            return
        }
        pos = r.a + ab * railT + SIMD3(0, lift, 0)
        heading = atan2(exitDir.x, exitDir.z)

        if ollieReleased {
            endGrind()
            vel = exitDir * grindSpeed + SIMD3(0, ollieImpulse * 0.9, 0)
            enterAir()
            lightHaptic.impactOccurred()
        }
    }

    private func endGrind() {
        combo.addBonus(Int(grindTime * 160))
        if grindTime >= 4 { model?.completeGoal(.grind) }
        lastRailIndex = railIndex
        railCooldown = 0.3
        railIndex = -1
    }

    // MARK: - Bail / respawn

    private func bail(_ msg: String) {
        guard mode != .bail else { return }
        let h: SIMD2<Float> = mode == .air ? SIMD2(vel.x, vel.z) : SIMD2(sin(heading), cos(heading)) * speed
        bailSlide = SIMD3(h.x, 0, h.y) * 0.5
        mode = .bail
        bailTimer = 1.7
        bailProgress = 0
        combo.reset()
        landGrace = 0
        manualActive = false
        flipKind = nil
        grabKind = nil
        railIndex = -1
        speed = 0
        model?.flash(msg)
        heavyHaptic.impactOccurred()
    }

    private func simulateBail(_ dt: Float) {
        bailTimer -= dt
        bailProgress = min(1, bailProgress + dt * 3)
        bailSlide *= (1 - 2.5 * dt)
        var np = pos + bailSlide * dt
        clampBounds(&np)
        if let g = ground(np.x, np.z, top: pos.y + 0.5, bottom: pos.y - 40) {
            np.y = np.y > g.point.y ? max(g.point.y, np.y - 9 * dt) : g.point.y
            groundNormal = g.normal
        }
        pos = np
        if bailTimer <= 0 {
            mode = .ground
            bailProgress = 0
            speed = 0
            lastVy = 0
        }
    }

    private func respawn() {
        pos = world.spawn
        heading = 0
        speed = 0
        vel = SIMD3(0, 0, 0)
        mode = .ground
        groundNormal = SIMD3(0, 1, 0)
        combo.reset()
    }

    // MARK: - Scoring

    private func bankCombo() {
        guard combo.active, let model else { combo.reset(); return }
        let pts = combo.total
        model.score += pts
        if combo.multiplier >= 5 { model.completeGoal(.combo5) }
        if pts >= 5000 { model.completeGoal(.bigCombo) }
        if model.score >= 15000 { model.completeGoal(.score) }
        if pts >= 2500 { model.flash(pts >= 10000 ? "SICK!!! +\(pts)" : pts >= 5000 ? "INSANE! +\(pts)" : "NICE! +\(pts)") }
        combo.reset()
        landGrace = 0
    }

    // MARK: - City life (traffic, pedestrians, letters)

    private func updateCity(_ dt: Float) {
        for c in world.cars {
            c.update(dt)
            if mode != .bail && pos.y < 1.6 && simd_distance(SIMD2(c.position.x, c.position.z), SIMD2(pos.x, pos.z)) < 2.1 {
                bail("WATCH THE TRAFFIC!")
            }
        }
        for w in world.walkers { w.update(dt) }

        guard let model else { return }
        for (i, node) in world.letterNodes.enumerated() where !model.letters[i] {
            node.simdEulerAngles.y += dt * 2
            if simd_distance(node.simdPosition, pos + SIMD3(0, 0.9, 0)) < 1.4 {
                model.letters[i] = true
                node.isHidden = true
                model.flash(["S", "K", "A", "T", "E"][i] + "!")
                rigidHaptic.impactOccurred()
                if model.letters.allSatisfy({ $0 }) { model.completeGoal(.skate) }
            }
        }
    }

    // MARK: - Visuals

    private func visuals(_ dt: Float) {
        let k: (Float) -> Float = { rate in 1 - exp(-rate * dt) }
        let up = SIMD3<Float>(0, 1, 0)

        var crouch: Float = 0.1, lift: Float = 0, tuck: Float = 0, reach: Float = 0
        var armsOut: Float = 0, lean: Float = 0, pitch: Float = 0, yawOff: Float = 0

        switch mode {
        case .ground:
            crouch = input.ollieHeld ? 0.85 : (isPushing ? 0.25 : 0.12)
            crouch = min(1, crouch + landSquash * 0.8)
            if manualActive { pitch = -0.22; lean = -0.6; armsOut = 0.55 + abs(balance) * 0.4; crouch = 0.25 }
        case .air:
            crouch = 0.45; lift = 0.16
            if flipKind != nil { tuck = 0.24 }
            if grabKind != nil { crouch = 1; reach = 1; lift = 0.3 }
            armsOut = 0.3
        case .grind:
            crouch = input.ollieHeld ? 0.7 : 0.35
            armsOut = 0.7 + abs(balance) * 0.3
            switch grindKind {
            case .fiveO: pitch = -0.2
            case .noseGrind: pitch = 0.2
            case .boardslide: yawOff = .pi / 2
            case .fiftyFifty: break
            }
        case .bail:
            crouch = 0.3
        }
        landSquash *= exp(-6 * dt)

        pose.crouch = lerp(pose.crouch, crouch, k(14))
        pose.lift = lerp(pose.lift, lift, k(14))
        pose.feetTuck = lerp(pose.feetTuck, tuck, k(20))
        pose.grabReach = lerp(pose.grabReach, reach, k(14))
        pose.armsOut = lerp(pose.armsOut, armsOut, k(8))
        pose.lean = lerp(pose.lean, lean, k(10))
        pose.grab = grabKind ?? (pose.grabReach > 0.02 ? lastGrab : nil)
        pose.pushPhase = (mode == .ground && isPushing) ? pushPhase : nil
        pose.bail = mode == .bail ? bailProgress : lerp(pose.bail, 0, k(10))
        pose.boardOffset = mode == .bail ? SIMD3(0, 0, bailProgress * 1.2) : SIMD3(0, 0, 0)
        boardPitch = lerp(boardPitch, pitch, k(12))
        yawOffset = lerpAngle(yawOffset, yawOff, k(14))

        var boardQ = simd_quatf(angle: boardPitch, axis: SIMD3(1, 0, 0))
        if let f = flipKind {
            let t = min(1, flipT)
            boardQ = f.rotation(at: 1 - (1 - t) * (1 - t)) * boardQ
        }
        if grabKind == .method { boardQ = simd_quatf(angle: 0.4 * pose.grabReach, axis: SIMD3(0, 0, 1)) * boardQ }
        if mode == .bail { boardQ = simd_quatf(angle: bailProgress * 2.5, axis: SIMD3(0, 0, 1)) * boardQ }
        pose.boardRotation = boardQ

        visualYaw = (mode == .ground) ? lerpAngle(visualYaw, heading, k(18)) : heading
        let targetN = mode == .ground ? groundNormal : up
        smoothNormal = simd_normalize(lerp3(smoothNormal, targetN, k(mode == .ground ? 16 : 4)))
        let carve: Float = mode == .ground && !manualActive ? input.stick.x * 0.18 * min(1, speed / 5) : 0
        let roll: Float = mode == .grind ? balance * 0.35 : (manualActive ? balance * 0.15 : 0)

        rig.root.simdPosition = pos
        rig.root.simdOrientation = quatFromTo(up, smoothNormal) *
            simd_quatf(angle: visualYaw + yawOffset, axis: up) *
            simd_quatf(angle: carve + roll, axis: SIMD3(0, 0, 1))
        rig.apply(pose)

        updateCamera(dt)
    }

    private func updateCamera(_ dt: Float) {
        var targetYaw = camYaw
        switch mode {
        case .ground: if speed > 0.3 { targetYaw = heading }
        case .grind: targetYaw = heading
        case .air:
            let h = SIMD2<Float>(vel.x, vel.z)
            if simd_length(h) > 1.5 { targetYaw = atan2(h.x, h.y) }
        case .bail: break
        }
        camYaw = lerpAngle(camYaw, targetYaw, 1 - exp(-3.2 * dt))
        let back = SIMD3<Float>(sin(camYaw), 0, cos(camYaw))
        let focus = pos + SIMD3<Float>(0, 1.0, 0)
        var desired = pos - back * 4.6 + SIMD3<Float>(0, 2.0, 0)
        if let h = ray(focus, desired) {
            desired = h.point + simd_normalize(focus - h.point) * 0.35
        }
        let rate: Float = mode == .air ? 5 : 9
        camPos += (desired - camPos) * (1 - exp(-rate * dt))
        cameraNode.simdPosition = camPos
        cameraNode.simdLook(at: focus)
        let v = mode == .air ? simd_length(vel) : speed
        let fov = 62 + min(v, 14) * 0.9
        if let cam = cameraNode.camera {
            cam.fieldOfView = CGFloat(lerp(Float(cam.fieldOfView), fov, 1 - exp(-4 * dt)))
        }
    }

    // MARK: - HUD

    private func publishHUD(_ dt: Float) {
        guard let model else { return }
        let text = combo.text
        if model.comboText != text { model.comboText = text }
        if model.comboValue != combo.base { model.comboValue = combo.base }
        if model.comboMultiplier != combo.multiplier { model.comboMultiplier = combo.multiplier }

        let showBalance = mode == .grind || manualActive
        if showBalance {
            let b = Double(max(-1, min(1, balance)))
            if model.balance == nil || abs((model.balance ?? 0) - b) > 0.02 { model.balance = b }
        } else if model.balance != nil {
            model.balance = nil
        }

        hudTimer += dt
        if hudTimer > 0.1 {
            hudTimer = 0
            if timed {
                let t = max(0, Int(ceil(timeLeft)))
                if model.timeLeft != t { model.timeLeft = t }
            }
            let v = mode == .air ? simd_length(SIMD2<Float>(vel.x, vel.z)) : (mode == .grind ? grindSpeed : speed)
            let kmh = Int(v * 3.6)
            if model.speedKmh != kmh { model.speedKmh = kmh }
        }
    }
}
