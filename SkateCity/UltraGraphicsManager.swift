#if os(iOS)
import UIKit
import SceneKit
import Metal
import simd

// MARK: - Quality tiers

enum GraphicsQuality: String {
    case low    = "Low"
    case high   = "High"
    case ultra  = "Ultra"
}

// MARK: - Time-of-day presets

struct TimeOfDayPreset {
    let label:            String
    let sunAngleX:        Float   // euler X of the sun node
    let sunAngleY:        Float
    let sunIntensity:     CGFloat
    let sunTemperature:   CGFloat // Kelvin
    let ambientIntensity: CGFloat
    let ambientColor:     UIColor
    let fogColor:         UIColor
    let fogStart:         CGFloat
    let fogEnd:           CGFloat
    let nightBlend:       Float   // 0 = day, 1 = full night
    let skyTop:           UIColor
    let skyHorizon:       UIColor

    static let day = TimeOfDayPreset(
        label:            "Day",
        sunAngleX:        -Float.pi / 4,
        sunAngleY:        Float.pi / 5,
        sunIntensity:     2200,
        sunTemperature:   6500,
        ambientIntensity: 450,
        ambientColor:     UIColor(white: 0.92, alpha: 1),
        fogColor:         UIColor(rgb: 0xC8DBF0),
        fogStart:         90,
        fogEnd:           260,
        nightBlend:       0,
        skyTop:           UIColor(rgb: 0x1A3D6B),
        skyHorizon:       UIColor(rgb: 0x9EC3E8)
    )
    static let goldenHour = TimeOfDayPreset(
        label:            "Golden",
        sunAngleX:        -0.18,
        sunAngleY:        Float.pi * 0.45,
        sunIntensity:     1800,
        sunTemperature:   3200,
        ambientIntensity: 280,
        ambientColor:     UIColor(rgb: 0xFFD0A0),
        fogColor:         UIColor(rgb: 0xF4C07A),
        fogStart:         55,
        fogEnd:           180,
        nightBlend:       0.15,
        skyTop:           UIColor(rgb: 0x2A1F4B),
        skyHorizon:       UIColor(rgb: 0xFF8A3C)
    )
    static let dusk = TimeOfDayPreset(
        label:            "Dusk",
        sunAngleX:        -0.06,
        sunAngleY:        Float.pi * 0.7,
        sunIntensity:     900,
        sunTemperature:   2400,
        ambientIntensity: 120,
        ambientColor:     UIColor(rgb: 0x4060A0),
        fogColor:         UIColor(rgb: 0x1C2840),
        fogStart:         40,
        fogEnd:           130,
        nightBlend:       0.85,
        skyTop:           UIColor(rgb: 0x080C18),
        skyHorizon:       UIColor(rgb: 0xFF5820)
    )
}

// MARK: - Ultra Graphics Manager

final class UltraGraphicsManager {
    static let shared = UltraGraphicsManager()
    private init() {}

    // Runtime state
    private(set) var quality:    GraphicsQuality  = .high
    private(set) var timeOfDay:  TimeOfDayPreset  = .day
    private      var nightValue: Float            = 0

    private weak var sunNode:     SCNNode?
    private weak var sunLight:    SCNLight?
    private weak var ambientNode: SCNNode?
    private weak var ambientLight: SCNLight?
    private weak var sceneRef:    SCNScene?

    // Per-frame night uniforms cache
    private var shaderMaterials: [SCNMaterial] = []

    // MARK: Primary entry point

    func setup(scene: SCNScene, scnView: SCNView, quality: GraphicsQuality = .high) {
        self.quality  = quality
        self.sceneRef = scene
        buildLighting(in: scene)
        configureIBL(scene: scene)
        configureView(scnView, quality: quality)
        apply(tod: .day)
    }

    // MARK: Lighting

    private func buildLighting(in scene: SCNScene) {
        // Sun — directional, PCF soft shadows
        let sn = SCNNode(); let sl = SCNLight()
        sl.type              = .directional
        sl.intensity         = 2200
        sl.temperature       = 6500
        sl.castsShadow       = true
        sl.shadowRadius      = 4
        sl.shadowSampleCount = 16
        sl.shadowMapSize     = CGSize(width: 4096, height: 4096)
        sl.shadowMode        = .deferred
        sl.orthographicScale = 40
        sl.shadowColor       = UIColor(white: 0, alpha: 0.55)
        sn.light = sl
        sn.eulerAngles = SCNVector3(-Float.pi / 4, Float.pi / 5, 0)
        scene.rootNode.addChildNode(sn)
        sunNode = sn; sunLight = sl

        // Sky fill (upward-facing area light simulating sky dome)
        let skyN = SCNNode(); let skyL = SCNLight()
        skyL.type      = .ambient
        skyL.intensity = 300
        skyL.color     = UIColor(rgb: 0xB8CEEE)
        skyN.light = skyL
        scene.rootNode.addChildNode(skyN)

        // Ground bounce (warm, low intensity)
        let groundN = SCNNode(); let groundL = SCNLight()
        groundL.type      = .ambient
        groundL.intensity = 80
        groundL.color     = UIColor(rgb: 0xFFE8C0)
        groundN.light = groundL
        scene.rootNode.addChildNode(groundN)

        // Main ambient (keyed per TOD)
        let an = SCNNode(); let al = SCNLight()
        al.type      = .ambient
        al.intensity = 450
        al.color     = UIColor(white: 0.92, alpha: 1)
        an.light = al
        scene.rootNode.addChildNode(an)
        ambientNode = an; ambientLight = al
    }

    // MARK: IBL

    private func configureIBL(scene: SCNScene) {
        if let hdr = UIImage(named: "remastered_skybox.hdr") {
            scene.lightingEnvironment.contents  = hdr
            scene.lightingEnvironment.intensity = 1.4
            scene.background.contents           = hdr
        } else {
            // Procedural sky gradient (replaced per TOD below)
            scene.lightingEnvironment.intensity = 1.0
            scene.background.contents           = UIColor(rgb: 0x9EC3E8)
        }
    }

    // MARK: SCNView + camera settings

    func configureView(_ scnView: SCNView, quality: GraphicsQuality) {
        self.quality = quality
        scnView.preferredFramesPerSecond = 120
        scnView.antialiasingMode         = quality == .low ? .none : .multisampling4X
        scnView.rendersContinuously      = true
        scnView.showsStatistics          = false
    }

    func configureCamera(_ camera: SCNCamera, quality: GraphicsQuality) {
        camera.fieldOfView        = 65
        camera.zNear              = 0.1
        camera.zFar               = 350
        camera.wantsHDR           = quality != .low
        camera.exposureOffset     = 0
        camera.minimumExposure    = -2
        camera.maximumExposure    = 2

        switch quality {
        case .low:
            camera.bloomIntensity      = 0
            camera.motionBlurIntensity = 0
            camera.screenSpaceAmbientOcclusionIntensity = 0
        case .high:
            camera.bloomIntensity      = 0.5
            camera.bloomThreshold      = 0.8
            camera.bloomBlurRadius     = 4
            camera.motionBlurIntensity = 0
            camera.screenSpaceAmbientOcclusionIntensity = 0.7
            camera.screenSpaceAmbientOcclusionRadius    = 5
            camera.screenSpaceAmbientOcclusionBias      = 0.03
        case .ultra:
            camera.bloomIntensity      = 0.7
            camera.bloomThreshold      = 0.65
            camera.bloomBlurRadius     = 6
            camera.motionBlurIntensity = 0.35
            camera.screenSpaceAmbientOcclusionIntensity = 1.0
            camera.screenSpaceAmbientOcclusionRadius    = 7
            camera.screenSpaceAmbientOcclusionBias      = 0.025
            camera.wantsDepthOfField = false  // off for action
        }
    }

    // MARK: Time of day

    func apply(tod: TimeOfDayPreset) {
        timeOfDay  = tod
        nightValue = tod.nightBlend

        sunLight?.intensity    = tod.sunIntensity
        sunLight?.temperature  = tod.sunTemperature
        sunNode?.eulerAngles   = SCNVector3(tod.sunAngleX, tod.sunAngleY, 0)

        ambientLight?.intensity = tod.ambientIntensity
        ambientLight?.color     = tod.ambientColor

        sceneRef?.fogColor           = tod.fogColor
        sceneRef?.fogStartDistance   = tod.fogStart
        sceneRef?.fogEndDistance     = tod.fogEnd
        sceneRef?.fogDensityExponent = 1.2

        // Sky gradient background
        let skyImg = makeSkyGradient(top: tod.skyTop, horizon: tod.skyHorizon)
        sceneRef?.background.contents = skyImg

        // Push night value into all registered shader materials
        updateNightUniforms()
    }

    func cycleTimeOfDay() {
        switch timeOfDay.label {
        case "Day":     apply(tod: .goldenHour)
        case "Golden":  apply(tod: .dusk)
        default:        apply(tod: .day)
        }
    }

    // MARK: Register materials for per-frame night uniform updates

    func registerShaderMaterials(_ materials: [SCNMaterial]) {
        shaderMaterials.append(contentsOf: materials)
    }

    func updateNightUniforms() {
        let n = NSNumber(value: nightValue)
        for m in shaderMaterials {
            m.setValue(n, forKey: "uNight")
        }
        Mat.setNight(nightValue)
    }

    // MARK: Node material routing

    /// Walk `root` hierarchy and apply the correct MaterialLibrary shader for each semantic node name.
    func applyMaterials(to root: SCNNode, shaderMats: inout [SCNMaterial]) {
        root.enumerateChildNodes { node, _ in
            guard let geo = node.geometry else { return }
            node.castsShadow = true
            let name = (node.name ?? "").lowercased()

            let mat: SCNMaterial?
            switch true {
            case name.contains("road") || name.contains("street"):
                mat = Mat.surface(Palette.road, rough: 0.92, shader: Shaders.road)
            case name.contains("sidewalk") || name.contains("pavement"):
                mat = Mat.surface(Palette.sidewalk, rough: 0.95, shader: Shaders.sidewalk)
            case name.contains("park") || name.contains("grass"):
                mat = Mat.surface(Palette.park, rough: 0.9, shader: Shaders.ground)
            case name.contains("building") || name.contains("facade"):
                let idx = Int(abs(node.worldPosition.x + node.worldPosition.z)) % Palette.buildings.count
                mat = Mat.surface(Palette.buildings[idx], rough: 0.85, shader: Shaders.building)
            case name.contains("water") || name.contains("ocean"):
                mat = Mat.surface(Palette.water, rough: 0.08, metal: 0.1, shader: Shaders.water)
            case name.contains("ledge") || name.contains("kicker") || name.contains("concrete"):
                mat = Mat.surface(Palette.concrete, rough: 0.88, shader: Shaders.concrete)
            case name.contains("plank") || name.contains("pier"):
                mat = Mat.surface(Palette.wood, rough: 0.8, shader: Shaders.planks)
            case name.contains("rail"):
                mat = Mat.pbr(Palette.rail, rough: 0.3, metal: 0.8)
            case name.contains("truck") || name.contains("axle"):
                mat = Mat.pbr(0xAAB2BC, rough: 0.35, metal: 0.85)
            case name.contains("wheel") || name.contains("urethane"):
                mat = Mat.pbr(0xF6EFE0, rough: 0.65)
            case name.contains("deck") || name.contains("board"):
                mat = nil  // handled separately (scratch shader)
            case name.contains("tree") || name.contains("leaf") || name.contains("foliage"):
                let leaf = Mat.surface(0x7FB86A, rough: 0.8, shader: Shaders.leaves)
                leaf.shaderModifiers?[.geometry] = Shaders.wind
                mat = leaf
            default:
                mat = nil
            }

            if let mat {
                geo.materials = [mat]
                if mat.shaderModifiers != nil { shaderMats.append(mat) }
            } else if geo.firstMaterial?.lightingModel != .physicallyBased {
                // Fallback: ensure PBR on any unrecognised mesh
                for m in geo.materials { m.lightingModel = .physicallyBased }
            }
        }
    }

    // MARK: SCNTechnique — ACES post-processing

    func makePostFXTechnique(quality: GraphicsQuality) -> SCNTechnique? {
        guard quality != .low else { return nil }

        let dict: [String: Any] = [
            "targets": [
                "hdrBuffer": [
                    "type": "color",
                    "scaleFactor": 1.0,
                    "format": "RGBA16F"
                ]
            ],
            "passes": [
                "renderScene": [
                    "draw": "DRAW_SCENE",
                    "colorStates": [["attachment": "hdrBuffer", "clear": false]],
                    "depthStates":  ["clear": true, "enabled": true]
                ],
                "postfx": [
                    "draw":                "DRAW_QUAD",
                    "metalVertexShader":   "postfx_vert",
                    "metalFragmentShader": "postfx_frag",
                    "inputs":  ["colorTex": "hdrBuffer"],
                    "outputs": ["color": "COLOR"]
                ]
            ],
            "sequence": ["renderScene", "postfx"]
        ]
        return SCNTechnique(dictionary: dict)
    }

    // MARK: Grind spark particle system

    func makeGrindSparks() -> SCNParticleSystem {
        let ps = SCNParticleSystem()
        ps.birthRate           = 0
        ps.birthRateVariation  = 0
        ps.particleSize        = 0.018
        ps.particleSizeVariation = 0.012
        ps.particleLifeSpan    = 0.45
        ps.particleLifeSpanVariation = 0.2
        ps.particleVelocity    = 2.8
        ps.particleVelocityVariation = 1.4
        ps.emittingDirection   = SCNVector3(0, 1, 0)
        ps.spreadingAngle      = 60
        ps.particleColor       = UIColor(rgb: 0xFFD060)
        ps.particleColorVariation = SCNVector4(0.1, 0.15, 0.4, 0.0)
        ps.isAffectedByGravity = true
        ps.blendMode           = .additive
        ps.loops               = true
        return ps
    }

    // MARK: Helpers

    private func makeSkyGradient(top: UIColor, horizon: UIColor) -> UIImage {
        let size = CGSize(width: 4, height: 256)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let c = ctx.cgContext
            let locs: [CGFloat] = [0, 1]
            let colors = [top.cgColor, horizon.cgColor] as CFArray
            let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: colors, locations: locs)!
            c.drawLinearGradient(grad,
                                 start: CGPoint(x: 0, y: 0),
                                 end:   CGPoint(x: 0, y: size.height),
                                 options: [])
        }
    }
}
#endif
