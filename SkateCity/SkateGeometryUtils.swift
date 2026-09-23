import SceneKit
import simd

/// Shared geometry helpers used by the rendering and collision pipelines.
class SkateGeometryUtils {

    /// Converts a world-space contact point into [0,1] UV coordinates on the deck texture.
    static func convertWorldPointToDeckUV(
        _ worldPoint: SCNVector3,
        deckNode:     SCNNode,
        boardWidth:   Float,
        boardLength:  Float
    ) -> simd_float2 {
        let local = deckNode.convertPosition(worldPoint, from: nil)
        let u = (Float(local.x) + (boardWidth  / 2.0)) / boardWidth
        let v = (Float(local.z) + (boardLength / 2.0)) / boardLength
        return simd_float2(max(0, min(1, u)), max(0, min(1, v)))
    }

    /// Projects a SceneKit node's bounding box extents as a SIMD rect (minX, minZ, maxX, maxZ).
    static func boundingRect(for node: SCNNode) -> simd_float4 {
        let (minVec, maxVec) = node.boundingBox
        return simd_float4(Float(minVec.x), Float(minVec.z), Float(maxVec.x), Float(maxVec.z))
    }

    /// Returns normalized forward direction of a node in world space (XZ plane).
    static func worldForward(of node: SCNNode) -> simd_float2 {
        let fwd = node.presentation.simdWorldFront
        let len = sqrt(fwd.x * fwd.x + fwd.z * fwd.z)
        guard len > 0 else { return simd_float2(0, 1) }
        return simd_float2(fwd.x / len, fwd.z / len)
    }
}
