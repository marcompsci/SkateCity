#if os(iOS)
import SceneKit
import Foundation

/// Streams skatepark map geometry from On-Demand Resources (ODR),
/// then loads the resulting .scn asset into a ready-to-use SCNScene.
///
/// Setup:
///   1. Tag your .scn files in Xcode → Project Editor → Resource Tags.
///   2. Call loadRemoteSkatepark(named:completion:) with the matching tag.
///   3. Merge or replace the active scene with the returned SCNScene.
///   4. Call purgeActiveMapCache() when the player exits the level.
final class SkateMapLoader {

    static let shared = SkateMapLoader()
    private var currentRequest: NSBundleResourceRequest?
    private init() {}

    // MARK: - Load

    /// Downloads (if needed) and loads the .scn file whose ODR tag equals `mapTag`.
    /// The expected asset filename is `<mapTag>_geometry.scn`.
    func loadRemoteSkatepark(named mapTag: String,
                             completion: @escaping (Result<SCNScene, Error>) -> Void) {
        // Cancel any in-flight request before starting a new one
        currentRequest?.endAccessingResources()

        let request = NSBundleResourceRequest(tags: [mapTag])
        request.loadingPriority = NSBundleResourceRequestLoadingPriorityUrgent
        currentRequest = request

        request.beginAccessingResources { [weak self] error in
            guard let self else { return }

            if let error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }

            guard let url = Bundle.main.url(forResource: "\(mapTag)_geometry",
                                            withExtension: "scn") else {
                let err = NSError(
                    domain: "SkateEngine", code: 404,
                    userInfo: [NSLocalizedDescriptionKey:
                        "Asset \(mapTag)_geometry.scn not found in ODR packet."]
                )
                DispatchQueue.main.async { completion(.failure(err)) }
                return
            }

            do {
                let scene = try SCNScene(url: url)
                DispatchQueue.main.async { completion(.success(scene)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    // MARK: - Purge

    /// Releases the ODR bundle — call when the player exits the level to free flash storage.
    func purgeActiveMapCache() {
        currentRequest?.endAccessingResources()
        currentRequest = nil
    }
}
#endif
