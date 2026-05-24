import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        Group {
            if state.onboardingDone {
                MainView()
            } else {
                OnboardingView()
            }
        }
        .preferredColorScheme(colorScheme)
    }

    private var colorScheme: ColorScheme? {
        switch state.theme {
        case .light:  return .light
        case .dark:   return .dark
        case .system: return nil
        }
    }
}

#Preview {
    ContentView()
        .environment(AppState())
}
