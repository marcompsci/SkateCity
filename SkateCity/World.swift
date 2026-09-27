//  World.swift
//  Builds "SkateCity Plaza": a downtown skate plaza (kickers, funbox, ledges, rails, stair set,
//  quarter pipes, manual pad) surrounded by a live city — road with traffic, sidewalks with
//  pedestrians, streetlights, trees and a skyline of lit buildings at golden hour.
// Copyright © 2026 MAR / SkateCity. All rights reserved.
// Unauthorized reproduction, distribution, or modification is strictly prohibited.

import SceneKit
import UIKit
import simd

struct Rail {
    enum Kind { case rail, ledge, coping }
    let a: SIMD3<Float>
    let b: SIMD3<Float>
    let kind: Kind
}

@MainActor
final class Car {
    let node: SCNNode
    private var s: Float
    private let speed: Float
    private let half: Float
    private let clockwise: Bool
    private(set) var position = SIMD3<Float>(0, 0, 0)

    init(node: SCNNode, start: Float, speed: Float, half: Float, clockwise: Bool) {
        self.node = node; self.s = start; self.speed = speed; self.half = half; self.clockwise = clockwise
    }

    func update(_ dt: Float) {
        let side = half * 2
        s = (s + speed * dt).truncatingRemainder(dividingBy: side * 4)
        let seg = Int(s / side)
        let t = s - Float(seg) * side - half
        var p: SIMD3<Float>, d: SIMD3<Float>
        switch seg {
        case 0: p = SIMD3(t, 0, -half); d = SIMD3(1, 0, 0)
        case 1: p = SIMD3(half, 0, t); d = SIMD3(0, 0, 1)
        case 2: p = SIMD3(-t, 0, half); d = SIMD3(-1, 0, 0)
        default: p = SIMD3(-half, 0, -t); d = SIMD3(0, 0, -1)
        }
        if !clockwise { p.x = -p.x; d.x = -d.x }
        position = p
        node.simdPosition = p
        node.simdEulerAngles = SIMD3(0, atan2(d.x, d.z), 0)
    }
}

@MainActor
final class Walker {
    let node = SCNNode()
    let body: Humanoid
    private let a: SIMD3<Float>, b: SIMD3<Float>
    private var t: Float
    private var dir: Float = 1
    private var phase: Float = 0
    private let speed: Float

    init(style: SkaterStyle, from a: SIMD3<Float>, to b: SIMD3<Float>, start: Float, speed: Float) {
        self.a = a; self.b = b; self.t = start; self.speed = speed
        body = Humanoid(style: style)
        node.addChildNode(body.root)
    }

    func update(_ dt: Float) {
        let len = simd_distance(a, b)
        t += dir * speed * dt / len
        if t > 1 { t = 1; dir = -1 }
        if t < 0 { t = 0; dir = 1 }
        phase += dt * speed * 5.2
        node.simdPosition = lerp3(a, b, t)
        let d = (b - a) * dir
        node.simdEulerAngles = SIMD3(0, atan2(-d.z, d.x), 0)
        body.walk(phase: phase)
    }
}

@MainActor
final class World {
    let root = SCNNode()
    private(set) var rails: [Rail] = []
    private(set) var letterNodes: [SCNNode] = []
    private(set) var cars: [Car] = []
    private(set) var walkers: [Walker] = []
    let spawn = SIMD3<Float>(0, 0, -30)
    let bounds: Float = 65.5

    private let tex: TextureCache
    private var rng: UInt64 = 0x5EED_CAFE

    private func random() -> Float {
        rng = rng &* 6364136223846793005 &+ 1442695040888963407
        return Float((rng >> 33) & 0xFFFFFF) / Float(0xFFFFFF)
    }

    init() {
        tex = TextureCache.shared
        tex.warmUp()
        buildGround()
        buildPlaza()
        buildCity()
        buildLetters()
    }

    // MARK: Helpers

    @discardableResult
    private func add(_ mb: MeshBuilder, _ mat: SCNMaterial, at pos: SIMD3<Float> = SIMD3(0, 0, 0), yaw: Float = 0,
                     solid: Bool = true, shadow: Bool = true) -> SCNNode {
        let node = SCNNode(geometry: mb.geometry(mat))
        node.simdPosition = pos
        node.simdEulerAngles = SIMD3(0, yaw, 0)
        if solid { node.categoryBitMask = 1 | solidCategory }
        node.castsShadow = shadow
        root.addChildNode(node)
        return node
    }

    private func toWorld(_ p: SIMD3<Float>, _ pos: SIMD3<Float>, _ yaw: Float) -> SIMD3<Float> {
        SIMD3(p.x * cos(yaw) + p.z * sin(yaw), p.y, -p.x * sin(yaw) + p.z * cos(yaw)) + pos
    }

    private func box(_ center: SIMD3<Float>, _ size: SIMD3<Float>, _ mat: SCNMaterial, grindEdges: Bool = false) {
        var mb = MeshBuilder()
        mb.addBox(center: center, size: size)
        add(mb, mat)
        guard grindEdges else { return }
        let top = center.y + size.y / 2
        let h = size / 2
        if size.x >= size.z {
            rails.append(Rail(a: SIMD3(center.x - h.x, top, center.z - h.z), b: SIMD3(center.x + h.x, top, center.z - h.z), kind: .ledge))
            rails.append(Rail(a: SIMD3(center.x - h.x, top, center.z + h.z), b: SIMD3(center.x + h.x, top, center.z + h.z), kind: .ledge))
        }
        if size.z >= size.x {
            rails.append(Rail(a: SIMD3(center.x - h.x, top, center.z - h.z), b: SIMD3(center.x - h.x, top, center.z + h.z), kind: .ledge))
            rails.append(Rail(a: SIMD3(center.x + h.x, top, center.z - h.z), b: SIMD3(center.x + h.x, top, center.z + h.z), kind: .ledge))
        }
    }

    private lazy var metal = Materials.color(UIColor(white: 0.55, alpha: 1), rough: 0.28, metal: 1)
    private lazy var paintedMetal = Materials.color(UIColor(red: 0.95, green: 0.75, blue: 0.1, alpha: 1), rough: 0.35, metal: 0.6)

    private func pipe(from a: SIMD3<Float>, to b: SIMD3<Float>, radius: CGFloat, _ mat: SCNMaterial, solid: Bool = false) {
        let len = simd_distance(a, b)
        let g = SCNCylinder(radius: radius, height: CGFloat(len))
        g.materials = [mat]
        let n = SCNNode(geometry: g)
        n.simdPosition = (a + b) / 2
        n.simdOrientation = quatFromTo(SIMD3(0, 1, 0), simd_normalize(b - a))
        n.castsShadow = true
        if solid { n.categoryBitMask = 1 | solidCategory }
        root.addChildNode(n)
    }

    /// A grindable rail with posts.
    private func rail(_ a: SIMD3<Float>, _ b: SIMD3<Float>, groundA: Float = 0, groundB: Float = 0, mat: SCNMaterial? = nil) {
        let m = mat ?? paintedMetal
        pipe(from: a, to: b, radius: 0.03, m)
        pipe(from: SIMD3(a.x, groundA, a.z), to: a, radius: 0.025, m)
        pipe(from: SIMD3(b.x, groundB, b.z), to: b, radius: 0.025, m)
        rails.append(Rail(a: a + SIMD3(0, 0.03, 0), b: b + SIMD3(0, 0.03, 0), kind: .rail))
    }

    private func wedge(at pos: SIMD3<Float>, yaw: Float, width: Float, length: Float, height: Float) {
        var mb = MeshBuilder()
        mb.addWedge(width: width, length: length, height: height)
        add(mb, tex.ramp, at: pos, yaw: yaw)
        // steel plate on the lip for looks
        let lipA = toWorld(SIMD3(-width / 2, height, length), pos, yaw)
        let lipB = toWorld(SIMD3(width / 2, height, length), pos, yaw)
        pipe(from: lipA, to: lipB, radius: 0.02, metal)
    }

    private func quarterPipe(at pos: SIMD3<Float>, yaw: Float, width: Float) {
        var mb = MeshBuilder()
        let r = mb.addQuarterPipe(width: width, radius: 3.6, maxAngle: 1.13, deck: 1.6)
        add(mb, tex.ramp, at: pos, yaw: yaw)
        let a = toWorld(SIMD3(-width / 2, r.height, r.lipZ), pos, yaw)
        let b = toWorld(SIMD3(width / 2, r.height, r.lipZ), pos, yaw)
        pipe(from: a, to: b, radius: 0.045, metal)
        rails.append(Rail(a: a + SIMD3(0, 0.04, 0), b: b + SIMD3(0, 0.04, 0), kind: .coping))
    }

    // MARK: Ground

    private func buildGround() {
        var g = MeshBuilder()
        g.addPlane(center: SIMD3(0, -0.02, 0), width: 700, depth: 700)
        add(g, tex.asphalt, shadow: false)

        var plaza = MeshBuilder()
        plaza.addPlane(center: SIMD3(0, 0, 0), width: 100, depth: 100)
        add(plaza, tex.concrete, shadow: false)

        // Road paint: dashed centre line + edge lines around the plaza block
        let paint = Materials.color(UIColor(white: 0.92, alpha: 1), rough: 0.55)
        let yellow = Materials.color(UIColor(red: 0.95, green: 0.78, blue: 0.2, alpha: 1), rough: 0.55)
        var dashes = MeshBuilder(), edges = MeshBuilder()
        var s: Float = -52
        while s < 52 {
            dashes.addPlane(center: SIMD3(s + 1.5, -0.012, -55), width: 3, depth: 0.15)
            dashes.addPlane(center: SIMD3(s + 1.5, -0.012, 55), width: 3, depth: 0.15)
            dashes.addPlane(center: SIMD3(-55, -0.012, s + 1.5), width: 0.15, depth: 3)
            dashes.addPlane(center: SIMD3(55, -0.012, s + 1.5), width: 0.15, depth: 3)
            s += 6
        }
        for d: Float in [50.6, 59.4] {
            edges.addPlane(center: SIMD3(0, -0.012, d), width: 2 * d, depth: 0.12)
            edges.addPlane(center: SIMD3(0, -0.012, -d), width: 2 * d, depth: 0.12)
            edges.addPlane(center: SIMD3(d, -0.012, 0), width: 0.12, depth: 2 * d)
            edges.addPlane(center: SIMD3(-d, -0.012, 0), width: 0.12, depth: 2 * d)
        }
        add(dashes, yellow, solid: false, shadow: false)
        add(edges, paint, solid: false, shadow: false)

        // Raised sidewalks (curbs) 60–66 m
        for (c, sz) in [(SIMD3<Float>(0, 0.06, 63), SIMD3<Float>(132, 0.12, 6)),
                        (SIMD3<Float>(0, 0.06, -63), SIMD3<Float>(132, 0.12, 6)),
                        (SIMD3<Float>(63, 0.06, 0), SIMD3<Float>(6, 0.12, 120)),
                        (SIMD3<Float>(-63, 0.06, 0), SIMD3<Float>(6, 0.12, 120))] {
            var mb = MeshBuilder()
            mb.addBox(center: c, size: sz)
            add(mb, tex.sidewalk, shadow: false)
        }
    }

    // MARK: Plaza

    private func buildPlaza() {
        // Kickers near spawn
        wedge(at: SIMD3(6, 0, -10), yaw: 0, width: 2.6, length: 2.6, height: 1.0)
        wedge(at: SIMD3(-6, 0, -10), yaw: 0, width: 2.6, length: 2.6, height: 1.0)

        // Funbox with banks on both ends, ledge edges grindable
        box(SIMD3(0, 0.4, 5), SIMD3(6, 0.8, 4), tex.concrete, grindEdges: true)
        wedge(at: SIMD3(0, 0, 0.6), yaw: 0, width: 6, length: 2.4, height: 0.8)
        wedge(at: SIMD3(0, 0, 9.4), yaw: .pi, width: 6, length: 2.4, height: 0.8)

        // Flat bar
        rail(SIMD3(-12, 0.45, -4), SIMD3(-12, 0.45, 4))

        // Manual pad
        box(SIMD3(-14, 0.125, -18), SIMD3(3, 0.25, 6), tex.concrete, grindEdges: true)

        // Granite ledges
        box(SIMD3(12, 0.25, -2), SIMD3(0.6, 0.5, 10), tex.concrete, grindEdges: true)
        box(SIMD3(16, 0.225, 14), SIMD3(8, 0.45, 0.6), tex.concrete, grindEdges: true)

        // Raised platform + 3-stair + handrails + banks
        box(SIMD3(0, 0.6, 35), SIMD3(20, 1.2, 10), tex.concrete)
        for i in 0..<3 {
            let top = Float(i + 1) * 0.3
            let zStart = 27.6 + Float(i) * 0.8
            box(SIMD3(0, top / 2, (zStart + 30) / 2), SIMD3(4, top, 30 - zStart), tex.concrete)
        }
        for x: Float in [-2.3, 2.3] {
            rail(SIMD3(x, 0.85, 26.8), SIMD3(x, 2.2, 30.4), groundA: 0, groundB: 1.2)
        }
        wedge(at: SIMD3(6.5, 0, 24), yaw: 0, width: 5, length: 6, height: 1.2)
        wedge(at: SIMD3(-6.5, 0, 24), yaw: 0, width: 5, length: 6, height: 1.2)
        box(SIMD3(0, 1.425, 36.5), SIMD3(14, 0.45, 0.6), tex.concrete, grindEdges: true)

        // Quarter pipes: east, west, south
        quarterPipe(at: SIMD3(26, 0, 0), yaw: .pi / 2, width: 16)
        quarterPipe(at: SIMD3(-26, 0, 0), yaw: -.pi / 2, width: 16)
        quarterPipe(at: SIMD3(0, 0, -44), yaw: .pi, width: 22)

        // Graffiti wall
        let wall = SCNBox(width: 0.4, height: 3, length: 16, chamferRadius: 0.02)
        let art = SCNMaterial()
        art.lightingModel = .physicallyBased
        art.diffuse.contents = tex.graffiti
        art.roughness.contents = NSNumber(value: 0.75)
        let plain = Materials.color(UIColor(white: 0.5, alpha: 1), rough: 0.85)
        wall.materials = [plain, art, plain, art, plain, plain]
        let wallNode = SCNNode(geometry: wall)
        wallNode.simdPosition = SIMD3(-22, 1.5, 20)
        wallNode.categoryBitMask = 1 | solidCategory
        wallNode.castsShadow = true
        root.addChildNode(wallNode)

        // Planters with trees (planter edges are grindable)
        let spots: [SIMD2<Float>] = [
            SIMD2(-44, -35), SIMD2(-44, -15), SIMD2(-44, 15), SIMD2(-44, 35),
            SIMD2(44, -35), SIMD2(44, -15), SIMD2(44, 15), SIMD2(44, 35),
            SIMD2(-40, 46), SIMD2(-25, 46), SIMD2(25, 46), SIMD2(40, 46),
            SIMD2(-30, -47), SIMD2(30, -47)
        ]
        for s in spots { tree(at: SIMD3(s.x, 0, s.y)) }
    }

    private func tree(at p: SIMD3<Float>) {
        box(p + SIMD3(0, 0.25, 0), SIMD3(2.4, 0.5, 2.4), tex.concrete, grindEdges: true)
        var soil = MeshBuilder()
        soil.addPlane(center: p + SIMD3(0, 0.505, 0), width: 2.1, depth: 2.1)
        add(soil, tex.grass, solid: false, shadow: false)

        let bark = Materials.color(UIColor(red: 0.3, green: 0.22, blue: 0.16, alpha: 1), rough: 0.9)
        let trunkH: Float = 3 + random() * 1.5
        pipe(from: p + SIMD3(0, 0.5, 0), to: p + SIMD3(0, trunkH, 0), radius: 0.14, bark)
        let leaf = Materials.color(UIColor(red: 0.2 + CGFloat(random()) * 0.1, green: 0.38, blue: 0.12, alpha: 1), rough: 0.85)
        for _ in 0..<5 {
            let r = CGFloat(1.1 + random() * 0.9)
            let s = SCNSphere(radius: r)
            s.segmentCount = 14
            s.materials = [leaf]
            let n = SCNNode(geometry: s)
            n.simdPosition = p + SIMD3((random() - 0.5) * 2, trunkH + random() * 1.2, (random() - 0.5) * 2)
            n.castsShadow = true
            root.addChildNode(n)
        }
    }

    // MARK: City

    private func buildCity() {
        // Buildings on four sides
        for side in 0..<4 {
            var x: Float = -80
            while x < 80 {
                let w = 10 + random() * 9
                let h = 14 + random() * 36
                let depth: Float = 14
                let center = SIMD3<Float>(x + w / 2, 0, 67 + depth / 2)
                let yaw = Float(side) * .pi / 2
                var mb = MeshBuilder()
                mb.addBox(center: SIMD3(0, h / 2, 0), size: SIMD3(w - 0.6, h, depth))
                let mat = tex.facades[Int(random() * 3) % 3]
                add(mb, mat, at: toWorld(center, .zero, yaw), yaw: yaw)
                var roof = MeshBuilder()
                roof.addBox(center: SIMD3(0, h + 0.4, 0), size: SIMD3(w - 0.2, 0.8, depth + 0.4))
                if random() > 0.5 { roof.addBox(center: SIMD3((random() - 0.5) * 4, h + 1.8, 0), size: SIMD3(3, 2, 3)) }
                add(roof, tex.roof, at: toWorld(center, .zero, yaw), yaw: yaw, solid: false)
                x += w + random() * 1.5
            }
        }

        // Streetlights
        let pole = Materials.color(UIColor(white: 0.18, alpha: 1), rough: 0.5, metal: 0.8)
        let bulb = Materials.color(.black, rough: 0.3, emission: UIColor(red: 1, green: 0.85, blue: 0.6, alpha: 1))
        var d: Float = -45
        while d <= 45 {
            for side in 0..<4 {
                let yaw = Float(side) * .pi / 2
                let base = toWorld(SIMD3(d, 0, 60.6), .zero, yaw)
                let top = base + SIMD3(0, 7, 0)
                let armEnd = toWorld(SIMD3(d, 7, 58.4), .zero, yaw)
                pipe(from: base, to: top, radius: 0.09, pole, solid: true)
                pipe(from: top, to: armEnd, radius: 0.05, pole)
                let lamp = SCNNode(geometry: SCNBox(width: 0.5, height: 0.12, length: 0.3, chamferRadius: 0.04))
                lamp.geometry?.materials = [bulb]
                lamp.simdPosition = armEnd - SIMD3(0, 0.08, 0)
                root.addChildNode(lamp)
            }
            d += 22.5
        }

        // Traffic
        let paints: [UIColor] = [.systemRed, .white, .black, .systemBlue, UIColor(red: 0.2, green: 0.3, blue: 0.25, alpha: 1), .systemYellow]
        for i in 0..<6 {
            let cw = i % 2 == 0
            let node = makeCar(paint: paints[i % paints.count])
            root.addChildNode(node)
            let car = Car(node: node, start: Float(i) * 70, speed: 8 + random() * 5, half: cw ? 53.5 : 56.5, clockwise: cw)
            cars.append(car)
            car.update(0)
        }

        // Pedestrians on the sidewalks
        let people: [SkaterStyle] = SkaterStyle.roster
        for i in 0..<12 {
            let side = i % 4
            let yaw = Float(side) * .pi / 2
            let off = (random() - 0.5) * 80
            let lane: Float = 62 + random() * 2.5
            let a = toWorld(SIMD3(off - 12, 0.12, lane), .zero, yaw)
            let b = toWorld(SIMD3(off + 12, 0.12, lane), .zero, yaw)
            let w = Walker(style: people[i % people.count], from: a, to: b, start: random(), speed: 1.1 + random() * 0.5)
            root.addChildNode(w.node)
            walkers.append(w)
        }
    }

    private func makeCar(paint: UIColor) -> SCNNode {
        let car = SCNNode()
        let body = Materials.color(paint, rough: 0.18, metal: 0.7)
        body.clearCoat.contents = NSNumber(value: 1)
        let glass = Materials.color(UIColor(white: 0.05, alpha: 1), rough: 0.05, metal: 0.2)
        let tire = Materials.color(UIColor(white: 0.06, alpha: 1), rough: 0.9)
        let head = Materials.color(.white, rough: 0.2, emission: UIColor(white: 1, alpha: 1))
        let tail = Materials.color(.red, rough: 0.2, emission: UIColor(red: 1, green: 0, blue: 0, alpha: 1))

        func part(_ w: CGFloat, _ h: CGFloat, _ l: CGFloat, _ pos: SIMD3<Float>, _ m: SCNMaterial, chamfer: CGFloat = 0.12) {
            let g = SCNBox(width: w, height: h, length: l, chamferRadius: chamfer)
            g.materials = [m]
            let n = SCNNode(geometry: g)
            n.simdPosition = pos
            n.castsShadow = true
            car.addChildNode(n)
        }
        part(1.85, 0.7, 4.4, SIMD3(0, 0.65, 0), body)
        part(1.6, 0.55, 2.3, SIMD3(0, 1.22, -0.25), glass, chamfer: 0.2)
        part(0.35, 0.1, 0.05, SIMD3(0.65, 0.75, 2.2), head, chamfer: 0.02)
        part(0.35, 0.1, 0.05, SIMD3(-0.65, 0.75, 2.2), head, chamfer: 0.02)
        part(0.4, 0.1, 0.05, SIMD3(0.62, 0.8, -2.2), tail, chamfer: 0.02)
        part(0.4, 0.1, 0.05, SIMD3(-0.62, 0.8, -2.2), tail, chamfer: 0.02)
        for x: Float in [0.85, -0.85] {
            for z: Float in [1.4, -1.4] {
                let g = SCNCylinder(radius: 0.34, height: 0.25)
                g.materials = [tire]
                let n = SCNNode(geometry: g)
                n.simdEulerAngles = SIMD3(0, 0, .pi / 2)
                n.simdPosition = SIMD3(x, 0.34, z)
                car.addChildNode(n)
            }
        }
        return car
    }

    // MARK: S-K-A-T-E letters

    private func buildLetters() {
        let spots: [SIMD3<Float>] = [
            SIMD3(6, 3.0, -6.5),    // S: air off the east kicker
            SIMD3(0, 2.3, 5),       // K: over the funbox
            SIMD3(-12, 1.5, 0),     // A: over the flat bar
            SIMD3(0, 2.8, 27.5),    // T: gap the stair set
            SIMD3(29.3, 4.6, 0)     // E: vert air on the east quarter pipe
        ]
        let gold = Materials.color(UIColor(red: 1, green: 0.8, blue: 0.2, alpha: 1), rough: 0.2, metal: 1,
                                   emission: UIColor(red: 0.6, green: 0.4, blue: 0.05, alpha: 1))
        for (i, ch) in ["S", "K", "A", "T", "E"].enumerated() {
            let t = SCNText(string: ch, extrusionDepth: 2)
            t.font = UIFont.systemFont(ofSize: 10, weight: .black)
            t.flatness = 0.1
            t.chamferRadius = 0.4
            t.materials = [gold]
            let n = SCNNode(geometry: t)
            let (mn, mx) = n.boundingBox
            n.pivot = SCNMatrix4MakeTranslation((mn.x + mx.x) / 2, (mn.y + mx.y) / 2, (mn.z + mx.z) / 2)
            n.simdScale = SIMD3(repeating: 0.08)
            let holder = SCNNode()
            holder.simdPosition = spots[i]
            holder.addChildNode(n)
            root.addChildNode(holder)
            letterNodes.append(holder)
        }
    }
}
