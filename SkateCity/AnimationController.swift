// Copyright © 2026 MAR / SkateCity. All rights reserved.
// Unauthorized reproduction, distribution, or modification is strictly prohibited.

#if os(iOS)
import SceneKit
import UIKit

// MARK: - Avatar state

enum AvatarState: Equatable {
    case idle
    case push
    case cruise
    case ollie
    case kickflip
    case heelflip
    case popShuvit
    case manual
    case grind
    case bail
    case walk
    case recover
}

// MARK: - AnimationController

/// Drives AvatarModel pose via per-bone CAAnimation.
/// Uses a two-layer blending approach: base pose + action layer.
final class AnimationController {

    // MARK: State

    private(set) var state: AvatarState = .idle
    private var blendTimer: Float = 0
    private var blendDuration: Float = 0.18

    // Idle oscillation
    private var idlePhase: Float = 0

    // Lean values (written by GameViewController each frame)
    var leanInput:  Float = 0   // -1…1 lateral lean
    var forwardBob: Float = 0   // 0…1 speed bob

    // IK target Y offset (board surface height, updated by physics)
    var boardSurfaceY: Float = 0.095

    // MARK: Bone references

    private weak var avatar: AvatarModel?

    // MARK: Init

    init(avatar: AvatarModel) {
        self.avatar = avatar
        startIdleAnimation()
    }

    // MARK: Transition

    func transition(to newState: AvatarState, blend: Float = 0.18) {
        guard newState != state else { return }
        state = newState
        blendDuration = blend
        blendTimer    = 0

        stopAllActions()
        switch newState {
        case .idle:       startIdleAnimation()
        case .push:       startPushAnimation()
        case .cruise:     startCruiseAnimation()
        case .ollie:      startOllieAnimation()
        case .kickflip:   startKickflipAnimation()
        case .heelflip:   startHeelflipAnimation()
        case .popShuvit:  startPopShuvitAnimation()
        case .manual:     startManualAnimation()
        case .grind:      startGrindAnimation()
        case .bail:       startBailAnimation()
        case .walk:       startWalkAnimation()
        case .recover:    startRecoverAnimation()
        }
    }

    // MARK: Per-frame update

    func update(deltaTime: Float) {
        guard let av = avatar else { return }
        blendTimer += deltaTime
        idlePhase  += deltaTime

        // Lateral lean from stick input
        let targetLean = leanInput * 0.18
        av.spineNode.eulerAngles.z = lerp(av.spineNode.eulerAngles.z, targetLean, 0.12)

        // Speed-based forward lean
        let fwdLean = -forwardBob * 0.10
        av.spineNode.eulerAngles.x = lerp(av.spineNode.eulerAngles.x, fwdLean, 0.08)

        // IK: keep foot bottoms at board surface
        updateLegIK(av: av, deltaTime: deltaTime)

        // State-specific per-frame
        switch state {
        case .idle: updateIdle(av: av)
        case .grind: updateGrindBalance(av: av)
        case .manual: updateManualBalance(av: av)
        default: break
        }
    }

    // MARK: - Idle

    private func startIdleAnimation() {
        guard let av = avatar else { return }

        // Subtle torso sway (breathing + balance micro-corrections)
        animate(node: av.chestNode, keyPath: "eulerAngles.z",
                values: [0, 0.025, 0, -0.025, 0], duration: 3.2, reps: .greatestFiniteMagnitude)
        animate(node: av.hipsNode, keyPath: "eulerAngles.z",
                values: [0, -0.018, 0, 0.018, 0], duration: 3.8, reps: .greatestFiniteMagnitude)

        // Subtle breathing chest rise
        animate(node: av.chestNode, keyPath: "scale.y",
                values: [1.0, 1.006, 1.0], duration: 2.8, reps: .greatestFiniteMagnitude)

        // Arms hang with gentle sway
        animate(node: av.shoulderLNode, keyPath: "eulerAngles.z",
                values: [0.12, 0.16, 0.12, 0.08, 0.12], duration: 3.2, reps: .greatestFiniteMagnitude)
        animate(node: av.shoulderRNode, keyPath: "eulerAngles.z",
                values: [-0.12, -0.08, -0.12, -0.16, -0.12], duration: 3.2, reps: .greatestFiniteMagnitude)
    }

    private func updateIdle(av: AvatarModel) {
        // Slight knee bend for natural stance
        let kneeTarget: Float = 0.12
        av.shinLNode.eulerAngles.x = lerp(av.shinLNode.eulerAngles.x, -kneeTarget, 0.06)
        av.shinRNode.eulerAngles.x = lerp(av.shinRNode.eulerAngles.x, -kneeTarget, 0.06)
    }

    // MARK: - Push

    private func startPushAnimation() {
        guard let av = avatar else { return }
        let dur = 0.55

        // Back leg kick
        let kickGroup = CAAnimationGroup()
        kickGroup.duration  = dur
        kickGroup.fillMode  = .backwards
        kickGroup.isRemovedOnCompletion = false

        let thighKick = keyframeAnim(keyPath: "eulerAngles.x",
                                     values: [0, 0.25, 0.65, 0.30, 0],
                                     times: [0, 0.18, 0.45, 0.72, 1.0],
                                     duration: dur)
        av.thighRNode.addAnimation(thighKick, forKey: "push_thigh")

        let shinKick = keyframeAnim(keyPath: "eulerAngles.x",
                                    values: [0, -0.10, -0.35, -0.22, 0],
                                    times: [0, 0.18, 0.50, 0.72, 1.0],
                                    duration: dur)
        av.shinRNode.addAnimation(shinKick, forKey: "push_shin")

        // Body dip
        let hipDip = keyframeAnim(keyPath: "position.y",
                                   values: [0.900, 0.840, 0.880, 0.900],
                                   times: [0, 0.28, 0.65, 1.0],
                                   duration: dur)
        av.hipsNode.addAnimation(hipDip, forKey: "push_hips")

        // Left arm swing forward (balance)
        animate(node: av.shoulderLNode, keyPath: "eulerAngles.x",
                values: [0, -0.25, -0.10, 0], duration: dur)
        animate(node: av.shoulderRNode, keyPath: "eulerAngles.x",
                values: [0, 0.30, 0.12, 0], duration: dur)

        // Return to cruise after push completes
        DispatchQueue.main.asyncAfter(deadline: .now() + dur + 0.08) { [weak self] in
            if self?.state == .push { self?.transition(to: .cruise) }
        }
    }

    // MARK: - Cruise

    private func startCruiseAnimation() {
        guard let av = avatar else { return }

        // Slight forward lean
        animate(node: av.chestNode, keyPath: "eulerAngles.x",
                values: [av.chestNode.eulerAngles.x, -0.08], duration: 0.30)

        // Front foot angled on board
        animate(node: av.thighLNode, keyPath: "eulerAngles.y",
                values: [0, 0.12], duration: 0.35)

        // Arms slightly raised for balance
        animate(node: av.shoulderLNode, keyPath: "eulerAngles.x",
                values: [0, -0.14], duration: 0.35)
        animate(node: av.shoulderRNode, keyPath: "eulerAngles.x",
                values: [0, -0.10], duration: 0.35)
    }

    // MARK: - Ollie

    private func startOllieAnimation() {
        guard let av = avatar else { return }
        let dur = 0.50

        // Phase 1: Crouch
        let hipsY: Float = 0.900
        animate(node: av.hipsNode, keyPath: "position.y",
                values: [hipsY, hipsY - 0.12, hipsY + 0.10, hipsY + 0.14, hipsY],
                times: [0, 0.20, 0.45, 0.65, 1.0], duration: dur)

        // Knee crouch then tuck
        animate(node: av.shinLNode, keyPath: "eulerAngles.x",
                values: [0, -0.55, -0.35, -0.15, 0],
                times: [0, 0.22, 0.48, 0.72, 1.0], duration: dur)
        animate(node: av.shinRNode, keyPath: "eulerAngles.x",
                values: [0, -0.50, -0.40, -0.20, 0],
                times: [0, 0.22, 0.48, 0.72, 1.0], duration: dur)

        // Arms raise for momentum
        animate(node: av.shoulderLNode, keyPath: "eulerAngles.x",
                values: [0, -0.30, -0.55, -0.20, 0],
                times: [0, 0.25, 0.50, 0.75, 1.0], duration: dur)
        animate(node: av.shoulderRNode, keyPath: "eulerAngles.x",
                values: [0, -0.25, -0.50, -0.18, 0],
                times: [0, 0.25, 0.50, 0.75, 1.0], duration: dur)

        // Body tuck
        animate(node: av.chestNode, keyPath: "eulerAngles.x",
                values: [0, -0.10, -0.25, -0.12, 0],
                times: [0, 0.20, 0.48, 0.72, 1.0], duration: dur)
    }

    // MARK: - Kickflip

    private func startKickflipAnimation() {
        guard let av = avatar else { return }
        let dur = 0.55

        // Ollie base
        startOllieAnimation()

        // Left foot flick outward (front foot kicks heelside to flip board)
        animate(node: av.thighLNode, keyPath: "eulerAngles.x",
                values: [0, -0.10, 0.45, 0.15, 0],
                times: [0, 0.22, 0.40, 0.65, 1.0], duration: dur)
        animate(node: av.shinLNode, keyPath: "eulerAngles.z",
                values: [0, -0.20, 0.55, 0.10, 0],
                times: [0, 0.20, 0.38, 0.65, 1.0], duration: dur)

        // Right foot tuck high (catches board on landing)
        animate(node: av.thighRNode, keyPath: "eulerAngles.x",
                values: [0, 0.18, 0.45, 0.18, 0],
                times: [0, 0.22, 0.45, 0.72, 1.0], duration: dur)
    }

    // MARK: - Heelflip

    private func startHeelflipAnimation() {
        guard let av = avatar else { return }
        let dur = 0.55
        startOllieAnimation()
        // Front foot flick the other way (toeside)
        animate(node: av.shinLNode, keyPath: "eulerAngles.z",
                values: [0, 0.15, -0.50, -0.10, 0],
                times: [0, 0.20, 0.38, 0.65, 1.0], duration: dur)
    }

    // MARK: - Pop Shove-It

    private func startPopShuvitAnimation() {
        guard let av = avatar else { return }
        let dur = 0.55
        startOllieAnimation()
        // Body counter-rotates slightly (board spins 180° under feet)
        animate(node: av.hipsNode, keyPath: "eulerAngles.y",
                values: [0, -0.12, -0.25, -0.12, 0],
                times: [0, 0.22, 0.45, 0.72, 1.0], duration: dur)
        animate(node: av.spineNode, keyPath: "eulerAngles.y",
                values: [0, 0.08, 0.18, 0.08, 0],
                times: [0, 0.22, 0.45, 0.72, 1.0], duration: dur)
    }

    // MARK: - Manual

    private func startManualAnimation() {
        guard let av = avatar else { return }

        animate(node: av.hipsNode, keyPath: "eulerAngles.x",
                values: [0, 0.28], duration: 0.32)
        animate(node: av.chestNode, keyPath: "eulerAngles.x",
                values: [0, -0.20], duration: 0.32)
        animate(node: av.shoulderLNode, keyPath: "eulerAngles.x",
                values: [0, -0.35], duration: 0.32)
        animate(node: av.shoulderRNode, keyPath: "eulerAngles.x",
                values: [0, -0.35], duration: 0.32)
    }

    private func updateManualBalance(av: AvatarModel) {
        // Tiny oscillation on arms to simulate balance micro-corrections
        let wave = sin(idlePhase * 4.5) * 0.04
        av.shoulderLNode.eulerAngles.z =  0.12 + wave
        av.shoulderRNode.eulerAngles.z = -0.12 - wave
    }

    // MARK: - Grind

    private func startGrindAnimation() {
        guard let av = avatar else { return }
        animate(node: av.chestNode, keyPath: "eulerAngles.x",
                values: [0, -0.16], duration: 0.25)
        animate(node: av.hipsNode, keyPath: "eulerAngles.x",
                values: [0, 0.12], duration: 0.25)
        // Arms wide for balance
        animate(node: av.shoulderLNode, keyPath: "eulerAngles.x",
                values: [0, -0.40], duration: 0.25)
        animate(node: av.elbowLNode, keyPath: "eulerAngles.x",
                values: [0, -0.22], duration: 0.25)
        animate(node: av.shoulderRNode, keyPath: "eulerAngles.x",
                values: [0, -0.38], duration: 0.25)
        animate(node: av.elbowRNode, keyPath: "eulerAngles.x",
                values: [0, -0.22], duration: 0.25)
    }

    private func updateGrindBalance(av: AvatarModel) {
        let wave = sin(idlePhase * 3.8) * 0.022
        av.chestNode.eulerAngles.z = leanInput * 0.12 + wave
    }

    // MARK: - Bail

    private func startBailAnimation() {
        guard let av = avatar else { return }
        let dur = 0.28

        // Ragdoll-style: hips forward, arms out
        animate(node: av.chestNode, keyPath: "eulerAngles.x",
                values: [0, -0.55, -0.80], times: [0, 0.35, 1.0], duration: dur)
        animate(node: av.hipsNode, keyPath: "eulerAngles.x",
                values: [0, 0.35, 0.65], times: [0, 0.35, 1.0], duration: dur)

        animate(node: av.shoulderLNode, keyPath: "eulerAngles.x",
                values: [0, -0.80, -1.20], times: [0, 0.35, 1.0], duration: dur)
        animate(node: av.shoulderRNode, keyPath: "eulerAngles.x",
                values: [0, -0.80, -1.20], times: [0, 0.35, 1.0], duration: dur)
        animate(node: av.elbowLNode, keyPath: "eulerAngles.x",
                values: [0, 0.60, 1.10], times: [0, 0.35, 1.0], duration: dur)
        animate(node: av.elbowRNode, keyPath: "eulerAngles.x",
                values: [0, 0.60, 1.10], times: [0, 0.35, 1.0], duration: dur)

        // Twist
        animate(node: av.hipsNode, keyPath: "eulerAngles.z",
                values: [0, 0.35, 0.70], times: [0, 0.40, 1.0], duration: dur)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.20) { [weak self] in
            if self?.state == .bail { self?.transition(to: .recover, blend: 0.40) }
        }
    }

    // MARK: - Walk (carrying board)

    private func startWalkAnimation() {
        guard let av = avatar else { return }
        let dur = 0.62

        animate(node: av.thighLNode, keyPath: "eulerAngles.x",
                values: [0, 0.28, 0, -0.28, 0], duration: dur, reps: .greatestFiniteMagnitude)
        animate(node: av.thighRNode, keyPath: "eulerAngles.x",
                values: [0, -0.28, 0, 0.28, 0], duration: dur, reps: .greatestFiniteMagnitude)
        animate(node: av.shinLNode, keyPath: "eulerAngles.x",
                values: [0, -0.18, 0, -0.06, 0], duration: dur, reps: .greatestFiniteMagnitude)
        animate(node: av.shinRNode, keyPath: "eulerAngles.x",
                values: [0, -0.06, 0, -0.18, 0], duration: dur, reps: .greatestFiniteMagnitude)

        // Arm swing (opposite to legs)
        animate(node: av.shoulderLNode, keyPath: "eulerAngles.x",
                values: [0, -0.20, 0, 0.20, 0], duration: dur, reps: .greatestFiniteMagnitude)
        animate(node: av.shoulderRNode, keyPath: "eulerAngles.x",
                values: [0, 0.20, 0, -0.20, 0], duration: dur, reps: .greatestFiniteMagnitude)
    }

    // MARK: - Recover

    private func startRecoverAnimation() {
        guard let av = avatar else { return }
        // Return all bones toward neutral
        let keys = ["eulerAngles.x", "eulerAngles.y", "eulerAngles.z"]
        let nodes = [av.chestNode, av.hipsNode, av.spineNode,
                     av.shoulderLNode, av.shoulderRNode,
                     av.elbowLNode, av.elbowRNode,
                     av.thighLNode, av.thighRNode,
                     av.shinLNode, av.shinRNode]
        for node in nodes {
            for key in keys {
                animate(node: node, keyPath: key, values: [0.0], duration: 0.55)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.80) { [weak self] in
            if self?.state == .recover { self?.transition(to: .idle) }
        }
    }

    // MARK: - Analytical leg IK

    private func updateLegIK(av: AvatarModel, deltaTime: Float) {
        // Keep shins pointing toward board surface — simple two-bone IK
        let targetY = boardSurfaceY
        let kneeBend: Float = 0.18 + max(0, (0.900 - targetY - 0.440) / 0.400) * 0.6
        let smoothSpeed: Float = state == .ollie ? 0.25 : 0.08

        av.shinLNode.eulerAngles.x = lerp(av.shinLNode.eulerAngles.x, -kneeBend, smoothSpeed)
        av.shinRNode.eulerAngles.x = lerp(av.shinRNode.eulerAngles.x, -kneeBend, smoothSpeed)

        // Tilt feet flat to board
        av.footLNode.eulerAngles.x = lerp(av.footLNode.eulerAngles.x, kneeBend * 0.65, smoothSpeed)
        av.footRNode.eulerAngles.x = lerp(av.footRNode.eulerAngles.x, kneeBend * 0.65, smoothSpeed)
    }

    // MARK: - Stop all actions

    private func stopAllActions() {
        guard let av = avatar else { return }
        let nodes = [av.rootNode, av.hipsNode, av.spineNode, av.chestNode, av.neckNode, av.headNode,
                     av.thighLNode, av.thighRNode, av.shinLNode, av.shinRNode, av.footLNode, av.footRNode,
                     av.shoulderLNode, av.shoulderRNode, av.elbowLNode, av.elbowRNode, av.wristLNode, av.wristRNode]
        for n in nodes { n.removeAllActions(); n.removeAllAnimations() }
    }

    // MARK: - Animation helpers

    private func animate(node: SCNNode, keyPath: String, values: [Float],
                         times: [Double]? = nil, duration: Double,
                         reps: Float = 0) {
        let anim = CAKeyframeAnimation(keyPath: keyPath)
        anim.values        = values.map { NSNumber(value: $0) }
        if let t = times { anim.keyTimes = t.map { NSNumber(value: $0) } }
        anim.duration      = duration
        anim.repeatCount   = reps
        anim.calculationMode  = .linear
        anim.isRemovedOnCompletion = reps == 0
        anim.fillMode      = reps == 0 ? .forwards : .removed
        node.addAnimation(anim, forKey: keyPath + "_anim")
    }

    private func keyframeAnim(keyPath: String, values: [Float],
                               times: [Double], duration: Double) -> CAKeyframeAnimation {
        let anim = CAKeyframeAnimation(keyPath: keyPath)
        anim.values    = values.map { NSNumber(value: $0) }
        anim.keyTimes  = times.map { NSNumber(value: $0) }
        anim.duration  = duration
        anim.fillMode  = .forwards
        anim.isRemovedOnCompletion = false
        return anim
    }

    // MARK: - Math

    private func lerp(_ a: Float, _ b: Float, _ t: Float) -> Float { a + (b - a) * t }
}
#endif
