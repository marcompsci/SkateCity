import SwiftUI

struct ContentView: View {
    @AppStorage("onboardingComplete") private var onboardingComplete = false
    @EnvironmentObject var model: GameModel

    var body: some View {
        if !onboardingComplete {
            OnboardingView()
                .ignoresSafeArea()
        } else {
            RootView()
                .ignoresSafeArea()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(GameModel())
}
