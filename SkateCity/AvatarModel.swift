// Copyright © 2026 MAR / SkateCity. All rights reserved.
// Unauthorized reproduction, distribution, or modification is strictly prohibited.

#if os(iOS)
import SceneKit
import UIKit

// MARK: - Human proportions (metres)

private enum Dims {
    static let headR:    Float = 0.114
    static let neckLen:  Float = 0.080
    static let torsoH:   Float = 0.520
    static let pelvisH:  Float = 0.170
    static let thighLen: Float = 0.440
    static let shinLen:  Float = 0.400
    static let footLen:  Float = 0.255
    static let footH:    Float = 0.090
    static let uArmLen:  Float = 0.320
    static let fArmLen:  Float = 0.255
    static let handH:    Float = 0.090
    static let shoulderW: Float = 0.215   // half-width from spine

    // Y positions from ground (regular stance, knees slightly bent)
    static let hipsY:    Float = 0.900
    static let spineOff: Float = 0.110
    static let chestOff: Float = 0.240
    static let neckOff:  Float = 0.270
    static let headOff:  Float = neckLen + headR + 0.010
}

// MARK: - AvatarModel

/// Procedural semi-realistic skater avatar built from SceneKit primitives.
/// All geometry is original character IP for SkateCity.
final class AvatarModel {

    // MARK: Public pivot nodes (used by AnimationController for IK & pose)

    let rootNode      = SCNNode()   // placed at world y = 0
    let hipsNode      = SCNNode()
    let spineNode     = SCNNode()
    let chestNode     = SCNNode()
    let neckNode      = SCNNode()
    let headNode      = SCNNode()

    let thighLNode    = SCNNode()
    let thighRNode    = SCNNode()
    let shinLNode     = SCNNode()
    let shinRNode     = SCNNode()
    let footLNode     = SCNNode()
    let footRNode     = SCNNode()

    let shoulderLNode = SCNNode()
    let shoulderRNode = SCNNode()
    let elbowLNode    = SCNNode()
    let elbowRNode    = SCNNode()
    let wristLNode    = SCNNode()
    let wristRNode    = SCNNode()

    // Contact shadow
    private(set) var shadowPlane = SCNNode()

    // Current profile
    private(set) var profile = SkaterWardrobeProfile()

    // MARK: Init

    init() {
        setupHierarchy()
        buildSkeletonMeshes()
        buildContactShadow()
        // Default appearance
        var p = SkaterWardrobeProfile(); p.initStarterOwned()
        apply(profile: p)
    }

    // MARK: Public API

    /// Apply a wardrobe profile — rebuilds all clothing overlays.
    func apply(profile: SkaterWardrobeProfile) {
        self.profile = profile
        removeClothing()
        applyBaseSkin(hex: Wardrobe.skinTones[min(profile.skin, Wardrobe.skinTones.count - 1)])
        applyEyeColor(hex: "#5a4a38")
        buildShoes(profile)
        buildBottoms(profile)
        buildTop(profile)
        buildHeadwear(profile)
        buildExtras(profile)
        buildFacialHair(profile)
    }

    // MARK: - Skeleton hierarchy

    private func setupHierarchy() {
        rootNode.name = "AvatarRoot"

        // Hips
        hipsNode.position = SCNVector3(0, Dims.hipsY, 0)
        rootNode.addChildNode(hipsNode)

        // Spine chain
        spineNode.position = SCNVector3(0, Dims.spineOff, 0)
        hipsNode.addChildNode(spineNode)

        chestNode.position = SCNVector3(0, Dims.chestOff, 0)
        spineNode.addChildNode(chestNode)

        neckNode.position = SCNVector3(0, Dims.neckOff, 0)
        chestNode.addChildNode(neckNode)

        headNode.position = SCNVector3(0, Dims.headOff, 0)
        neckNode.addChildNode(headNode)

        // Legs
        for side in [-1, 1] as [Float] {
            let tN = side < 0 ? thighLNode : thighRNode
            let sN = side < 0 ? shinLNode  : shinRNode
            let fN = side < 0 ? footLNode  : footRNode
            tN.position = SCNVector3(side * 0.10, 0, 0)
            sN.position = SCNVector3(0, -Dims.thighLen, 0)
            fN.position = SCNVector3(0, -Dims.shinLen, 0)
            tN.addChildNode(sN); sN.addChildNode(fN)
            hipsNode.addChildNode(tN)
        }

        // Arms
        for side in [-1, 1] as [Float] {
            let shN = side < 0 ? shoulderLNode : shoulderRNode
            let elN = side < 0 ? elbowLNode    : elbowRNode
            let wrN = side < 0 ? wristLNode    : wristRNode
            shN.position = SCNVector3(side * Dims.shoulderW, Dims.chestOff * 0.88, 0)
            shN.eulerAngles = SCNVector3(0, 0, side * 0.12)
            elN.position = SCNVector3(0, -Dims.uArmLen, 0)
            wrN.position = SCNVector3(0, -Dims.fArmLen, 0)
            shN.addChildNode(elN); elN.addChildNode(wrN)
            chestNode.addChildNode(shN)
        }
    }

    // MARK: - Base skeleton meshes (skin-coloured body, no clothing)

    private func buildSkeletonMeshes() {
        let skinMat = AvatarMaterials.skin(hex: "#d6a07a")

        // Pelvis blob
        addMesh(SCNCapsule(capRadius: 0.155, height: 0.14), to: hipsNode,
                at: SCNVector3(0, -0.04, 0), euler: SCNVector3(Float.pi/2, 0, 0),
                name: "sk_pelvis", mat: skinMat)

        // Abdomen
        addMesh(SCNCapsule(capRadius: 0.130, height: 0.22), to: spineNode,
                at: SCNVector3(0, 0.10, 0), name: "sk_abdomen", mat: skinMat)

        // Chest
        let chestGeo = SCNCapsule(capRadius: 0.166, height: 0.28)
        chestGeo.radialSegmentCount = 20
        let chestMesh = SCNNode(geometry: chestGeo)
        chestMesh.name = "sk_chest"; chestMesh.scale = SCNVector3(1, 1, 0.73)
        chestMesh.geometry?.materials = [skinMat]; chestNode.addChildNode(chestMesh)

        // Neck
        addMesh(SCNCapsule(capRadius: 0.042, height: CGFloat(Dims.neckLen) * 0.9), to: neckNode,
                at: SCNVector3(0, Dims.neckLen * 0.3, 0), name: "sk_neck", mat: skinMat)

        // Head
        buildHead(skinMat)

        // Thighs / shins / feet
        for (tN, sN, fN) in [(thighLNode, shinLNode, footLNode), (thighRNode, shinRNode, footRNode)] {
            addMesh(SCNCapsule(capRadius: 0.070, height: CGFloat(Dims.thighLen) * 0.84), to: tN,
                    at: SCNVector3(0, -Dims.thighLen * 0.42, 0), name: "sk_thigh", mat: skinMat)
            addMesh(SCNSphere(radius: 0.060), to: sN,
                    at: SCNVector3(0, 0, 0.014), name: "sk_kneecap", mat: skinMat)
            addMesh(SCNCapsule(capRadius: 0.057, height: CGFloat(Dims.shinLen) * 0.80), to: sN,
                    at: SCNVector3(0, -Dims.shinLen * 0.40, 0), name: "sk_shin", mat: skinMat)
            // Ankle
            addMesh(SCNSphere(radius: 0.038), to: fN,
                    at: SCNVector3(0, 0, 0), name: "sk_ankle", mat: skinMat)
        }

        // Upper arms / forearms / hands
        for (shN, elN, wrN) in [(shoulderLNode, elbowLNode, wristLNode),
                                 (shoulderRNode, elbowRNode, wristRNode)] {
            addMesh(SCNCapsule(capRadius: 0.052, height: CGFloat(Dims.uArmLen) * 0.82), to: shN,
                    at: SCNVector3(0, -Dims.uArmLen * 0.41, 0), name: "sk_uarm", mat: skinMat)
            addMesh(SCNSphere(radius: 0.050), to: elN,
                    at: SCNVector3(0, 0, 0), name: "sk_elbow", mat: skinMat)
            addMesh(SCNCapsule(capRadius: 0.043, height: CGFloat(Dims.fArmLen) * 0.82), to: elN,
                    at: SCNVector3(0, -Dims.fArmLen * 0.41, 0), name: "sk_farm", mat: skinMat)
            // Hand blob
            let handGeo = SCNBox(width: 0.070, height: 0.042, length: 0.082, chamferRadius: 0.016)
            let handNode = SCNNode(geometry: handGeo)
            handNode.name = "sk_hand"
            handNode.position = SCNVector3(0, -Dims.handH * 0.5, 0)
            handNode.geometry?.materials = [skinMat]
            wrN.addChildNode(handNode)
            addFingers(to: wrN, skin: skinMat)
        }
    }

    private func buildHead(_ skinMat: SCNMaterial) {
        // Skull
        let skull = SCNSphere(radius: CGFloat(Dims.headR)); skull.segmentCount = 24
        let skullNode = SCNNode(geometry: skull)
        skullNode.name = "sk_skull"; skullNode.scale = SCNVector3(0.93, 1.06, 0.98)
        skullNode.geometry?.materials = [skinMat]; headNode.addChildNode(skullNode)

        // Jaw
        let jaw = SCNSphere(radius: 0.086); jaw.segmentCount = 18
        let jawNode = SCNNode(geometry: jaw); jawNode.position = SCNVector3(0, -0.062, 0.018)
        jawNode.scale = SCNVector3(0.88, 0.65, 0.90); jawNode.name = "sk_jaw"
        jawNode.geometry?.materials = [skinMat]; headNode.addChildNode(jawNode)

        // Nose
        let noseGeo = SCNBox(width: 0.022, height: 0.036, length: 0.030, chamferRadius: 0.010)
        let noseNode = SCNNode(geometry: noseGeo); noseNode.position = SCNVector3(0, -0.028, Dims.headR * 0.92)
        noseNode.geometry?.materials = [skinMat]; headNode.addChildNode(noseNode)

        // Lips
        let lipGeo = SCNBox(width: 0.048, height: 0.010, length: 0.010, chamferRadius: 0.004)
        let lipNode = SCNNode(geometry: lipGeo); lipNode.position = SCNVector3(0, -0.072, CGFloat(Dims.headR) * 0.90)
        lipNode.geometry?.materials = [AvatarMaterials.plain(hex: "#7a3b38")]; headNode.addChildNode(lipNode)

        // Eyes
        for side: Float in [-1, 1] {
            let eyeWhiteGeo = SCNSphere(radius: 0.016); eyeWhiteGeo.segmentCount = 12
            let eyeWhite = SCNNode(geometry: eyeWhiteGeo)
            eyeWhite.name = "sk_eyewhite"
            eyeWhite.position = SCNVector3(side * 0.040, 0.004, Dims.headR * 0.87)
            eyeWhite.geometry?.materials = [AvatarMaterials.plain(hex: "#f0ece5")]
            headNode.addChildNode(eyeWhite)

            let irisGeo = SCNCylinder(radius: 0.010, height: 0.004)
            let irisNode = SCNNode(geometry: irisGeo)
            irisNode.name = "sk_iris"
            irisNode.eulerAngles = SCNVector3(Float.pi/2, 0, 0)
            irisNode.position = SCNVector3(0, 0, 0.015)
            irisNode.geometry?.materials = [AvatarMaterials.iris(hex: "#3a2e22")]
            eyeWhite.addChildNode(irisNode)

            // Brow
            let browGeo = SCNBox(width: 0.030, height: 0.008, length: 0.006, chamferRadius: 0.003)
            let browNode = SCNNode(geometry: browGeo)
            browNode.position = SCNVector3(side * 0.040, 0.026, Dims.headR * 0.86)
            browNode.eulerAngles = SCNVector3(0, 0, side * -0.18)
            browNode.geometry?.materials = [AvatarMaterials.plain(hex: "#3b2618")]
            browNode.name = "sk_brow"
            headNode.addChildNode(browNode)
        }

        // Ears
        for side: Float in [-1, 1] {
            let earGeo = SCNSphere(radius: 0.028); earGeo.segmentCount = 10
            let earNode = SCNNode(geometry: earGeo)
            earNode.position = SCNVector3(side * Dims.headR * 0.94, -0.006, -0.005)
            earNode.scale = SCNVector3(0.46, 1.0, 0.80)
            earNode.name = "sk_ear"
            earNode.geometry?.materials = [skinMat]; headNode.addChildNode(earNode)
        }
    }

    private func addFingers(to wrist: SCNNode, skin: SCNMaterial) {
        let configs: [(dx: Float, len: Float, bent: Float)] = [
            (-0.026, 0.034, 0.10), (-0.010, 0.038, 0.08),
            ( 0.004, 0.037, 0.08), ( 0.018, 0.033, 0.10), ( 0.030, 0.022, 0.24)
        ]
        for (i, c) in configs.enumerated() {
            let knuckle = SCNNode(); knuckle.position = SCNVector3(c.dx, -0.052, 0.014)
            knuckle.name = "sk_finger\(i)"
            let geo = SCNCapsule(capRadius: 0.006, height: CGFloat(c.len))
            geo.radialSegmentCount = 6; geo.heightSegmentCount = 1
            let p1 = SCNNode(geometry: geo); p1.geometry?.materials = [skin]
            p1.position = SCNVector3(0, -c.len * 0.5, 0)
            knuckle.addChildNode(p1)
            let tip = SCNNode(); tip.position = SCNVector3(0, -c.len, 0)
            tip.eulerAngles = SCNVector3(c.bent, 0, 0)
            let geo2 = SCNCapsule(capRadius: 0.005, height: CGFloat(c.len * 0.75))
            geo2.radialSegmentCount = 5; geo2.heightSegmentCount = 1
            let p2 = SCNNode(geometry: geo2); p2.geometry?.materials = [skin]
            p2.position = SCNVector3(0, -c.len * 0.375, 0)
            tip.addChildNode(p2); knuckle.addChildNode(tip)
            wrist.addChildNode(knuckle)
        }
    }

    // MARK: - Contact shadow

    private func buildContactShadow() {
        let geo = SCNPlane(width: 0.95, height: 0.95)
        let mat = SCNMaterial()
        mat.lightingModel     = .constant
        mat.diffuse.contents  = UIColor(white: 0, alpha: 0.38)
        mat.transparencyMode  = .singleLayer
        mat.isDoubleSided     = true
        mat.writesToDepthBuffer  = false
        mat.readsFromDepthBuffer = true
        geo.materials = [mat]
        shadowPlane.geometry    = geo
        shadowPlane.eulerAngles = SCNVector3(-Float.pi/2, 0, 0)
        shadowPlane.position    = SCNVector3(0, 0.003, 0)
        shadowPlane.castsShadow = false
        rootNode.addChildNode(shadowPlane)
    }

    // MARK: - Material helpers

    private func applyBaseSkin(hex: String) {
        let mat = AvatarMaterials.skin(hex: hex)
        rootNode.enumerateChildNodes { n, _ in
            guard let name = n.name, name.hasPrefix("sk_") else { return }
            n.geometry?.materials = [mat]
            n.castsShadow = true
        }
    }

    private func applyEyeColor(hex: String) {
        let mat = AvatarMaterials.iris(hex: hex)
        rootNode.enumerateChildNodes { n, _ in
            if n.name == "sk_iris" { n.geometry?.materials = [mat] }
        }
    }

    // MARK: - Remove clothing overlays

    private func removeClothing() {
        rootNode.enumerateChildNodes { n, _ in
            if n.name?.hasPrefix("cl_") == true { n.removeFromParentNode() }
        }
    }

    // MARK: - Shoes

    private func buildShoes(_ profile: SkaterWardrobeProfile) {
        let sel  = profile.shoes
        let item = Wardrobe.store.item(key: "shoes", id: sel.itemID)
        let c1   = item?.variants.indices.contains(sel.variant) == true
                   ? item!.variants[sel.variant].color1 : "#1d1e22"
        let c2   = item?.variants.indices.contains(sel.variant) == true
                   ? item!.variants[sel.variant].color2 : "#f2f0ea"
        let isHighTop = sel.itemID == "vulcHigh"
        let isChunky  = sel.itemID == "puffy" || sel.itemID == "runner"
        let upperMat  = AvatarMaterials.shoe(hex: c1, style: sel.itemID)
        let soleMat   = AvatarMaterials.sole(hex: c2)

        for foot in [footLNode, footRNode] {
            let g = SCNNode(); g.name = "cl_shoe"

            // Upper
            let upperW: CGFloat = isChunky ? 0.108 : 0.100
            let upperH: CGFloat = isChunky ? 0.080 : 0.070
            let upper = SCNBox(width: upperW, height: upperH, length: CGFloat(Dims.footLen * 0.90), chamferRadius: 0.022)
            let uNode = SCNNode(geometry: upper); uNode.position = SCNVector3(0, 0.016, 0.055)
            uNode.geometry?.materials = [upperMat]; g.addChildNode(uNode)

            // Sole
            let soleH: CGFloat = isChunky ? 0.030 : 0.020
            let sole = SCNBox(width: upperW + 0.006, height: soleH,
                              length: CGFloat(Dims.footLen + 0.018), chamferRadius: 0.008)
            let sNode = SCNNode(geometry: sole); sNode.position = SCNVector3(0, 0.016 - upperH/2 - soleH/2, 0.057)
            sNode.geometry?.materials = [soleMat]; g.addChildNode(sNode)

            // High-top collar
            if isHighTop {
                let collarGeo = SCNCylinder(radius: 0.052, height: 0.065)
                let cNode = SCNNode(geometry: collarGeo); cNode.position = SCNVector3(0, 0.065, -0.022)
                cNode.geometry?.materials = [upperMat]; g.addChildNode(cNode)
            }

            // Lace strip (visible canvas strip across top)
            let lace = SCNBox(width: 0.042, height: 0.004, length: CGFloat(Dims.footLen * 0.58), chamferRadius: 0.002)
            let lNode = SCNNode(geometry: lace); lNode.position = SCNVector3(0, 0.053, 0.028)
            lNode.geometry?.materials = [AvatarMaterials.plain(hex: "#f4f0ea")]; g.addChildNode(lNode)

            foot.addChildNode(g)
        }
    }

    // MARK: - Bottoms

    private func buildBottoms(_ profile: SkaterWardrobeProfile) {
        let sel  = profile.bottom
        let item = Wardrobe.store.item(key: "bottom", id: sel.itemID)
        let c1   = item?.variants.indices.contains(sel.variant) == true
                   ? item!.variants[sel.variant].color1 : "#2e3f66"
        let mat  = AvatarMaterials.pants(hex: c1, style: sel.itemID)
        let isShorts = sel.itemID == "shorts"
        let isBaggy  = sel.itemID == "baggy" || sel.itemID == "flames"

        for (tN, sN) in [(thighLNode, shinLNode), (thighRNode, shinRNode)] {
            // Thigh
            let thighR: CGFloat = isBaggy ? 0.086 : 0.079
            let tGeo = SCNCapsule(capRadius: thighR, height: CGFloat(Dims.thighLen * 0.86))
            let tNode = SCNNode(geometry: tGeo); tNode.name = "cl_pants"
            tNode.position = SCNVector3(0, -Dims.thighLen * 0.43, 0)
            tNode.geometry?.materials = [mat]; tN.addChildNode(tNode)

            if !isShorts {
                // Shin
                let sGeo = SCNCapsule(capRadius: isBaggy ? 0.074 : 0.064,
                                      height: CGFloat(Dims.shinLen * 0.82))
                let sNode2 = SCNNode(geometry: sGeo); sNode2.name = "cl_pants"
                sNode2.position = SCNVector3(0, -Dims.shinLen * 0.41, 0)
                sNode2.geometry?.materials = [mat]; sN.addChildNode(sNode2)

                // Cuff / hem at ankle
                let cuffGeo = SCNCylinder(radius: isBaggy ? 0.072 : 0.062, height: 0.028)
                let cNode = SCNNode(geometry: cuffGeo); cNode.name = "cl_pants_cuff"
                cNode.position = SCNVector3(0, -Dims.shinLen + 0.012, 0)
                cNode.geometry?.materials = [mat]; sN.addChildNode(cNode)
            }
        }

        // Belt
        let beltGeo = SCNTorus(ringRadius: 0.168, pipeRadius: 0.014)
        let belt = SCNNode(geometry: beltGeo); belt.name = "cl_belt"
        belt.eulerAngles = SCNVector3(Float.pi/2, 0, 0)
        belt.position    = SCNVector3(0, 0.045, 0)
        belt.geometry?.materials = [AvatarMaterials.plain(hex: "#18191c")]
        hipsNode.addChildNode(belt)

        // Belt buckle
        let buckleGeo = SCNBox(width: 0.034, height: 0.026, length: 0.008, chamferRadius: 0.004)
        let buckle = SCNNode(geometry: buckleGeo); buckle.name = "cl_belt_buckle"
        buckle.position = SCNVector3(0, Dims.hipsY + 0.045, 0.145)
        buckle.geometry?.materials = [AvatarMaterials.metal(hex: "#c3cad3", roughness: 0.30, metalness: 0.85)]
        rootNode.addChildNode(buckle)
    }

    // MARK: - Tops

    private func buildTop(_ profile: SkaterWardrobeProfile) {
        let sel  = profile.top
        let item = Wardrobe.store.item(key: "top", id: sel.itemID)
        let c1   = item?.variants.indices.contains(sel.variant) == true
                   ? item!.variants[sel.variant].color1 : "#9ea3a8"
        let c2   = item?.variants.indices.contains(sel.variant) == true
                   ? item!.variants[sel.variant].color2 : c1
        let style = sel.itemID
        let mat   = AvatarMaterials.top(hex: c1, style: style)
        let isTank    = style == "tank"
        let isShort   = isTank || style == "tee" || style == "graphicTee" || style == "stripeTee"
        let isHoodie  = style == "hoodie"
        let isJacket  = style == "coach" || style == "varsity"

        // Chest overlay (slightly larger than skeleton chest)
        let chestOvr = SCNCapsule(capRadius: 0.178, height: 0.29)
        let cNode = SCNNode(geometry: chestOvr); cNode.name = "cl_top_chest"
        cNode.scale = SCNVector3(1, 1, 0.76); cNode.geometry?.materials = [mat]
        chestNode.addChildNode(cNode)

        // Collar / neck opening
        if !isHoodie && !isJacket {
            let collar = SCNTorus(ringRadius: 0.070, pipeRadius: 0.015)
            let collarNode = SCNNode(geometry: collar); collarNode.name = "cl_collar"
            collarNode.eulerAngles = SCNVector3(Float.pi/2, 0, 0)
            collarNode.position    = SCNVector3(0, 0.285, 0)
            collarNode.geometry?.materials = [AvatarMaterials.top(hex: darken(c1, 0.85), style: style)]
            chestNode.addChildNode(collarNode)
        }

        // Hem
        let hem = SCNTorus(ringRadius: 0.172, pipeRadius: 0.018)
        let hemNode = SCNNode(geometry: hem); hemNode.name = "cl_hem"
        hemNode.eulerAngles = SCNVector3(Float.pi/2, 0, 0); hemNode.position = SCNVector3(0, -0.10, 0)
        hemNode.scale = SCNVector3(1, 1, 0.76); hemNode.geometry?.materials = [mat]
        chestNode.addChildNode(hemNode)

        // Sleeves
        for (shN, elN) in [(shoulderLNode, elbowLNode), (shoulderRNode, elbowRNode)] {
            let sleeveLen: Float = isShort ? Dims.uArmLen * 0.48 : Dims.uArmLen * 0.90
            let slGeo = SCNCapsule(capRadius: 0.060, height: CGFloat(sleeveLen))
            let slNode = SCNNode(geometry: slGeo); slNode.name = "cl_sleeve"
            slNode.position = SCNVector3(0, -sleeveLen * 0.5, 0)
            slNode.geometry?.materials = [mat]; shN.addChildNode(slNode)

            if !isShort {
                let faGeo = SCNCapsule(capRadius: 0.054, height: CGFloat(Dims.fArmLen * 0.84))
                let faNode = SCNNode(geometry: faGeo); faNode.name = "cl_forearm"
                faNode.position = SCNVector3(0, -Dims.fArmLen * 0.42, 0)
                faNode.geometry?.materials = [mat]; elN.addChildNode(faNode)

                // Cuff
                let cuffGeo = SCNCylinder(radius: 0.057, height: 0.028)
                let cuffNode = SCNNode(geometry: cuffGeo); cuffNode.name = "cl_cuff"
                cuffNode.position = SCNVector3(0, -Dims.fArmLen + 0.012, 0)
                cuffNode.geometry?.materials = [AvatarMaterials.ribKnit(hex: c1)]
                elN.addChildNode(cuffNode)
            }
        }

        // Hoodie-specific: hood + drawstrings + kangaroo pocket
        if isHoodie { buildHoodDetails(c1: c1) }

        // Jacket: zip strip
        if isJacket {
            let zipGeo = SCNCylinder(radius: 0.003, height: 0.24)
            let zipNode = SCNNode(geometry: zipGeo); zipNode.name = "cl_zip"
            zipNode.position = SCNVector3(0, 0.12, 0.145)
            zipNode.geometry?.materials = [AvatarMaterials.metal(hex: "#d8d8d8", roughness: 0.25, metalness: 0.9)]
            chestNode.addChildNode(zipNode)

            // Contrast body for varsity
            if style == "varsity" {
                let body2Mat = AvatarMaterials.top(hex: c2, style: style)
                let body2 = SCNCapsule(capRadius: 0.174, height: 0.28)
                let b2N = SCNNode(geometry: body2); b2N.name = "cl_varsity_body2"
                b2N.scale = SCNVector3(1, 1, 0.76)
                b2N.geometry?.materials = [body2Mat]
                // Clip to left half using scale trick
                b2N.position = SCNVector3(-0.06, 0, 0); b2N.scale = SCNVector3(0.5, 1, 0.76)
                chestNode.addChildNode(b2N)
            }
        }

        // Tank: shoulder straps
        if isTank {
            for side: Float in [-1, 1] {
                let strap = SCNBox(width: 0.050, height: 0.080, length: 0.020, chamferRadius: 0.008)
                let sNode = SCNNode(geometry: strap); sNode.name = "cl_strap"
                sNode.position = SCNVector3(side * 0.100, 0.265, 0.008)
                sNode.geometry?.materials = [mat]; chestNode.addChildNode(sNode)
            }
        }
    }

    private func buildHoodDetails(c1: String) {
        let mat = AvatarMaterials.top(hex: c1, style: "hoodie")

        // Hood torus at back of neck
        let hood = SCNTorus(ringRadius: 0.098, pipeRadius: 0.054)
        let hoodNode = SCNNode(geometry: hood); hoodNode.name = "cl_hood"
        hoodNode.eulerAngles = SCNVector3(-0.42, 0, 0)
        hoodNode.position    = SCNVector3(0, 0.12, -0.080)
        hoodNode.geometry?.materials = [mat]; neckNode.addChildNode(hoodNode)

        // Kangaroo pocket
        let pocket = SCNBox(width: 0.190, height: 0.090, length: 0.022, chamferRadius: 0.012)
        let pNode = SCNNode(geometry: pocket); pNode.name = "cl_pocket"
        pNode.position = SCNVector3(0, -0.02, 0.142)
        pNode.geometry?.materials = [AvatarMaterials.top(hex: darken(c1, 0.90), style: "hoodie")]
        chestNode.addChildNode(pNode)

        // Drawstrings
        for side: Float in [-1, 1] {
            let str = SCNCylinder(radius: 0.003, height: 0.110)
            let sNode = SCNNode(geometry: str); sNode.name = "cl_drawstring"
            sNode.position = SCNVector3(side * 0.034, 0.10, 0.138)
            sNode.eulerAngles = SCNVector3(0.15, 0, 0)
            sNode.geometry?.materials = [AvatarMaterials.plain(hex: "#e8e2d2")]
            chestNode.addChildNode(sNode)
        }

        // Hem rib
        let hemRib = SCNTorus(ringRadius: 0.175, pipeRadius: 0.022)
        let hrNode = SCNNode(geometry: hemRib); hrNode.name = "cl_hoodie_hem"
        hrNode.eulerAngles = SCNVector3(Float.pi/2, 0, 0); hrNode.position = SCNVector3(0, -0.10, 0)
        hrNode.scale = SCNVector3(1, 1, 0.76)
        hrNode.geometry?.materials = [AvatarMaterials.ribKnit(hex: c1)]; chestNode.addChildNode(hrNode)
    }

    // MARK: - Headwear

    private func buildHeadwear(_ profile: SkaterWardrobeProfile) {
        guard profile.hat.itemID != "none" else { return }
        let sel  = profile.hat
        let item = Wardrobe.store.item(key: "hat", id: sel.itemID)
        let c1   = item?.variants.indices.contains(sel.variant) == true
                   ? item!.variants[sel.variant].color1 : "#2b2f38"
        let mat  = AvatarMaterials.top(hex: c1, style: "hat")
        let HR   = CGFloat(Dims.headR)

        switch sel.itemID {
        case "beanie":
            let crown = SCNSphere(radius: HR + 0.014); crown.segmentCount = 20
            let cNode = SCNNode(geometry: crown); cNode.name = "cl_hat"
            cNode.scale = SCNVector3(0.97, 1.06, 1.0); cNode.geometry?.materials = [mat]
            let cuff = SCNCylinder(radius: HR + 0.014, height: 0.048)
            let cuNode = SCNNode(geometry: cuff); cuNode.name = "cl_hat"
            cuNode.position = SCNVector3(0, -0.030, 0); cuNode.geometry?.materials = [AvatarMaterials.ribKnit(hex: c1)]
            [cNode, cuNode].forEach { headNode.addChildNode($0) }

        case "cap", "capBack":
            let crown = SCNSphere(radius: HR + 0.010); crown.segmentCount = 20
            let cNode = SCNNode(geometry: crown); cNode.name = "cl_hat"
            cNode.scale = SCNVector3(0.97, 0.88, 1.02); cNode.position = SCNVector3(0, 0.020, 0)
            cNode.geometry?.materials = [mat]
            let brim = SCNBox(width: 0.180, height: 0.012, length: 0.125, chamferRadius: 0.012)
            let bNode = SCNNode(geometry: brim); bNode.name = "cl_hat_brim"
            bNode.position = SCNVector3(0, 0.018, 0.168); bNode.eulerAngles = SCNVector3(0.10, 0, 0)
            bNode.geometry?.materials = [mat]
            [cNode, bNode].forEach { headNode.addChildNode($0) }
            if sel.itemID == "capBack" {
                headNode.childNodes.filter { $0.name?.hasPrefix("cl_hat") == true }
                    .forEach { $0.eulerAngles.y = .pi }
            }

        case "bucket":
            let crown = SCNCylinder(radius: HR + 0.012, height: 0.100)
            let cNode = SCNNode(geometry: crown); cNode.name = "cl_hat"
            cNode.position = SCNVector3(0, 0.052, 0); cNode.geometry?.materials = [mat]
            let brim = SCNCylinder(radius: HR + 0.052, height: 0.014)
            let bNode = SCNNode(geometry: brim); bNode.name = "cl_hat"
            bNode.position = SCNVector3(0, 0.006, 0); bNode.geometry?.materials = [mat]
            [cNode, bNode].forEach { headNode.addChildNode($0) }

        default: break
        }
    }

    // MARK: - Facial hair

    private func buildFacialHair(_ profile: SkaterWardrobeProfile) {
        guard profile.facial != "none" else { return }
        let hairHex = Wardrobe.hairColors.indices.contains(profile.hairColor)
                      ? Wardrobe.hairColors[profile.hairColor].hex : "#141110"
        let mat = AvatarMaterials.plain(hex: hairHex)
        let HR  = CGFloat(Dims.headR)

        switch profile.facial {
        case "stubble":
            let geo = SCNSphere(radius: HR * 0.985); geo.segmentCount = 18
            let node = SCNNode(geometry: geo); node.name = "cl_facial"
            node.scale = SCNVector3(0.96, 1, 0.98); node.position = SCNVector3(0, -0.006, 0.003)
            let stubleMat = AvatarMaterials.plain(hex: hairHex)
            stubleMat.transparency = 0.55; node.geometry?.materials = [stubleMat]
            headNode.addChildNode(node)
        case "goatee":
            let geo = SCNBox(width: 0.040, height: 0.046, length: 0.020, chamferRadius: 0.012)
            let node = SCNNode(geometry: geo); node.name = "cl_facial"
            node.position = SCNVector3(0, -0.105, HR * 0.92); node.geometry?.materials = [mat]
            headNode.addChildNode(node)
        case "beard":
            let geo = SCNSphere(radius: HR * 1.015); geo.segmentCount = 18
            let node = SCNNode(geometry: geo); node.name = "cl_facial"
            node.scale = SCNVector3(0.95, 0.82, 0.96); node.position = SCNVector3(0, -0.020, 0.004)
            node.geometry?.materials = [mat]; headNode.addChildNode(node)
        default: break
        }
    }

    // MARK: - Extras (accessories)

    private func buildExtras(_ profile: SkaterWardrobeProfile) {
        guard profile.extra.itemID != "none" else { return }
        let sel  = profile.extra
        let item = Wardrobe.store.item(key: "extra", id: sel.itemID)
        let c1   = item?.variants.indices.contains(sel.variant) == true
                   ? item!.variants[sel.variant].color1 : "#1d1e22"
        let mat  = AvatarMaterials.accessory(hex: c1)

        switch sel.itemID {
        case "shades":
            for side: Float in [-1, 1] {
                let lens = SCNBox(width: 0.050, height: 0.030, length: 0.012, chamferRadius: 0.008)
                let node = SCNNode(geometry: lens); node.name = "cl_shades"
                node.position = SCNVector3(side * 0.042, 0.003, Dims.headR * 0.92)
                node.geometry?.materials = [mat]; headNode.addChildNode(node)
            }
            let bridge = SCNBox(width: 0.016, height: 0.006, length: 0.008, chamferRadius: 0.002)
            let bNode = SCNNode(geometry: bridge); bNode.name = "cl_shades"
            bNode.position = SCNVector3(0, 0.003, Dims.headR * 0.92)
            bNode.geometry?.materials = [mat]; headNode.addChildNode(bNode)

        case "chain":
            let chainMat = AvatarMaterials.metal(hex: c1, roughness: 0.22, metalness: 1.0)
            let ring = SCNTorus(ringRadius: 0.085, pipeRadius: 0.008)
            let rNode = SCNNode(geometry: ring); rNode.name = "cl_chain"
            rNode.eulerAngles = SCNVector3(.pi/2 - 0.45, 0, 0)
            rNode.position    = SCNVector3(0, 0.285, 0.038)
            rNode.geometry?.materials = [chainMat]; chestNode.addChildNode(rNode)

        case "watch":
            let wGeo = SCNCylinder(radius: 0.050, height: 0.025)
            let wNode = SCNNode(geometry: wGeo); wNode.name = "cl_watch"
            wNode.position = SCNVector3(0, -Dims.fArmLen * 0.80, 0)
            wNode.geometry?.materials = [mat]; elbowLNode.addChildNode(wNode)

        case "phones":
            let band = SCNTorus(ringRadius: 0.100, pipeRadius: 0.012)
            let bNode = SCNNode(geometry: band); bNode.name = "cl_phones"
            bNode.eulerAngles = SCNVector3(.pi/2 - 0.20, 0, 0)
            bNode.position    = SCNVector3(0, 0.26, 0.010)
            bNode.geometry?.materials = [mat]; neckNode.addChildNode(bNode)

        default: break
        }
    }

    // MARK: - Geometry helper

    private func addMesh<G: SCNGeometry>(_ geo: G, to parent: SCNNode,
                                          at pos: SCNVector3, euler: SCNVector3 = .init(0,0,0),
                                          name: String, mat: SCNMaterial) {
        let node = SCNNode(geometry: geo)
        node.position = pos; node.eulerAngles = euler; node.name = name
        node.geometry?.materials = [mat]; node.castsShadow = true
        parent.addChildNode(node)
    }

    // MARK: - Colour math

    private func darken(_ hex: String, _ factor: Float) -> String { hex }  // UI-only tint, identity fallback
}

// MARK: - AvatarMaterials

enum AvatarMaterials {

    static func skin(hex: String) -> SCNMaterial {
        let m = base(hex)
        m.roughness.contents  = CGFloat(0.58)
        m.metalness.contents  = CGFloat(0.00)
        m.shaderModifiers = [.fragment: ShaderSrc.skin]
        return m
    }

    static func iris(hex: String) -> SCNMaterial {
        let m = base(hex)
        m.roughness.contents = CGFloat(0.10)
        m.metalness.contents = CGFloat(0.00)
        return m
    }

    static func shoe(hex: String, style: String) -> SCNMaterial {
        let m = base(hex)
        let rough: CGFloat = ["puffy", "runner"].contains(style) ? 0.70 : 0.86
        m.roughness.contents = rough
        m.shaderModifiers = [.fragment: style == "runner" ? ShaderSrc.suede : ShaderSrc.canvas]
        return m
    }

    static func sole(hex: String) -> SCNMaterial {
        let m = base(hex)
        m.roughness.contents = CGFloat(0.75)
        m.shaderModifiers = [.fragment: ShaderSrc.rubber]
        return m
    }

    static func pants(hex: String, style: String) -> SCNMaterial {
        let m = base(hex)
        m.roughness.contents = CGFloat(0.88)
        let isDenim = ["jeans", "baggy", "flames"].contains(style)
        m.shaderModifiers = [.fragment: isDenim ? ShaderSrc.denim : ShaderSrc.cloth]
        return m
    }

    static func top(hex: String, style: String) -> SCNMaterial {
        let m = base(hex)
        m.roughness.contents = CGFloat(0.90)
        let shader: String
        switch style {
        case "coach":  shader = ShaderSrc.nylon
        case "hat":    shader = ShaderSrc.ribKnit
        default:       shader = ShaderSrc.cloth
        }
        m.shaderModifiers = [.fragment: shader]
        return m
    }

    static func ribKnit(hex: String) -> SCNMaterial {
        let m = base(hex)
        m.roughness.contents = CGFloat(0.92)
        m.shaderModifiers = [.fragment: ShaderSrc.ribKnit]
        return m
    }

    static func plain(hex: String) -> SCNMaterial { base(hex) }

    static func metal(hex: String, roughness: CGFloat, metalness: CGFloat) -> SCNMaterial {
        let m = base(hex)
        m.roughness.contents = roughness
        m.metalness.contents = metalness
        return m
    }

    static func accessory(hex: String) -> SCNMaterial {
        let m = base(hex)
        m.roughness.contents = CGFloat(0.20)
        m.metalness.contents = CGFloat(0.75)
        return m
    }

    // MARK: Private

    private static func base(_ hex: String) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = UIColor(hex: hex)
        m.roughness.contents = CGFloat(0.75)
        m.metalness.contents = CGFloat(0.00)
        m.ambientOcclusion.intensity = 0.88
        return m
    }

    // MARK: Metal fragment shader modifiers

    private enum ShaderSrc {

        static let skin = """
#pragma body
float sss = 0.055;
_surface.diffuse.rgb += float3(sss * 0.80, sss * 0.45, sss * 0.28) * 0.40;
_surface.roughness    = clamp(_surface.roughness - 0.06, 0.0, 1.0);
"""
        static let cloth = """
#pragma body
float2 uv   = _surface.diffuseTexcoord * 72.0;
float wx    = sin(uv.x * 6.283185) * 0.5 + 0.5;
float wy    = sin(uv.y * 6.283185) * 0.5 + 0.5;
float weave = wx * wy * 0.040;
float seamU = step(0.47, fract(uv.x * 0.125)) * step(fract(uv.x * 0.125), 0.53) * 0.09;
float seamV = step(0.47, fract(uv.y * 0.125)) * step(fract(uv.y * 0.125), 0.53) * 0.09;
_surface.diffuse.rgb  *= 1.0 - max(seamU, seamV) + weave;
_surface.roughness    += weave * 0.07;
"""
        static let denim = """
#pragma body
float2 uv   = _surface.diffuseTexcoord * 55.0;
float twill = fract(uv.x * 0.577 + uv.y);
float line  = smoothstep(0.44, 0.49, twill) - smoothstep(0.49, 0.54, twill);
float thread= sin(uv.x * 18.84) * sin(uv.y * 18.84) * 0.030;
_surface.diffuse.rgb  *= 1.0 - line * 0.065 + thread;
_surface.roughness    += line * 0.040;
"""
        static let canvas = """
#pragma body
float2 uv = _surface.diffuseTexcoord * 85.0;
float g   = sin(uv.x * 6.28) * sin(uv.y * 6.28) * 0.022;
float seam= step(0.48, fract(uv.x * 0.5)) * step(fract(uv.x * 0.5), 0.52) * 0.10;
_surface.diffuse.rgb  *= 1.0 + g - seam;
_surface.roughness    += 0.055 + seam * 0.04;
"""
        static let suede = """
#pragma body
float2 uv = _surface.diffuseTexcoord * 110.0;
float fuzz = fract(sin(uv.x * 127.1 + uv.y * 311.7) * 43758.5) * 0.055;
_surface.diffuse.rgb  *= 1.0 + fuzz;
_surface.roughness    += 0.070;
"""
        static let rubber = """
#pragma body
float2 uv = _surface.diffuseTexcoord;
float gx  = step(0.45, fract(uv.x * 26.0));
float gy  = step(0.45, fract(uv.y * 13.0));
_surface.diffuse.rgb  *= 1.0 + gx * gy * 0.090;
_surface.roughness    += gx * gy * 0.055;
"""
        static let nylon = """
#pragma body
float2 uv = _surface.diffuseTexcoord * 45.0;
float ripstop = (step(0.48, fract(uv.x * 0.25)) + step(0.48, fract(uv.y * 0.25))) * 0.06;
_surface.roughness = 0.44 + ripstop * 0.04;
_surface.diffuse.rgb *= 1.0 + ripstop * 0.12;
"""
        static let ribKnit = """
#pragma body
float2 uv = _surface.diffuseTexcoord * 35.0;
float rib  = step(0.40, fract(uv.x * 0.5)) * 0.075;
_surface.diffuse.rgb *= 1.0 - rib;
_surface.roughness   += rib * 0.055;
"""
    }
}
#endif
