import SceneKit

// MARK: - Ragdoll Skeleton Driver

/// Rigs named bones on a skater SCNNode with capsule colliders, stitches them
/// with ball-socket joints, then detonates a physics-driven bail on demand.
///
/// Bone names must match child node names inside the skater hierarchy
/// (e.g. exported from a .usdz / .glb avatar with named joints).
final class SkaterRagdollController {

    private let rootNode:  SCNNode
    private var boneNodes: [SCNNode]            = []
    private var joints:    [SCNPhysicsBehavior] = []

    private(set) var isRagdolling = false

    init(skaterNode: SCNNode) {
        self.rootNode = skaterNode
    }

    // MARK: - Rigging

    /// Adds a capsule collider (kinematic by default) to a named bone.
    func rigBone(named boneName: String,
                 radius: CGFloat,
                 height: CGFloat,
                 mass:   CGFloat = 3.5,
                 in scene: SCNScene) {
        guard let bone = rootNode.childNode(withName: boneName, recursively: true) else { return }
        let shape = SCNPhysicsShape(
            geometry: SCNCapsule(capRadius: radius, height: height),
            options:  [.type: SCNPhysicsShape.ShapeType.convexHull]
        )
        let body          = SCNPhysicsBody(type: .kinematic, shape: shape)
        body.mass         = mass
        body.friction     = 0.6
        body.restitution  = 0.12
        bone.physicsBody  = body
        boneNodes.append(bone)
    }

    /// Ball-socket joint connecting two rigged bones at their local origins.
    func linkBones(child childName: String, parent parentName: String, in scene: SCNScene) {
        guard let childNode  = rootNode.childNode(withName: childName,  recursively: true),
              let parentNode = rootNode.childNode(withName: parentName, recursively: true),
              let bodyA      = parentNode.physicsBody,
              let bodyB      = childNode.physicsBody else { return }

        let joint = SCNPhysicsBallSocketJoint(
            bodyA: bodyA, anchorA: .init(0, 0, 0),
            bodyB: bodyB, anchorB: .init(0, 0, 0)
        )
        scene.physicsWorld.addBehavior(joint)
        joints.append(joint)
    }

    // MARK: - Standard rig helper

    /// Rigs and links the core lower-body skeleton in one call.
    func rigCoreBodySegments(in scene: SCNScene) {
        rigBone(named: "Hips",      radius: 0.18, height: 0.40, in: scene)
        rigBone(named: "Spine",     radius: 0.16, height: 0.50, in: scene)
        rigBone(named: "LeftKnee",  radius: 0.10, height: 0.45, in: scene)
        rigBone(named: "RightKnee", radius: 0.10, height: 0.45, in: scene)
        linkBones(child: "Spine",     parent: "Hips", in: scene)
        linkBones(child: "LeftKnee",  parent: "Hips", in: scene)
        linkBones(child: "RightKnee", parent: "Hips", in: scene)
    }

    // MARK: - Bail detonation

    /// Switches all bones kinematic → dynamic, inherits board velocity, injects torque chaos.
    func eject(boardVelocity: SCNVector3) {
        guard !isRagdolling else { return }
        isRagdolling = true
        rootNode.removeAllActions()

        for bone in boneNodes {
            guard let body = bone.physicsBody else { continue }
            body.type               = .dynamic
            body.isAffectedByGravity = true
            body.velocity           = boardVelocity
            body.applyTorque(
                SCNVector4(Float.random(in: -4...4),
                           Float.random(in: -2...4),
                           Float.random(in: -5...5), 1.0),
                asImpulse: true
            )
        }

        // Hip hub gets the directional launch impulse so the skater arcs forward
        let launchImpulse = SCNVector3(
            boardVelocity.x * 1.2,
            abs(boardVelocity.y) + 3.0,
            boardVelocity.z * 1.2
        )
        rootNode.childNode(withName: "Hips", recursively: true)?
            .physicsBody?.applyForce(launchImpulse, asImpulse: true)
    }

    /// Resets all bones to kinematic — call after the recovery animation completes.
    func resetToKinematic() {
        boneNodes.forEach { $0.physicsBody?.type = .kinematic }
        isRagdolling = false
    }

    // MARK: - Per-frame balance deformation

    /// Procedurally tilts board + spine based on the grind balance offset.
    /// Call from SCNSceneRendererDelegate every frame while grinding.
    func applyBalanceTilt(to boardNode: SCNNode, spineNodeName: String, offset: Float) {
        #if os(iOS)
        boardNode.eulerAngles.x = offset * 0.25
        rootNode.childNode(withName: spineNodeName, recursively: true)?
            .eulerAngles.z = -offset * 0.40
        #else
        boardNode.eulerAngles.x = CGFloat(offset * 0.25)
        rootNode.childNode(withName: spineNodeName, recursively: true)?
            .eulerAngles.z = CGFloat(-offset * 0.40)
        #endif
    }
}
