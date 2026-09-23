import SwiftUI
import SwiftData

@main
struct SkateCityApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [PlayerProfile.self, SkateComboRecord.self])
    }
}
