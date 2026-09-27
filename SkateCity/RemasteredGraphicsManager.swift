// Copyright © 2026 MAR / SkateCity. All rights reserved.
// Unauthorized reproduction, distribution, or modification is strictly prohibited.

#if os(iOS)
import SceneKit
import UIKit
import Metal
import simd

/// Dedicated graphics manager for injecting a high-fidelity PBR pipeline into SceneKit.
/// Extends the original static API with per-role texture routing and a Metal compute
/// scratch pipeline exposed via ScratchPipeline.shared.
public final class RemasteredGraphicsManager {

    private init() {}   // Utility class — all API is static

    // MARK: - Primary Public API

    /// Configures a SceneKit scene and its child nodes to use remastered PBR graphics.
    /// - Parameters:
    ///   - scene: The target SCNScene where environmental lighting and skyboxes are applied.
    ///   - targetNode: The root SCNNode whose hierarchy will be recursively updated with PBR materials.
    public static func setupRemasteredPipeline(for scene: SCNScene, targetNode: SCNNode) {
        configureIBL(for: scene)
        injectPBRMaterials(into: targetNode)
    }

    // MARK: - IBL Environment

    private static func configureIBL(for scene: SCNScene) {
        // High-dynamic-range (HDR) images provide realistic ambient reflections across metallic surfaces.
        if let skybox = UIImage(named: "remastered_skybox.hdr") {
            scene.lightingEnvironment.contents  = skybox
            scene.lightingEnvironment.intensity = 1.2
            scene.background.contents           = skybox
        } else {
            // Fallback until the HDR asset is added to the asset catalogue
            scene.lightingEnvironment.intensity = 1.0
            scene.background.contents           = UIColor(white: 0.15, alpha: 1)
        }

        // Atmospheric city depth
        scene.fogStartDistance   = 80
        scene.fogEndDistance     = 200
        scene.fogColor           = UIColor(white: 0.72, alpha: 1)
        scene.fogDensityExponent = 1.0
    }

    // MARK: - Recursive PBR Injection

    private static func injectPBRMaterials(into targetNode: SCNNode) {
        // Traverses the entire node tree to stamp high-fidelity PBR material settings.
        targetNode.enumerateChildNodes { node, _ in
            guard let geometry = node.geometry else { return }

            // Enable real-time shadow math for this mesh
            node.castsShadow = true
            geometry.firstMaterial?.lightingModel = .physicallyBased

            for material in geometry.materials {
                applyPBR(to: material, nodeName: node.name)
            }
        }

        // Also apply to the root node's own geometry
        if let geometry = targetNode.geometry {
            targetNode.castsShadow = true
            geometry.firstMaterial?.lightingModel = .physicallyBased
            for material in geometry.materials {
                applyPBR(to: material, nodeName: targetNode.name)
            }
        }
    }

    // MARK: - Per-Material PBR Configuration

    private static func applyPBR(to material: SCNMaterial, nodeName: String?) {
        // Force the renderer to use Physically-Based Shading
        material.lightingModel = .physicallyBased

        // --- Shared High-Res Base Maps (applied to every mesh as a baseline) ---

        // Base Color / Texture Map
        if let albedo = UIImage(named: "remastered_albedo_highres") {
            material.diffuse.contents = albedo
        }

        // Normal Map (simulates fine physical depth, cracks, and surface imperfections)
        if let normal = UIImage(named: "remastered_normal_map") {
            material.normal.contents  = normal
            material.normal.intensity = 1.0
        }

        // Roughness Map (determines how blurred or sharp light reflections appear)
        if let roughness = UIImage(named: "remastered_roughness") {
            material.roughness.contents = roughness
        }

        // Metalness Map (specifies which areas act like real metal vs. dielectric surfaces)
        if let metalness = UIImage(named: "remastered_metalness") {
            material.metalness.contents = metalness
        }

        // Ambient Occlusion Map (injects baked micro-shadows into crevices)
        if let ao = UIImage(named: "remastered_ao") {
            material.ambientOcclusion.contents  = ao
            material.ambientOcclusion.intensity = 1.0
        }

        // --- Per-Role Overrides ---
        // Route correct PBR channel values based on the mesh's semantic name so
        // deck, truck, wheel, and environment surfaces each present accurate material
        // properties without breaking the enumerateChildNodes traversal above.
        switch meshRole(for: nodeName) {

        case .deck:
            // Roughness driven by dynamic Metal scratch texture — wear accumulates in real-time.
            material.metalness.contents = UIImage(named: "deck_metalness") ?? Float(0.05)
            material.roughness.contents = ScratchPipeline.shared.deckScratchTexture
                                          ?? UIImage(named: "deck_roughness")
                                          ?? Float(0.85)

        case .truck:
            // Brushed aluminium — high metalness, low-mid roughness.
            material.diffuse.contents   = UIImage(named: "truck_albedo")    ?? UIColor(white: 0.75, alpha: 1)
            material.metalness.contents = UIImage(named: "truck_metalness") ?? Float(0.95)
            material.roughness.contents = UIImage(named: "truck_roughness") ?? Float(0.35)

        case .wheel:
            // Urethane — zero metalness, high roughness (matte).
            material.diffuse.contents   = UIImage(named: "wheel_albedo")    ?? UIColor(white: 0.95, alpha: 1)
            material.metalness.contents = Float(0.0)
            material.roughness.contents = UIImage(named: "wheel_roughness") ?? Float(0.75)

        case .environment:
            // City props: ledges, rails, kickers, ground — near-matte concrete/metal.
            material.metalness.contents = UIImage(named: "env_metalness") ?? Float(0.1)
            material.roughness.contents = UIImage(named: "env_roughness") ?? Float(0.9)

        case .unknown:
            break   // Shared base maps above are sufficient for unrecognised meshes
        }

        material.isDoubleSided       = false
        material.writesToDepthBuffer = true
    }

    // MARK: - Mesh Role Resolution

    private enum MeshRole { case deck, truck, wheel, environment, unknown }

    private static func meshRole(for name: String?) -> MeshRole {
        let n = (name ?? "").lowercased()
        if n.contains("deck")    || n.contains("board")    { return .deck }
        if n.contains("truck")   || n.contains("axle")     { return .truck }
        if n.contains("wheel")   || n.contains("urethane") { return .wheel }
        if n.contains("ledge")   || n.contains("rail")
        || n.contains("street")  || n.contains("ground")
        || n.contains("kicker")  || n.contains("building") { return .environment }
        return .unknown
    }

    // MARK: - Metal Scratch Compute (static façade over ScratchPipeline)

    /// Dispatch the compute kernel to paint a wear mark on the deck scratch texture at `uv`.
    /// Safe to call every grind frame — the underlying pipeline batches work on the GPU.
    static func paintScratch(at uv: simd_float2, intensity: Float) {
        ScratchPipeline.shared.paint(at: uv, intensity: intensity)
    }
}

// MARK: - ScratchPipeline

/// Owns the MTLDevice and MTLComputePipelineState for the deck scratch compute kernel.
/// Kept as a separate singleton so RemasteredGraphicsManager stays a static utility class.
final class ScratchPipeline {
    static let shared = ScratchPipeline()

    private let device: MTLDevice = MTLCreateSystemDefaultDevice()!
    private var pipeline: MTLComputePipelineState?
    private var commandQueue: MTLCommandQueue?
    private(set) var deckScratchTexture: MTLTexture?

    private init() {
        commandQueue = device.makeCommandQueue()
        buildPipeline()
        deckScratchTexture = makeTexture(size: 512)
    }

    private func buildPipeline() {
        guard let lib = device.makeDefaultLibrary(),
              let fn  = lib.makeFunction(name: "paint_board_scratches") else { return }
        pipeline = try? device.makeComputePipelineState(function: fn)
    }

    private func makeTexture(size: Int) -> MTLTexture? {
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm, width: size, height: size, mipmapped: false)
        desc.usage       = [.shaderRead, .shaderWrite]
        desc.storageMode = .shared
        let tex = device.makeTexture(descriptor: desc)
        // Start clean (white = zero wear)
        let white = [UInt8](repeating: 255, count: size * size * 4)
        tex?.replace(region: MTLRegionMake2D(0, 0, size, size),
                     mipmapLevel: 0, withBytes: white, bytesPerRow: size * 4)
        return tex
    }

    func paint(at uv: simd_float2, intensity: Float) {
        guard let pipeline,
              let queue = commandQueue,
              let tex   = deckScratchTexture,
              let cmd   = queue.makeCommandBuffer(),
              let enc   = cmd.makeComputeCommandEncoder() else { return }

        var uvCopy  = uv
        var intCopy = intensity

        enc.setComputePipelineState(pipeline)
        enc.setTexture(tex, index: 0)
        enc.setBytes(&uvCopy,  length: MemoryLayout<simd_float2>.size, index: 0)
        enc.setBytes(&intCopy, length: MemoryLayout<Float>.size,        index: 1)

        let tpg = MTLSize(width: 16, height: 16, depth: 1)
        let grp = MTLSize(width: (tex.width + 15) / 16, height: (tex.height + 15) / 16, depth: 1)
        enc.dispatchThreadgroups(grp, threadsPerThreadgroup: tpg)
        enc.endEncoding()
        cmd.commit()
    }
}
#endif
