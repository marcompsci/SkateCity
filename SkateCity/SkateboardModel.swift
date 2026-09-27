// Copyright © 2026 MAR / SkateCity. All rights reserved.
// Unauthorized reproduction, distribution, or modification is strictly prohibited.

#if os(iOS)
import SceneKit
import UIKit

// MARK: - SkateboardModel

/// Realistic skateboard: deck with concave, independent truck nodes that steer,
/// four wheel nodes that spin, grip tape via shader, and deck graphic via shader.
final class SkateboardModel {

    // MARK: Public nodes

    /// Root node — attach to the physics body (boardNode).
    let boardRoot = SCNNode()

    // Deck pivot (whole visual board lives here)
    private let deckNode = SCNNode()

    // Truck pivot nodes — rotate on Y to steer
    let truckFront = SCNNode()
    let truckBack  = SCNNode()

    // Wheels — rotate on X to roll
    private(set) var wheels: [SCNNode] = []

    // Grip tape + deck graphic materials (refreshed by apply(profile:))
    private var gripMat  = SCNMaterial()
    private var deckMat  = SCNMaterial()
    private var graphicMat = SCNMaterial()

    // MARK: Geometry constants

    private let deckW:  CGFloat = 0.210
    private let deckL:  CGFloat = 0.820
    private let deckH:  CGFloat = 0.018
    private let truckZ: CGFloat = 0.300   // front/back offset from centre
    private let wheelR: CGFloat = 0.028
    private let wheelW: CGFloat = 0.024
    private let wheelX: CGFloat = 0.088   // left/right offset

    // MARK: Init

    init() {
        boardRoot.name = "SkateboardRoot"
        buildDeck()
        buildTrucks()
        buildWheels()
    }

    // MARK: Apply profile

    func apply(profile: SkaterWardrobeProfile) {
        // Deck graphic colour
        let deckSel  = profile.deck
        let deckItem = Wardrobe.boardShop.item(key: "deck", id: deckSel.itemID)
        let dc1 = deckItem?.variants.indices.contains(deckSel.variant) == true
                  ? deckItem!.variants[deckSel.variant].color1 : "#ff4f6d"
        let dc2 = deckItem?.variants.indices.contains(deckSel.variant) == true
                  ? deckItem!.variants[deckSel.variant].color2 : dc1
        graphicMat.diffuse.contents  = UIColor(hex: dc1)
        graphicMat.emission.contents = UIColor(hex: dc2).withAlphaComponent(0.12)
        graphicMat.shaderModifiers   = [.fragment: deckGraphicShader(id: deckSel.itemID, c1: dc1, c2: dc2)]

        // Grip tape
        let gripID = profile.grip
        gripMat.shaderModifiers = [.fragment: gripShader(id: gripID)]

        // Trucks
        let truckSel  = profile.trucks
        let truckItem = Wardrobe.boardShop.item(key: "trucks", id: truckSel.itemID)
        let tc = truckItem?.variants.indices.contains(truckSel.variant) == true
                 ? truckItem!.variants[truckSel.variant].color1 : "#c3cad3"
        truckFront.enumerateChildNodes { n, _ in n.geometry?.firstMaterial?.diffuse.contents = UIColor(hex: tc) }
        truckBack.enumerateChildNodes  { n, _ in n.geometry?.firstMaterial?.diffuse.contents = UIColor(hex: tc) }

        // Wheels
        let wheelSel  = profile.wheels
        let wheelItem = Wardrobe.boardShop.item(key: "wheels", id: wheelSel.itemID)
        let wc = wheelItem?.variants.indices.contains(wheelSel.variant) == true
                 ? wheelItem!.variants[wheelSel.variant].color1 : "#f6efe0"
        let wSize: Float = wheelSel.itemID == "w56" ? 1.10 : (wheelSel.itemID == "w54" ? 1.04 : 1.0)
        for w in wheels {
            w.geometry?.firstMaterial?.diffuse.contents = UIColor(hex: wc)
            w.scale = SCNVector3(wSize, wSize, wSize)
        }
    }

    // MARK: Animation helpers

    /// Spin all wheels at the given speed (rad/s × dt).
    func tickWheels(speed: Float, deltaTime: Float) {
        let angle = speed * deltaTime
        for w in wheels { w.eulerAngles.x -= angle }
    }

    /// Steer both trucks by the given normalised input (-1…1).
    func steer(input: Float) {
        let maxAngle: Float = 0.22
        let target = input * maxAngle
        truckFront.eulerAngles.y = target
        truckBack.eulerAngles.y  = -target * 0.55   // natural truck geometry
    }

    // MARK: - Deck construction

    private func buildDeck() {
        boardRoot.addChildNode(deckNode)

        // Main flat section
        makeDeckSegment(length: deckL * 0.72, zOff: 0)

        // Nose kick (front)
        let noseH: CGFloat = 0.016
        let noseSeg = SCNBox(width: deckW, height: deckH + noseH,
                             length: deckL * 0.14, chamferRadius: 0.006)
        let noseNode = SCNNode(geometry: noseSeg)
        noseNode.position = SCNVector3(0, noseH * 0.5, deckL * 0.38)
        noseNode.eulerAngles = SCNVector3(-0.28, 0, 0)
        applyDeckMaterials(to: noseSeg, isKick: true)
        deckNode.addChildNode(noseNode)

        // Tail kick (back)
        let tailH: CGFloat = 0.014
        let tailSeg = SCNBox(width: deckW, height: deckH + tailH,
                             length: deckL * 0.12, chamferRadius: 0.006)
        let tailNode = SCNNode(geometry: tailSeg)
        tailNode.position = SCNVector3(0, tailH * 0.5, -deckL * 0.36)
        tailNode.eulerAngles = SCNVector3(0.24, 0, 0)
        applyDeckMaterials(to: tailSeg, isKick: true)
        deckNode.addChildNode(tailNode)

        // Slight concave: two side-rail cylinders under the flat
        for xSide: Float in [-0.090, 0.090] {
            let rail = SCNCylinder(radius: 0.006, height: deckL * 0.70)
            rail.radialSegmentCount = 10
            let railNode = SCNNode(geometry: rail)
            railNode.position    = SCNVector3(xSide, Float(-deckH * 0.38), 0)
            railNode.eulerAngles = SCNVector3(0, 0, 0)
            railNode.geometry?.materials = [woodMaterial()]
            deckNode.addChildNode(railNode)
        }

        deckNode.position = SCNVector3(0, 0, 0)
    }

    private func makeDeckSegment(length: CGFloat, zOff: Float) {
        let geo = SCNBox(width: deckW, height: deckH, length: length, chamferRadius: 0.007)
        let node = SCNNode(geometry: geo)
        node.position = SCNVector3(0, 0, zOff)
        applyDeckMaterials(to: geo, isKick: false)
        deckNode.addChildNode(node)
    }

    private func applyDeckMaterials(to geo: SCNBox, isKick: Bool) {
        // Faces: +X, -X, +Y (grip), -Y (graphic), +Z, -Z
        gripMat = makePBR(UIColor(white: 0.12, alpha: 1), roughness: 1.0, metalness: 0)
        gripMat.shaderModifiers = [.fragment: gripShader(id: "black")]

        graphicMat = makePBR(UIColor(hex: "#ff4f6d"), roughness: 0.45, metalness: 0)
        let sideMat = woodMaterial()

        // top=grip, bottom=graphic, sides=wood
        geo.materials = [sideMat, sideMat, gripMat, graphicMat, sideMat, sideMat]
    }

    private func woodMaterial() -> SCNMaterial {
        makePBR(UIColor(hex: "#d8b98a"), roughness: 0.70, metalness: 0)
    }

    // MARK: - Truck construction

    private func buildTrucks() {
        for (truck, zOff) in [(truckFront, truckZ), (truckBack, -truckZ)] {
            truck.position = SCNVector3(0, -deckH * 0.5, zOff)
            deckNode.addChildNode(truck)

            // Base plate
            let base = SCNBox(width: 0.064, height: 0.012, length: 0.082, chamferRadius: 0.003)
            let baseNode = SCNNode(geometry: base); baseNode.name = "truck_base"
            baseNode.geometry?.materials = [truckMat()]
            truck.addChildNode(baseNode)

            // Hanger (axle bar)
            let hanger = SCNCylinder(radius: 0.013, height: 0.194)
            hanger.radialSegmentCount = 10
            let hangerNode = SCNNode(geometry: hanger); hangerNode.name = "truck_hanger"
            hangerNode.eulerAngles = SCNVector3(0, 0, Float.pi/2)
            hangerNode.position    = SCNVector3(0, -0.022, 0)
            hangerNode.geometry?.materials = [truckMat()]
            truck.addChildNode(hangerNode)

            // Kingpin
            let kp = SCNCylinder(radius: 0.005, height: 0.034)
            kp.radialSegmentCount = 6
            let kpNode = SCNNode(geometry: kp); kpNode.name = "truck_kingpin"
            kpNode.position = SCNVector3(0, -0.010, 0.012)
            kpNode.geometry?.materials = [truckMat()]
            truck.addChildNode(kpNode)

            // Pivot cup (small sphere)
            let piv = SCNSphere(radius: 0.008); piv.segmentCount = 8
            let pivNode = SCNNode(geometry: piv); pivNode.name = "truck_pivot"
            pivNode.position = SCNVector3(0, -0.018, -0.016)
            pivNode.geometry?.materials = [makePBR(UIColor(hex: "#cc7722"), roughness: 0.5, metalness: 0)]
            truck.addChildNode(pivNode)

            // Bolts (×4)
            for bx: Float in [-0.018, 0.018] {
                for bz: Float in [-0.016, 0.016] {
                    let bolt = SCNCylinder(radius: 0.003, height: 0.016)
                    bolt.radialSegmentCount = 6
                    let bn = SCNNode(geometry: bolt); bn.position = SCNVector3(bx, 0.006, bz)
                    bn.geometry?.materials = [makePBR(UIColor(hex: "#aaaaaa"), roughness: 0.3, metalness: 0.9)]
                    truck.addChildNode(bn)
                }
            }
        }
    }

    private func truckMat() -> SCNMaterial {
        makePBR(UIColor(hex: "#c3cad3"), roughness: 0.32, metalness: 0.88)
    }

    // MARK: - Wheels

    private func buildWheels() {
        for (truck, zOff) in [(truckFront, truckZ), (truckBack, -truckZ)] {
            for xSide: Float in [-1, 1] {
                let wheelGeo = SCNCylinder(radius: wheelR, height: wheelW)
                wheelGeo.radialSegmentCount = 18

                let innerMat = makePBR(UIColor(hex: "#f6efe0"), roughness: 0.50, metalness: 0)
                innerMat.shaderModifiers = [SCNShaderModifierEntryPoint.fragment: wheelShader()]
                let sideMat  = makePBR(UIColor(hex: "#e8e0ce"), roughness: 0.55, metalness: 0)

                // Hub circles on both ends
                let hubGeo = SCNCylinder(radius: wheelR * 0.36, height: wheelW + 0.002)
                hubGeo.radialSegmentCount = 12
                let hubMat = makePBR(UIColor(hex: "#c3cad3"), roughness: 0.30, metalness: 0.80)
                let hubNode = SCNNode(geometry: hubGeo)
                hubNode.geometry?.materials = [hubMat]

                wheelGeo.materials = [innerMat, sideMat, sideMat]

                let wNode = SCNNode(geometry: wheelGeo)
                wNode.name = "wheel"
                wNode.eulerAngles = SCNVector3(0, 0, Float.pi/2)
                wNode.position    = SCNVector3(xSide * Float(wheelX), -0.022, Float(zOff))
                hubNode.position  = .init(0, 0, 0)
                wNode.addChildNode(hubNode)

                truck.addChildNode(wNode)
                wheels.append(wNode)
            }
        }
    }

    // MARK: - Shader sources

    private func gripShader(id: String) -> String {
        let speckle = id == "speckle"
        let split   = id == "split"
        let logo    = id == "logo"
        return """
#pragma body
float2 uv = _surface.diffuseTexcoord;
float grain = fract(sin(uv.x * 5821.3 + uv.y * 3947.7) * 43758.5) * 0.07;
_surface.diffuse.rgb = float3(0.12, 0.12, 0.13) + float3(grain);
_surface.roughness   = 1.0;
""" + (speckle ? """
float spk = step(0.94, fract(sin(uv.x * 8921.3 + uv.y * 6547.1) * 93758.5));
float3 cols[4] = {float3(1,0.31,0.43), float3(1,0.82,0.24), float3(0.18,0.72,1), float3(0.95,0.94,0.91)};
_surface.diffuse.rgb = mix(_surface.diffuse.rgb, cols[int(fract(sin(uv.x*uv.y*9.9)*99.9)*4.0)], spk);
""" : "") + (split ? """
float band = step(0.43, uv.y) * step(uv.y, 0.48);
_surface.diffuse.rgb = mix(_surface.diffuse.rgb, float3(0.94), band * 0.9);
""" : "") + (logo ? """
float2 c = uv - 0.5; float r = length(c);
float ring = step(0.28, r) * step(r, 0.30);
_surface.diffuse.rgb = mix(_surface.diffuse.rgb, float3(0.85, 0.73, 0.54), ring);
""" : "")
    }

    private func deckGraphicShader(id: String, c1: String, c2: String) -> String {
        // Nose/tail darkening gradient is universal; pattern varies by id
        let pattern: String
        switch id {
        case "checker":
            pattern = """
float cx = step(0.5, fract(uv.x * 8.0));
float cy = step(0.5, fract(uv.y * 32.0));
float chk = abs(cx - cy);
_surface.diffuse.rgb = mix(_surface.diffuse.rgb, float3(0.95, 0.94, 0.91), chk * 0.92);
"""
        case "sunset":
            pattern = """
_surface.diffuse.rgb = mix(_surface.diffuse.rgb, float3(0.42, 0.18, 0.62), clamp(uv.y * 1.8, 0.0, 1.0));
float sun = step(0.38, 1.0-length((uv - float2(0.5, 0.62))*float2(4.0,2.0)));
_surface.diffuse.rgb = mix(_surface.diffuse.rgb, float3(1.0, 0.95, 0.78), sun);
"""
        case "grid":
            pattern = """
float lx = step(0.97, fract(uv.x * 6.0));
float ly = step(0.97, fract(uv.y * 24.0));
float grid = max(lx, ly);
_surface.diffuse.rgb = mix(_surface.diffuse.rgb, float3(1,0,1), grid * 0.9);
"""
        case "tiger":
            pattern = """
float stripe = step(0.4, sin((uv.x + uv.y) * 18.0) * 0.5 + 0.5);
_surface.diffuse.rgb = mix(_surface.diffuse.rgb, float3(0.12, 0.11, 0.13), stripe * 0.88);
"""
        case "wave":
            pattern = """
float wave = sin(uv.x * 12.56 + uv.y * 4.0) * 0.08 + uv.y;
float band = step(0.40, fract(wave * 3.5));
_surface.diffuse.rgb = mix(_surface.diffuse.rgb, float3(0.95, 0.97, 1.0), band * 0.55);
"""
        default:
            pattern = ""
        }
        return """
#pragma body
float2 uv = _surface.diffuseTexcoord;
\(pattern)
// Nose/tail kick darkening
float noseTail = (1.0 - smoothstep(0.35, 0.50, abs(uv.y - 0.5) * 2.0));
_surface.diffuse.rgb *= (0.82 + noseTail * 0.18);
// Edge wrap darkening
float edgeX = 1.0 - smoothstep(0.40, 0.50, abs(uv.x - 0.5) * 2.0);
_surface.diffuse.rgb *= (0.88 + edgeX * 0.12);
_surface.roughness = 0.45;
"""
    }

    private func wheelShader() -> String {
        """
#pragma body
float2 uv = _surface.diffuseTexcoord;
// Urethane ridge pattern
float ridge = step(0.45, sin(uv.y * 94.0) * 0.5 + 0.5) * 0.06;
_surface.diffuse.rgb *= 1.0 + ridge;
_surface.roughness   = clamp(_surface.roughness + ridge * 0.08, 0.0, 1.0);
"""
    }

    // MARK: - Material helper

    private func makePBR(_ color: UIColor, roughness: CGFloat, metalness: CGFloat) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel      = .physicallyBased
        m.diffuse.contents   = color
        m.roughness.contents = roughness
        m.metalness.contents = metalness
        return m
    }
}
#endif
