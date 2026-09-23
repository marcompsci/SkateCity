import SceneKit

/// Loads .glb (glTF 2.0 binary) assets via SCNScene and vends cloned SCNNodes.
///
/// Production path: add .glb files to the Xcode project as bundle resources.
/// Dev / Simulator path: automatically resolves to SkateCity.Draft/assets-glb/ on the
/// local Desktop so assets work during development without a manual import step.
/// When a file cannot be resolved, returns nil — callers (SkateCityMapBuilder) have
/// SceneKit-primitive fallbacks for every obstacle.
final class GLBAssetLoader {

    // MARK: - Asset catalogue (filenames match SkateCity.Draft/assets-glb/)

    enum AssetName: String, CaseIterable {
        case avatar
        case bench
        case building
        case carHatch       = "car_hatch"
        case carSedan       = "car_sedan"
        case hailrRideshare = "hailr_rideshare"
        case kicker
        case ledge
        case mapPin         = "map_pin"
        case motorcycle
        case rail
        case skateboard
        case stairs
        case streetlight
        case tree
        case zippEbike      = "zipp_ebike"
        case zippEscooter   = "zipp_escooter"
    }

    // MARK: - Singleton + cache

    static let shared = GLBAssetLoader()
    private var cache: [String: SCNNode] = [:]
    private init() {}

    // MARK: - Public API

    /// Returns a cloned SCNNode for `asset`, or nil if the file cannot be resolved.
    /// Subsequent calls return a fresh clone from the in-memory cache (no disk IO).
    func loadNode(named asset: AssetName) -> SCNNode? {
        if let cached = cache[asset.rawValue] { return cached.clone() }
        guard let url  = resolveURL(for: asset),
              let scene = try? SCNScene(url: url) else { return nil }
        cache[asset.rawValue] = scene.rootNode
        return scene.rootNode.clone()
    }

    /// Background-thread bulk preload — call during a loading screen.
    func preload(_ assets: [AssetName]) async {
        await withTaskGroup(of: Void.self) { group in
            for asset in assets {
                group.addTask { _ = self.loadNode(named: asset) }
            }
        }
    }

    // MARK: - URL resolution

    private func resolveURL(for asset: AssetName) -> URL? {
        // 1. App bundle (production)
        if let url = Bundle.main.url(forResource: asset.rawValue, withExtension: "glb") {
            return url
        }
        // 2. Desktop Draft folder — Simulator / development only
        #if targetEnvironment(simulator)
        let path = "/Users/\(NSUserName())/Desktop/SkateCity App/SkateCity.Draft/assets-glb/\(asset.rawValue).glb"
        let url  = URL(fileURLWithPath: path)
        if FileManager.default.fileExists(atPath: url.path) { return url }
        #endif
        return nil
    }
}
