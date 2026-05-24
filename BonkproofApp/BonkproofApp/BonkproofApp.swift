import SwiftUI

@main
struct BonkproofApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .environment(\.locale, locale)
        }
    }

    private var locale: Locale {
        switch appState.language {
        case .en:     return Locale(identifier: "en")
        case .de:     return Locale(identifier: "de")
        case .system: return .autoupdatingCurrent
        }
    }
}
