import SwiftUI

struct MainView: View {
    @Environment(AppState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showResetShake = false

    private func anim(_ a: Animation) -> Animation? { reduceMotion ? nil : a }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    RideInputCard()

                    if state.hasDuration {
                        ResultCardsRow()
                            .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))

                        if state.hasPower {
                            PowerCard()
                                .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
                        }

                        TotalsCard()
                            .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
                    } else {
                        emptyState
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
                .animation(anim(.spring(response: 0.4, dampingFraction: 0.8)), value: state.hasDuration)
                .animation(anim(.spring(response: 0.4, dampingFraction: 0.8)), value: state.hasPower)
            }
            .background(Color.systemGroupedBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    logoView
                }
                ToolbarItem(placement: .primaryAction) {
                    settingsButton
                }
            }
            .sheet(isPresented: Binding(get: { state.showSettings }, set: { state.showSettings = $0 })) {
                SettingsSheet()
            }
            .sheet(isPresented: Binding(get: { state.showHowTo }, set: { state.showHowTo = $0 })) {
                HowToSheet()
            }
        }
        .onShake {
            showResetShake = true
        }
        .alert("resetRide", isPresented: $showResetShake) {
            Button("reset", role: .destructive) {
                withAnimation { state.resetRide() }
            }
            Button("cancel", role: .cancel) {}
        } message: {
            Text("Shake detected — reset all ride inputs?")
        }
    }

    // MARK: - Logo

    private var logoView: some View {
        Text("\(Text("bonk").italic().bold())\(Text("proof!").foregroundStyle(Color.bpAccent).bold())")
            .font(.title3)
    }

    // MARK: - Settings button

    private var settingsButton: some View {
        Button {
            state.showSettings = true
        } label: {
            Image(systemName: "gearshape")
                .font(.body.weight(.medium))
        }
        .accessibilityLabel("settings")
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bolt.circle")
                .font(.system(size: 44))
                .foregroundStyle(Color.tertiaryLabel)
            Text("emptyTitle", bundle: .main)
                .font(.headline)
                .foregroundStyle(Color.secondaryLabel)
            Text("emptyState", bundle: .main)
                .font(.subheadline)
                .foregroundStyle(Color.tertiaryLabel)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 48)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Shake gesture support

struct ShakeGestureModifier: ViewModifier {
    let action: () -> Void

    func body(content: Content) -> some View {
        content
            .background(ShakeDetector(action: action))
    }
}

extension View {
    func onShake(perform action: @escaping () -> Void) -> some View {
        modifier(ShakeGestureModifier(action: action))
    }
}

struct ShakeDetector: UIViewControllerRepresentable {
    let action: () -> Void

    func makeUIViewController(context: Context) -> ShakeViewController {
        let vc = ShakeViewController()
        vc.onShake = action
        return vc
    }

    func updateUIViewController(_ uiViewController: ShakeViewController, context: Context) {
        uiViewController.onShake = action
    }
}

class ShakeViewController: UIViewController {
    var onShake: (() -> Void)?

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            onShake?()
        }
    }
}

#Preview {
    MainView()
        .environment(AppState())
}
