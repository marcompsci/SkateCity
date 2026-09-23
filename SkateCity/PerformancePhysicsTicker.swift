import SceneKit

/// Throttles expensive raycasts to 60 Hz while the render loop runs at 120 FPS.
class PerformancePhysicsTicker {
    private var lastPhysicsUpdateTime: TimeInterval = 0
    private let physicsTargetInterval: TimeInterval = 1.0 / 60.0

    private(set) var optimalIsGrounded = false
    private(set) var cachedGroundNormal = SCNVector3(0, 1, 0)

    func tickEngineUpdate(at currentTime: TimeInterval, boardNode: SCNNode) {
        let delta = currentTime - lastPhysicsUpdateTime
        guard delta >= physicsTargetInterval else { return }
        lastPhysicsUpdateTime = currentTime
        executeHeavyRaycast(for: boardNode)
    }

    private func executeHeavyRaycast(for node: SCNNode) {
        let start = node.presentation.position
        let end   = SCNVector3(start.x, start.y - 0.6, start.z)

        let options: [String: Any] = [
            SCNHitTestOption.searchMode.rawValue:       SCNHitTestSearchMode.closest.rawValue,
            SCNHitTestOption.backFaceCulling.rawValue:  true,
            SCNHitTestOption.ignoreHiddenNodes.rawValue: true
        ]

        let hits = node.parent?.hitTestWithSegment(from: start, to: end, options: options) ?? []
        if let hit = hits.first {
            optimalIsGrounded   = true
            cachedGroundNormal  = hit.worldNormal
        } else {
            optimalIsGrounded = false
        }
    }
}
