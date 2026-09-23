import SwiftUI

struct ContentView: View {
    @AppStorage("onboardingComplete") private var onboardingComplete = false

    var body: some View {
        if !onboardingComplete {
            OnboardingView()
                .ignoresSafeArea()
        } else {
            #if os(iOS)
            SkateCityGameView()
                .ignoresSafeArea()
                .statusBarHidden(true)
                .persistentSystemOverlays(.hidden)
            #else
            Text("SkateCity runs on iPhone and iPad.")
                .font(.title2)
                .foregroundStyle(.secondary)
            #endif
        }
    }
}

#if os(iOS)
/// Bridges GameViewController (UIKit/SceneKit) into the SwiftUI hierarchy.
struct SkateCityGameView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> GameViewController {
        GameViewController()
    }
    func updateUIViewController(_ uiViewController: GameViewController, context: Context) {}
}
#endif

#Preview {
    ContentView()
}
