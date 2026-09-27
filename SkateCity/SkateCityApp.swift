import SwiftUI
import SwiftData

/// Global physics category bitmask used by GameEngine + World.
let solidCategory: Int = 2

@main
struct SkateCityApp: App {
    @StateObject private var model = GameModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .preferredColorScheme(.dark)
                .statusBarHidden()
                .persistentSystemOverlays(.hidden)
        }
        .modelContainer(for: [PlayerProfile.self, SkateComboRecord.self])
    }
}
