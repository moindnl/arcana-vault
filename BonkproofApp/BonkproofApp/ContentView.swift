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
        // UIKit bridge: set window.overrideUserInterfaceStyle directly so
        // .system properly resets to .unspecified — SwiftUI's
        // .preferredColorScheme(nil) doesn't reliably clear the VC-level
        // override, but the window level propagates to all presented VCs
        // (sheets) without issues.
        .background(WindowThemeSetter(theme: state.theme))
    }
}

// MARK: - UIKit theme bridge

private struct WindowThemeSetter: UIViewRepresentable {
    let theme: AppTheme

    func makeUIView(context: Context) -> UIView { UIView() }

    func updateUIView(_ uiView: UIView, context: Context) {
        let style: UIUserInterfaceStyle = {
            switch theme {
            case .light:  return .light
            case .dark:   return .dark
            case .system: return .unspecified
            }
        }()
        // Async so uiView.window is guaranteed non-nil (view is in hierarchy).
        DispatchQueue.main.async {
            uiView.window?.overrideUserInterfaceStyle = style
        }
    }
}

#Preview {
    ContentView()
        .environment(AppState())
}
