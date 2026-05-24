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
        .environment(\.locale, locale)
    }

    private var colorScheme: ColorScheme? {
        switch state.theme {
        case .light:  return .light
        case .dark:   return .dark
        case .system: return nil
        }
    }

    /// Map AppLanguage → Locale so String(localized:) resolves correctly.
    private var locale: Locale {
        switch state.language {
        case .en:     return Locale(identifier: "en")
        case .de:     return Locale(identifier: "de")
        case .system: return .autoupdatingCurrent
        }
    }
}

#Preview {
    ContentView()
        .environment(AppState())
}
