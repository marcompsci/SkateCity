// Copyright © 2026 MAR / SkateCity. All rights reserved.
// Unauthorized reproduction, distribution, or modification is strictly prohibited.

import SceneKit

/// Procedural geometry builder for the Bay Area skatepark level.
/// Provides a SF SoMa Street Zone and a Lake Cunningham full-pipe vert section,
/// intended to be loaded via SkateMapLoader ODR when the player selects this map.
///
/// Falls back to pure SceneKit primitives when the .scn ODR asset isn't available,
/// so the level is always playable during development.
enum SkateParkBuilder {

    // MARK: - Entry point

    /// Populates `scene` with Bay Area geometry; returns grindable nodes.
    @discardableResult
    static func build(into scene: SCNScene) -> [SCNNode] {
        var grindables: [SCNNode] = []
        addGround(to: scene)
        grindables += buildSoMaStreetZone(in: scene)
        buildCunninghamVertZone(in: scene)
        addGoldenHourLighting(to: scene)
        return grindables
    }

    // MARK: - Ground

    private static func addGround(to scene: SCNScene) {
        let floor = SCNFloor()
        floor.reflectivity = 0.06
        let node = SCNNode(geometry: floor)
        node.name = "street"
        node.physicsBody = SCNPhysicsBody(type: .static, shape: nil)
        scene.rootNode.addChildNode(node)
    }

    // MARK: - SoMa Street Zone

    private static func buildSoMaStreetZone(in scene: SCNScene) -> [SCNNode] {
        var grindables: [SCNNode] = []
        let hub = SCNNode()
        hub.name = "SF_Street_Zone"
        hub.position = SCNVector3(0, 0, 0)

        // Main SoMa ledge
        let ledgeGeo = SCNBox(width: 1.5, height: 0.6, length: 8.0, chamferRadius: 0.05)
        let ledge    = SCNNode(geometry: ledgeGeo)
        ledge.name   = "ledge"
        ledge.position = SCNVector3(-2.0, 0.3, 4.0)
        ledge.physicsBody = SCNPhysicsBody(
            type: .static,
            shape: SCNPhysicsShape(
                geometry: ledgeGeo,
                options: [.type: SCNPhysicsShape.ShapeType.concavePolyhedron]
            )
        )
        ledge.physicsBody?.friction = 0.35
        hub.addChildNode(ledge)
        grindables.append(ledge)

        // Granite bench (right plaza)
        let benchGeo  = SCNBox(width: 0.45, height: 0.48, length: 2.4, chamferRadius: 0.03)
        let bench     = SCNNode(geometry: benchGeo)
        bench.name    = "bench"
        bench.position = SCNVector3(2.5, 0.24, 3.0)
        bench.physicsBody = SCNPhysicsBody(type: .static, shape: nil)
        bench.physicsBody?.friction = 0.35
        hub.addChildNode(bench)
        grindables.append(bench)

        // 3-step stair set
        for i in 0..<3 {
            let h   = CGFloat(0.20 * Double(i + 1))
            let geo = SCNBox(width: 3, height: h, length: 0.55, chamferRadius: 0)
            let step = SCNNode(geometry: geo)
            step.name     = "stairs"
            step.position = SCNVector3(-4.5, Float(h / 2), Float(-Double(i) * 0.55))
            step.physicsBody = SCNPhysicsBody(type: .static, shape: nil)
            hub.addChildNode(step)
        }

        // Hubba rail beside the stair set
        let hubbaGeo  = SCNBox(width: 0.06, height: 0.06, length: 2.1, chamferRadius: 0.01)
        let hubba     = SCNNode(geometry: hubbaGeo)
        hubba.name    = "rail"
        hubba.position = SCNVector3(-3.4, 0.48, -0.8)
        hubba.eulerAngles = SCNVector3(-0.30, 0, 0)
        hubba.physicsBody = SCNPhysicsBody(type: .static, shape: nil)
        hub.addChildNode(hubba)
        grindables.append(hubba)

        // Kicker at end of plaza
        let kickGeo  = SCNBox(width: 2.5, height: 0.7, length: 2.0, chamferRadius: 0.04)
        let kicker   = SCNNode(geometry: kickGeo)
        kicker.name  = "kicker"
        kicker.position = SCNVector3(5.0, 0.35, 0)
        kicker.physicsBody = SCNPhysicsBody(type: .static, shape: nil)
        hub.addChildNode(kicker)

        scene.rootNode.addChildNode(hub)
        return grindables
    }

    // MARK: - Lake Cunningham Full-Pipe Vert Zone

    private static func buildCunninghamVertZone(in scene: SCNScene) {
        let hub = SCNNode()
        hub.name     = "Bay_Vert_Zone"
        hub.position = SCNVector3(0, 0, -32.0)

        // Full pipe (rotated to lie on its side as a ridable tunnel)
        let pipeGeo = SCNCylinder(radius: 4.5, height: 12.0)
        let pipe    = SCNNode(geometry: pipeGeo)
        pipe.name   = "fullpipe"
        pipe.eulerAngles = SCNVector3(0, 0, Float.pi / 2.0)
        pipe.physicsBody = SCNPhysicsBody(
            type: .static,
            shape: SCNPhysicsShape(
                geometry: pipeGeo,
                options: [.type: SCNPhysicsShape.ShapeType.concavePolyhedron]
            )
        )
        hub.addChildNode(pipe)

        // Quarter-pipe ramps flanking the full pipe
        for xSide in [-8.0, 8.0] as [Float] {
            let rampGeo  = SCNBox(width: 4.5, height: 3.5, length: 5.5, chamferRadius: 0.3)
            let ramp     = SCNNode(geometry: rampGeo)
            ramp.name    = "kicker"
            ramp.position = SCNVector3(xSide, 1.75, 0)
            ramp.eulerAngles = SCNVector3(xSide > 0 ? -0.45 : 0.45, 0, 0)
            ramp.physicsBody = SCNPhysicsBody(type: .static, shape: nil)
            hub.addChildNode(ramp)
        }

        scene.rootNode.addChildNode(hub)
    }

    // MARK: - Lighting

    private static func addGoldenHourLighting(to scene: SCNScene) {
        let sun   = SCNNode()
        let light = SCNLight()
        light.type        = .directional
        light.intensity   = 1600
        light.temperature = 5200      // Warmer angle = SF afternoon
        light.castsShadow = true
        light.shadowRadius = 4
        light.shadowMapSize = CGSize(width: 2048, height: 2048)
        sun.light       = light
        sun.eulerAngles = SCNVector3(-0.35, 0.62, 0)
        scene.rootNode.addChildNode(sun)
    }
}
