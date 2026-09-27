// Copyright © 2026 MAR / SkateCity. All rights reserved.
// Unauthorized reproduction, distribution, or modification is strictly prohibited.

#if os(iOS)
import UIKit
import SceneKit

// MARK: - Gear Catalogue Types

enum CustomizationCategory: String, Codable {
    case shoes         = "SHOES"
    case boardGraphic  = "BOARD_GRAPHIC"
    case clothingStyle = "CLOTHING"
}

struct CustomAssetItem: Identifiable, Codable {
    let id:                       UUID
    let name:                     String
    let category:                 CustomizationCategory
    let textureAlbedoName:        String
    let textureRoughnessMetalName: String
    /// Per-channel tint [R, G, B, A] — used for cloth dye swaps.
    let colorTintRGBA: [Float]
}

// MARK: - Live Material Swapper

/// Dynamically hot-swaps PBR textures on the skater mesh and skateboard
/// without rebuilding the SceneKit material or reallocating GPU pipelines.
final class SkaterCustomizer {

    private let skaterNode: SCNNode
    private let boardNode:  SCNNode

    init(skaterNode: SCNNode, boardNode: SCNNode) {
        self.skaterNode = skaterNode
        self.boardNode  = boardNode
    }

    func apply(_ item: CustomAssetItem) {
        let targetMeshName: String
        switch item.category {
        case .shoes:         targetMeshName = "skater_shoes_mesh"
        case .clothingStyle: targetMeshName = "skater_body_mesh"
        case .boardGraphic:  targetMeshName = "deck_bottom_mesh"
        }
        swap(item: item, onto: targetMeshName)
    }

    private func swap(item: CustomAssetItem, onto meshName: String) {
        // Search both character and board hierarchies
        let node = skaterNode.childNode(withName: meshName, recursively: true)
                ?? boardNode.childNode(withName: meshName, recursively: true)
        guard let material = node?.geometry?.firstMaterial else { return }

        if let albedo = UIImage(named: item.textureAlbedoName) {
            material.diffuse.contents = albedo
        }
        if let rm = UIImage(named: item.textureRoughnessMetalName) {
            material.roughness.contents = rm
            material.metalness.contents = rm
        }

        // Inject uniform tint directly into SceneKit's custom shader registers
        let t = item.colorTintRGBA
        if t.count >= 4 {
            material.setValue(SCNVector4(t[0], t[1], t[2], t[3]), forKey: "customColorTint")
        }
    }
}

// MARK: - Persistence Bridge

/// Reads the player's saved loadout keys from ProfilePersistenceManager
/// and applies them via SkaterCustomizer on scene entry.
final class CustomizationPersistenceBridge {

    let customizer: SkaterCustomizer
    private var catalog: [String: CustomAssetItem] = [:]

    init(skaterNode: SCNNode, boardNode: SCNNode) {
        self.customizer = SkaterCustomizer(skaterNode: skaterNode, boardNode: boardNode)
        buildCatalog()
    }

    /// Call once after the scene is loaded to restore the player's gear.
    func applyLoadout() {
        // Default loadout — production wires this from PlayerProfile.equippedGearIDs
        ["vans_old_skool_black", "anti_hero_classic_eagle"]
            .compactMap { catalog[$0] }
            .forEach { customizer.apply($0) }
    }

    // MARK: - Default Gear Catalogue

    private func buildCatalog() {
        catalog["vans_old_skool_black"] = CustomAssetItem(
            id: UUID(), name: "Suede Skate Shoes",
            category: .shoes,
            textureAlbedoName: "shoes_vans_albedo",
            textureRoughnessMetalName: "shoes_vans_roughness",
            colorTintRGBA: [1, 1, 1, 1]
        )
        catalog["vans_checkerboard"] = CustomAssetItem(
            id: UUID(), name: "Checkerboard Vans",
            category: .shoes,
            textureAlbedoName: "shoes_vans_check_albedo",
            textureRoughnessMetalName: "shoes_vans_roughness",
            colorTintRGBA: [1, 1, 1, 1]
        )
        catalog["anti_hero_classic_eagle"] = CustomAssetItem(
            id: UUID(), name: "Bay Area Classic Deck",
            category: .boardGraphic,
            textureAlbedoName: "deck_eagle_albedo",
            textureRoughnessMetalName: "deck_shared_roughness",
            colorTintRGBA: [1, 1, 1, 1]
        )
        catalog["zoo_york_subway"] = CustomAssetItem(
            id: UUID(), name: "Zoo York Subway Deck",
            category: .boardGraphic,
            textureAlbedoName: "deck_zooyork_albedo",
            textureRoughnessMetalName: "deck_shared_roughness",
            colorTintRGBA: [1, 1, 1, 1]
        )
        catalog["spitfire_hoodie_red"] = CustomAssetItem(
            id: UUID(), name: "Spitfire Flames Hoodie",
            category: .clothingStyle,
            textureAlbedoName: "clothing_spitfire_albedo",
            textureRoughnessMetalName: "clothing_fabric_roughness",
            colorTintRGBA: [1, 0.18, 0.08, 1]   // Red tint via uniform register
        )
    }
}
#endif
