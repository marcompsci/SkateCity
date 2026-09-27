//  Skater.swift
//  Procedural, IK-driven skater + skateboard rig. Every frame the engine hands it a `RigPose`
//  and the body solves hips/knees/elbows so it crouches, pops, tucks, grabs, balances and bails.
//  (Placeholder art — see README for swapping in a rigged, mocap-animated USDZ character.)

import SceneKit
import UIKit
import simd

struct SkaterStyle: @unchecked Sendable {
    let name: String
    let tagline: String
    let skin: UIColor
    let top: UIColor
    let pants: UIColor
    let shoes: UIColor
    let hat: UIColor?
    let deckA: UIColor
    let deckB: UIColor

    static let roster: [SkaterStyle] = [
        SkaterStyle(name: "Omari", tagline: "Fresno roots, SF streets", skin: UIColor(red: 0.36, green: 0.23, blue: 0.16, alpha: 1),
                    top: UIColor(red: 0.85, green: 0.25, blue: 0.12, alpha: 1), pants: UIColor(red: 0.13, green: 0.14, blue: 0.17, alpha: 1),
                    shoes: .white, hat: UIColor(red: 0.08, green: 0.08, blue: 0.1, alpha: 1),
                    deckA: .systemOrange, deckB: .systemPink),
        SkaterStyle(name: "Nova", tagline: "Transition queen", skin: UIColor(red: 0.93, green: 0.76, blue: 0.64, alpha: 1),
                    top: UIColor(red: 0.2, green: 0.55, blue: 0.95, alpha: 1), pants: UIColor(red: 0.75, green: 0.7, blue: 0.6, alpha: 1),
                    shoes: UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1), hat: nil,
                    deckA: .systemTeal, deckB: .systemBlue),
        SkaterStyle(name: "Dre", tagline: "Rail destroyer", skin: UIColor(red: 0.55, green: 0.36, blue: 0.25, alpha: 1),
                    top: UIColor(red: 0.95, green: 0.8, blue: 0.2, alpha: 1), pants: UIColor(red: 0.25, green: 0.3, blue: 0.2, alpha: 1),
                    shoes: UIColor(red: 0.8, green: 0.1, blue: 0.1, alpha: 1), hat: UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1),
                    deckA: .systemYellow, deckB: .systemGreen),
        SkaterStyle(name: "Kenji", tagline: "Tech-ledge wizard", skin: UIColor(red: 0.85, green: 0.68, blue: 0.52, alpha: 1),
                    top: UIColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1), pants: UIColor(red: 0.2, green: 0.3, blue: 0.55, alpha: 1),
                    shoes: UIColor(red: 0.9, green: 0.9, blue: 0.85, alpha: 1), hat: UIColor(red: 0.5, green: 0.1, blue: 0.6, alpha: 1),
                    deckA: .systemPurple, deckB: .systemIndigo)
    ]
}

// MARK: - Humanoid body (faces +X; its right side is +Z)

@MainActor
final class Humanoid {
    let root = SCNNode()
    private let pelvis: SCNNode, torso: SCNNode, head: SCNNode
    private let thighA: SCNNode, shinA: SCNNode, thighB: SCNNode, shinB: SCNNode
    private let upperA: SCNNode, foreA: SCNNode, upperB: SCNNode, foreB: SCNNode
    private let handA: SCNNode, handB: SCNNode, shoeA: SCNNode, shoeB: SCNNode

    let thigh: Float = 0.45, shin: Float = 0.45, upperArm: Float = 0.3, foreArm: Float = 0.28
    private let torsoBase: Float = 0.43

    init(style: SkaterStyle) {
        let skin = Materials.color(style.skin, rough: 0.55)
        let top = Materials.color(style.top, rough: 0.9)
        let pants = Materials.color(style.pants, rough: 0.85)
        let shoe = Materials.color(style.shoes, rough: 0.6)

        func capsule(_ r: CGFloat, _ len: Float, _ m: SCNMaterial) -> SCNNode {
            let g = SCNCapsule(capRadius: r, height: CGFloat(len) + r * 2)
            g.materials = [m]
            return SCNNode(geometry: g)
        }
        func sphere(_ r: CGFloat, _ m: SCNMaterial) -> SCNNode {
            let g = SCNSphere(radius: r)
            g.segmentCount = 24
            g.materials = [m]
            return SCNNode(geometry: g)
        }

        pelvis = sphere(0.14, pants)
        torso = capsule(0.16, 0.43, top)
        head = sphere(0.11, skin)
        thighA = capsule(0.075, 0.45, pants); thighB = capsule(0.075, 0.45, pants)
        shinA = capsule(0.062, 0.45, pants); shinB = capsule(0.062, 0.45, pants)
        upperA = capsule(0.055, 0.3, top); upperB = capsule(0.055, 0.3, top)
        foreA = capsule(0.045, 0.28, skin); foreB = capsule(0.045, 0.28, skin)
        handA = sphere(0.05, skin); handB = sphere(0.05, skin)

        let shoeGeo = SCNBox(width: 0.28, height: 0.09, length: 0.11, chamferRadius: 0.035)
        shoeGeo.materials = [shoe]
        shoeA = SCNNode(geometry: shoeGeo)
        shoeB = SCNNode(geometry: shoeGeo)

        if let hatColor = style.hat {
            let cap = SCNSphere(radius: 0.118)
            cap.materials = [Materials.color(hatColor, rough: 0.8)]
            let capNode = SCNNode(geometry: cap)
            capNode.simdPosition = SIMD3(-0.01, 0.03, 0)
            capNode.simdScale = SIMD3(1, 0.75, 1)
            head.addChildNode(capNode)
            let brim = SCNBox(width: 0.12, height: 0.015, length: 0.16, chamferRadius: 0.005)
            brim.materials = cap.materials
            let brimNode = SCNNode(geometry: brim)
            brimNode.simdPosition = SIMD3(0.1, 0.045, 0)
            head.addChildNode(brimNode)
        }

        for n in [pelvis, torso, head, thighA, shinA, thighB, shinB, upperA, foreA, upperB, foreB, handA, handB, shoeA, shoeB] {
            n.castsShadow = true
            root.addChildNode(n)
        }
    }

    private func place(_ node: SCNNode, _ a: SIMD3<Float>, _ b: SIMD3<Float>) {
        node.simdPosition = (a + b) * 0.5
        let d = b - a
        let len = simd_length(d)
        node.simdOrientation = len > 1e-5 ? quatFromTo(SIMD3(0, 1, 0), d / len) : simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
    }

    /// Positions are in the humanoid's local space. A = front (+Z) side, B = back (−Z) side.
    func solve(hip: SIMD3<Float>, chest: SIMD3<Float>, head headPos: SIMD3<Float>,
               footA: SIMD3<Float>, footB: SIMD3<Float>, handA hA: SIMD3<Float>, handB hB: SIMD3<Float>) {
        pelvis.simdPosition = hip
        let torsoStart = hip + SIMD3(0, 0.05, 0)
        place(torso, torsoStart, chest)
        torso.simdScale = SIMD3(0.8, max(0.3, simd_distance(torsoStart, chest) / torsoBase), 1.25)
        head.simdPosition = headPos

        let knee = SIMD3<Float>(1, 0, 0)
        let hipA = hip + SIMD3(0, -0.04, 0.09), hipB = hip + SIMD3(0, -0.04, -0.09)
        let la = twoBoneIK(root: hipA, target: footA, l1: thigh, l2: shin, bend: knee)
        let lb = twoBoneIK(root: hipB, target: footB, l1: thigh, l2: shin, bend: knee)
        place(thighA, hipA, la.joint); place(shinA, la.joint, la.end)
        place(thighB, hipB, lb.joint); place(shinB, lb.joint, lb.end)
        shoeA.simdPosition = la.end + SIMD3(0.04, -0.045, 0)
        shoeB.simdPosition = lb.end + SIMD3(0.04, -0.045, 0)

        let elbow = SIMD3<Float>(-1, -0.3, 0)
        let shA = chest + SIMD3(0, -0.02, 0.19), shB = chest + SIMD3(0, -0.02, -0.19)
        let aa = twoBoneIK(root: shA, target: hA, l1: upperArm, l2: foreArm, bend: elbow)
        let ab = twoBoneIK(root: shB, target: hB, l1: upperArm, l2: foreArm, bend: elbow)
        place(upperA, shA, aa.joint); place(foreA, aa.joint, aa.end)
        place(upperB, shB, ab.joint); place(foreB, ab.joint, ab.end)
        handA.simdPosition = aa.end
        handB.simdPosition = ab.end
    }

    /// Simple walk cycle for city pedestrians.
    func walk(phase: Float) {
        let s = sin(phase), c = cos(phase)
        let hip = SIMD3<Float>(0, 0.93 + abs(c) * 0.02, 0)
        let fA = SIMD3<Float>(s * 0.25, 0.08 + max(0, c) * 0.08, 0.1)
        let fB = SIMD3<Float>(-s * 0.25, 0.08 + max(0, -c) * 0.08, -0.1)
        let chest = hip + SIMD3(0.02, 0.48, 0)
        let hA = chest + SIMD3(-s * 0.2, -0.52, 0.22)
        let hB = chest + SIMD3(s * 0.2, -0.52, -0.22)
        solve(hip: hip, chest: chest, head: chest + SIMD3(0.03, 0.25, 0), footA: fA, footB: fB, handA: hA, handB: hB)
    }
}

// MARK: - Skater + board rig

struct RigPose {
    var crouch: Float = 0
    var lift: Float = 0
    var feetTuck: Float = 0
    var lean: Float = 0
    var armsOut: Float = 0
    var grab: GrabKind?
    var grabReach: Float = 0
    var pushPhase: Float?
    var boardRotation = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
    var boardOffset = SIMD3<Float>(0, 0, 0)
    var bail: Float = 0
}

@MainActor
final class SkaterRig {
    let root = SCNNode()          // world position / heading / surface tilt
    let boardPivot = SCNNode()    // flips spin around this
    let riderRoot = SCNNode()
    let body: Humanoid

    init(style: SkaterStyle) {
        body = Humanoid(style: style)
        root.addChildNode(boardPivot)
        root.addChildNode(riderRoot)
        riderRoot.addChildNode(body.root)
        buildBoard(style)
    }

    private func buildBoard(_ style: SkaterStyle) {
        let wood = Materials.color(UIColor(red: 0.78, green: 0.62, blue: 0.42, alpha: 1), rough: 0.6)
        let grip = SCNMaterial()
        grip.lightingModel = .physicallyBased
        grip.diffuse.contents = TextureCache.shared.grip
        grip.roughness.contents = NSNumber(value: 1)
        let graphic = SCNMaterial()
        graphic.lightingModel = .physicallyBased
        graphic.diffuse.contents = TextureFactory.deckGraphic(style.deckA, style.deckB)
        graphic.roughness.contents = NSNumber(value: 0.35)
        let deckMats = [wood, wood, wood, wood, grip, graphic]

        let deck = SCNBox(width: 0.21, height: 0.014, length: 0.56, chamferRadius: 0.004)
        deck.materials = deckMats
        let deckNode = SCNNode(geometry: deck)
        deckNode.simdPosition = SIMD3(0, 0.02, 0)
        boardPivot.addChildNode(deckNode)

        for (z, angle) in [(Float(0.28), Float(-0.32)), (Float(-0.28), Float(0.32))] {
            let kickPivot = SCNNode()
            kickPivot.simdPosition = SIMD3(0, 0.02, z)
            kickPivot.simdEulerAngles = SIMD3(angle, 0, 0)
            let kick = SCNBox(width: 0.21, height: 0.014, length: 0.14, chamferRadius: 0.006)
            kick.materials = deckMats
            let kickNode = SCNNode(geometry: kick)
            kickNode.simdPosition = SIMD3(0, 0, z > 0 ? 0.065 : -0.065)
            kickPivot.addChildNode(kickNode)
            boardPivot.addChildNode(kickPivot)
        }

        let metal = Materials.color(UIColor(white: 0.75, alpha: 1), rough: 0.3, metal: 1)
        let urethane = Materials.color(UIColor(white: 0.95, alpha: 1), rough: 0.45)
        for z: Float in [0.2, -0.2] {
            let base = SCNNode(geometry: SCNBox(width: 0.06, height: 0.014, length: 0.08, chamferRadius: 0.003))
            base.geometry?.materials = [metal]
            base.simdPosition = SIMD3(0, 0.006, z)
            let hanger = SCNNode(geometry: SCNBox(width: 0.17, height: 0.022, length: 0.03, chamferRadius: 0.008))
            hanger.geometry?.materials = [metal]
            hanger.simdPosition = SIMD3(0, -0.018, z)
            boardPivot.addChildNode(base)
            boardPivot.addChildNode(hanger)
            for x: Float in [0.1, -0.1] {
                let w = SCNCylinder(radius: 0.027, height: 0.034)
                w.materials = [urethane]
                let wn = SCNNode(geometry: w)
                wn.simdEulerAngles = SIMD3(0, 0, .pi / 2)
                wn.simdPosition = SIMD3(x, -0.033, z)
                boardPivot.addChildNode(wn)
            }
        }
        boardPivot.enumerateHierarchy { n, _ in n.castsShadow = true }
    }

    func apply(_ p: RigPose) {
        let boardTop: Float = 0.087 + p.lift
        boardPivot.simdPosition = SIMD3(0, 0.06 + p.lift, 0) + p.boardOffset
        boardPivot.simdOrientation = p.boardRotation
        riderRoot.simdOrientation = simd_quatf(angle: -p.bail * 1.35, axis: SIMD3(0, 0, 1))

        let ankleY = boardTop + 0.07 + p.feetTuck
        var footA = SIMD3<Float>(0, ankleY, 0.19)
        var footB = SIMD3<Float>(0, ankleY, -0.19)
        if let ph = p.pushPhase {
            footA = SIMD3(0.02, ankleY, 0.1)
            let s = 0.5 + 0.5 * sin(ph)
            footB = SIMD3(0.14, 0.07 + max(0, cos(ph)) * 0.1, -0.05 - 0.4 * s)
        }
        if p.bail > 0 {
            footA.x += p.bail * 0.2
            footB.x -= p.bail * 0.2
        }

        let c = p.crouch
        let hip = SIMD3<Float>(0.03 - c * 0.1 + p.lean * 0.08, boardTop + 0.85 - c * 0.3 + p.feetTuck * 0.4, 0)
        let chest = hip + SIMD3<Float>(0.05 + c * 0.14 + p.grabReach * 0.12 + p.lean * 0.18,
                                       0.48 - c * 0.06 - p.grabReach * 0.1, 0)
        let head = chest + SIMD3<Float>(0.05, 0.25, 0)
        let shA = chest + SIMD3<Float>(0, -0.02, 0.19), shB = chest + SIMD3<Float>(0, -0.02, -0.19)

        var handA = lerp3(shA + SIMD3(0.06, -0.5, 0.1), shA + SIMD3(0.05, -0.1, 0.52), p.armsOut)
        var handB = lerp3(shB + SIMD3(0.06, -0.5, -0.1), shB + SIMD3(-0.05, -0.1, -0.52), p.armsOut)
        if p.bail > 0 {
            handA = lerp3(handA, shA + SIMD3(0.5, 0.1, 0.2), p.bail)
            handB = lerp3(handB, shB + SIMD3(0.5, 0.1, -0.2), p.bail)
        }
        if let g = p.grab, p.grabReach > 0.01 {
            let bt = boardTop + 0.02
            switch g {
            case .indy: handB = lerp3(handB, SIMD3(0.11, bt, 0.0), p.grabReach)
            case .melon: handA = lerp3(handA, SIMD3(-0.11, bt, 0.05), p.grabReach)
            case .method: handA = lerp3(handA, SIMD3(-0.11, bt, -0.02), p.grabReach)
            case .noseGrab: handA = lerp3(handA, SIMD3(0.0, bt, 0.36), p.grabReach)
            case .tailGrab: handB = lerp3(handB, SIMD3(0.0, bt, -0.36), p.grabReach)
            }
        }
        body.solve(hip: hip, chest: chest, head: head, footA: footA, footB: footB, handA: handA, handB: handB)
    }
}
