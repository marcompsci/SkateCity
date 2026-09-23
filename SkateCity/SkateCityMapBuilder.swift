import SceneKit

/// Constructs the full SkateCity world into an SCNScene.
/// GLB assets are attempted first; every obstacle has a SceneKit-primitive fallback
/// so the scene is always fully populated even before assets are bundled.
///
/// Returns the set of grindable nodes so the game loop can detect grind entry.
enum SkateCityMapBuilder {

    // MARK: - Entry Point

    @discardableResult
    static func build(into scene: SCNScene) -> [SCNNode] {
        addGround(to: scene)
        let grindables = addObstacles(to: scene)
        addProps(to: scene)
        addSkyboxBuildings(to: scene)
        return grindables
    }

    // MARK: - Ground

    private static func addGround(to scene: SCNScene) {
        let floor = SCNFloor()
        floor.reflectivity = 0.04
        let node = SCNNode(geometry: floor)
        node.name = "street"
        node.physicsBody = SCNPhysicsBody(type: .static, shape: nil)
        scene.rootNode.addChildNode(node)
    }

    // MARK: - Skate Obstacles

    private static func addObstacles(to scene: SCNScene) -> [SCNNode] {
        var grindables: [SCNNode] = []

        // ── Centre plaza ledge row ─────────────────────────────────────────────
        for xPos in [-4.0, 0.0, 4.0] as [Float] {
            let node = obstacle(
                asset:    .ledge,
                fallback: SCNBox(width: 4, height: 0.35, length: 0.5, chamferRadius: 0.02),
                name:     "ledge",
                position: SCNVector3(xPos, 0.175, -6)
            )
            scene.rootNode.addChildNode(node)
            grindables.append(node)
        }

        // ── Rails (both sides) ────────────────────────────────────────────────
        for xPos in [-5.5, 5.5] as [Float] {
            let node = obstacle(
                asset:    .rail,
                fallback: SCNTube(innerRadius: 0.025, outerRadius: 0.04, height: 5),
                name:     "rail",
                position: SCNVector3(xPos, 0.55, -6)
            )
            scene.rootNode.addChildNode(node)
            grindables.append(node)
        }

        // ── Kicker ramp ────────────────────────────────────────────────────────
        scene.rootNode.addChildNode(obstacle(
            asset:    .kicker,
            fallback: SCNBox(width: 2.5, height: 0.7, length: 2, chamferRadius: 0.04),
            name:     "kicker",
            position: SCNVector3(-8, 0.35, -3)
        ))

        // ── Stairs (right-street section) ─────────────────────────────────────
        scene.rootNode.addChildNode(obstacle(
            asset:    .stairs,
            fallback: SCNBox(width: 4, height: 0.8, length: 3, chamferRadius: 0.01),
            name:     "stairs",
            position: SCNVector3(7, 0.4, -9)
        ))

        // ── Bench grinds ──────────────────────────────────────────────────────
        for (x, z) in [(9.0, 0.0), (-9.0, 0.0)] as [(Float, Float)] {
            let node = obstacle(
                asset:    .bench,
                fallback: SCNBox(width: 0.4, height: 0.5, length: 2.2, chamferRadius: 0.03),
                name:     "bench",
                position: SCNVector3(x, 0.25, z)
            )
            scene.rootNode.addChildNode(node)
            grindables.append(node)
        }

        // ── Manual pad ────────────────────────────────────────────────────────
        let pad = SCNNode(geometry: SCNBox(width: 3, height: 0.15, length: 5, chamferRadius: 0.01))
        pad.name = "ledge"
        pad.position = SCNVector3(0, 0.075, 6)
        pad.physicsBody = SCNPhysicsBody(type: .static, shape: nil)
        scene.rootNode.addChildNode(pad)
        grindables.append(pad)

        return grindables
    }

    // MARK: - Decorative Props

    private static func addProps(to scene: SCNScene) {
        // Parked cars
        let carConfigs: [(x: Float, z: Float, asset: GLBAssetLoader.AssetName)] = [
            ( 12, 4,  .carSedan), (-12, 4,  .carHatch),
            ( 12, -4, .carHatch), (-12, -4, .carSedan),
        ]
        for cfg in carConfigs {
            if let node = GLBAssetLoader.shared.loadNode(named: cfg.asset) {
                node.position = SCNVector3(cfg.x, 0, cfg.z)
                node.physicsBody = SCNPhysicsBody(type: .static, shape: nil)
                scene.rootNode.addChildNode(node)
            }
        }

        // Streetlights
        for xPos in [-10.0, -3.5, 3.5, 10.0] as [Float] {
            let pos = SCNVector3(xPos, 0, -13)
            if let node = GLBAssetLoader.shared.loadNode(named: .streetlight) {
                node.position = pos
                scene.rootNode.addChildNode(node)
            } else {
                scene.rootNode.addChildNode(streetlightFallback(at: pos))
            }
        }

        // Trees
        for (x, z) in [(9.0, -17.0), (-9.0, -17.0), (0.0, -20.0)] as [(Float, Float)] {
            if let node = GLBAssetLoader.shared.loadNode(named: .tree) {
                node.position = SCNVector3(x, 0, z)
                scene.rootNode.addChildNode(node)
            }
        }

        // Rental micro-mobility (StreetSesh world dressing)
        for (x, z, asset) in [(6.0, 8.0, GLBAssetLoader.AssetName.zippEbike),
                               (-6.0, 8.0, .zippEscooter)] as [(Float, Float, GLBAssetLoader.AssetName)] {
            if let node = GLBAssetLoader.shared.loadNode(named: asset) {
                node.position = SCNVector3(x, 0, z)
                scene.rootNode.addChildNode(node)
            }
        }
    }

    // MARK: - Background Buildings

    private static func addSkyboxBuildings(to scene: SCNScene) {
        // (x, z, width, height, depth)
        let configs: [(Float, Float, Float, Float, Float)] = [
            ( 18, -25, 8,  20, 8),  (-18, -25, 8,  28, 8),
            (  0, -32, 12, 16, 10), ( 30, -20, 7,  22, 7),
            (-30, -20, 7,  18, 7),  ( 22, -35, 6,  30, 6),
            (-22, -35, 6,  24, 6),
        ]
        for (x, z, w, h, d) in configs {
            if let node = GLBAssetLoader.shared.loadNode(named: .building) {
                node.position = SCNVector3(x, 0, z)
                scene.rootNode.addChildNode(node)
            } else {
                let box  = SCNBox(width: CGFloat(w), height: CGFloat(h),
                                  length: CGFloat(d), chamferRadius: 0.1)
                let node = SCNNode(geometry: box)
                node.name = "building"
                node.position = SCNVector3(x, h / 2, z)
                scene.rootNode.addChildNode(node)
            }
        }
    }

    // MARK: - Helpers

    private static func obstacle(
        asset:    GLBAssetLoader.AssetName,
        fallback: SCNGeometry,
        name:     String,
        position: SCNVector3
    ) -> SCNNode {
        let node = GLBAssetLoader.shared.loadNode(named: asset) ?? SCNNode(geometry: fallback)
        node.name = name
        node.position = position
        node.physicsBody = SCNPhysicsBody(type: .static, shape: nil)
        return node
    }

    private static func streetlightFallback(at position: SCNVector3) -> SCNNode {
        let pole = SCNNode(geometry: SCNCylinder(radius: 0.06, height: 5))
        pole.name = "prop"
        pole.position = SCNVector3(position.x, 2.5, position.z)
        let arm  = SCNNode(geometry: SCNCylinder(radius: 0.04, height: 1.2))
        arm.name = "prop"
        arm.position    = SCNVector3(0.6, 2.7, 0)
        arm.eulerAngles = SCNVector3(0, 0, Float.pi / 2)
        pole.addChildNode(arm)
        return pole
    }
}
