import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        if state.onboardingDone {
            MainView()
        } else {
            OnboardingView()
        }
    }
}

#Preview {
    ContentView()
        .environment(AppState())
}
