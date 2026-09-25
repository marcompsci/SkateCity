#if os(iOS)
import SceneKit

// MARK: - LOD levels

enum CharacterLOD: Int, Comparable {
    case high   = 0   // < 10 m  — full detail: fingers, cloth seams, all extras
    case medium = 1   // < 30 m  — no fingers, simplified clothing
    case low    = 2   // >= 30 m — skeleton + base body only

    static func < (lhs: CharacterLOD, rhs: CharacterLOD) -> Bool { lhs.rawValue < rhs.rawValue }
}

// MARK: - CharacterLODManager

final class CharacterLODManager {

    private(set) var currentLOD: CharacterLOD = .high

    // Distance thresholds (metres, squared for cheap comparison)
    private let highSq:   Float = 10 * 10
    private let mediumSq: Float = 30 * 30

    // Finger node name prefix applied inside addFingers()
    private let fingerPrefix = "sk_finger"
    // High-detail clothing geometry node name substring
    private let seamsPrefix  = "cl_seam"
    private let extraPrefix  = "cl_extra"

    // MARK: Distance-based LOD selection

    func evaluate(cameraPosition: SCNVector3, avatarPosition: SCNVector3) -> CharacterLOD {
        let dx = cameraPosition.x - avatarPosition.x
        let dy = cameraPosition.y - avatarPosition.y
        let dz = cameraPosition.z - avatarPosition.z
        let distSq = dx*dx + dy*dy + dz*dz

        if distSq < highSq   { return .high   }
        if distSq < mediumSq { return .medium  }
        return .low
    }

    // MARK: Apply LOD to avatar

    /// Call once per frame from the render loop only when lod actually changes.
    func apply(lod: CharacterLOD, to avatar: AvatarModel) {
        guard lod != currentLOD else { return }
        currentLOD = lod
        updateVisibility(lod: lod, root: avatar.rootNode)
        updateGeometryDetail(lod: lod, avatar: avatar)
    }

    // MARK: Visibility

    private func updateVisibility(lod: CharacterLOD, root: SCNNode) {
        root.enumerateChildNodes { node, _ in
            guard let name = node.name else { return }

            // Fingers — only at high LOD
            if name.hasPrefix(self.fingerPrefix) {
                node.isHidden = lod != .high
                return
            }

            // High-detail seam geometry — only at high LOD
            if name.hasPrefix(self.seamsPrefix) {
                node.isHidden = lod != .high
                return
            }

            // Extras (glasses, chain, watch, headphones) — hide at low
            if name.hasPrefix(self.extraPrefix) {
                node.isHidden = lod == .low
                return
            }
        }
    }

    // MARK: Geometry detail

    private func updateGeometryDetail(lod: CharacterLOD, avatar: AvatarModel) {
        // At low LOD remove shader modifiers (expensive per-fragment ops)
        let removeShaders = lod == .low
        avatar.rootNode.enumerateChildNodes { node, _ in
            guard let geo = node.geometry else { return }
            for mat in geo.materials {
                if removeShaders {
                    mat.shaderModifiers = nil
                } else {
                    // Shader modifiers are re-applied when apply(profile:) is called;
                    // here we just skip forcing a rebuild — the next wardrobe change restores them.
                }
            }
        }

        // Shadow plane visibility
        if let shadowNode = avatar.rootNode.childNode(withName: "contact_shadow", recursively: false) {
            shadowNode.isHidden = lod == .low
        }
    }

    // MARK: Skateboard LOD

    func apply(lod: CharacterLOD, to board: SkateboardModel) {
        board.boardRoot.enumerateChildNodes { node, _ in
            guard let name = node.name else { return }
            // Truck bolts are tiny and invisible past medium
            if name.contains("_bolt") {
                node.isHidden = lod == .low
            }
            // Kingpin and pivot cup — medium+
            if name.contains("_kingpin") || name.contains("_pivot") {
                node.isHidden = lod == .low
            }
        }
    }
}
#endif
