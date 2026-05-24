import SwiftUI

struct RideInputCard: View {
    @Environment(AppState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focusedField: Field?

    private func anim(_ a: Animation) -> Animation? { reduceMotion ? nil : a }

    // Swipe-to-reset gesture state
    @State private var dragOffset: CGFloat = 0
    @State private var isResetRevealed = false

    // Long-press reset state
    @State private var holdProgress: CGFloat = 0
    @State private var holdTimer: Timer? = nil
    @State private var showNeuralizer = false
    @State private var showResetConfirm = false

    enum Field: Hashable { case distance, duration, power }

    private var hasAnyInput: Bool {
        !state.distanceText.isEmpty || !state.durationText.isEmpty || !state.powerText.isEmpty
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            // Red reset zone (revealed on swipe)
            resetZoneBackground

            // Card content (draggable)
            cardContent
                .offset(x: dragOffset)
                .gesture(swipeGesture)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .fullScreenCover(isPresented: $showNeuralizer) {
            NeuralizerFlashView()
        }
        .alert("resetRide", isPresented: $showResetConfirm) {
            Button("reset", role: .destructive) { performReset() }
            Button("cancel", role: .cancel) {}
        } message: {
            Text("All ride inputs will be cleared.")
        }
    }

    // MARK: - Card content

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("rideLabel", bundle: .main)
                    .font(.headline.weight(.semibold))
                Spacer()
                if hasAnyInput {
                    resetButton
                }
            }
            .padding(.bottom, 14)

            // Distance (optional)
            inputRow(
                icon: "arrow.right",
                label: "distanceFull",
                placeholder: state.imperial ? "mi" : "km",
                text: Binding(get: { state.distanceText }, set: { state.distanceText = $0 }),
                keyboardType: .decimalPad,
                field: .distance
            )

            Divider().padding(.vertical, 10)

            // Duration
            inputRow(
                icon: "clock",
                label: "durationLabel",
                placeholder: "durationHint",
                text: Binding(get: { state.durationText }, set: { state.durationText = $0 }),
                keyboardType: .numbersAndPunctuation,
                field: .duration
            )

            Divider().padding(.vertical, 10)

            // Power
            inputRow(
                icon: "bolt.fill",
                label: "ridePower",
                placeholder: "W",
                text: Binding(get: { state.powerText }, set: { state.powerText = $0 }),
                keyboardType: .numberPad,
                field: .power
            )

            Divider().padding(.vertical, 10)

            // Zone row
            zoneRow

            Divider().padding(.vertical, 10)

            // Temperature
            temperatureRow
        }
        .padding(16)
        .glassEffect(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("done") { focusedField = nil }
            }
        }
    }

    // MARK: - Input row helper

    private func inputRow(
        icon: String,
        label: LocalizedStringKey,
        placeholder: LocalizedStringKey,
        text: Binding<String>,
        keyboardType: UIKeyboardType,
        field: Field
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(Color.secondaryLabel)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.secondaryLabel)
                TextField(placeholder, text: text)
                    .keyboardType(keyboardType)
                    .focused($focusedField, equals: field)
                    .font(.body)
                    .accessibilityLabel(label)
            }
        }
    }

    // MARK: - Zone row

    private var zoneRow: some View {
        HStack {
            Image(systemName: "waveform.path")
                .foregroundStyle(Color.secondaryLabel)
                .frame(width: 20)
            Text("zoneLabel", bundle: .main)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.secondaryLabel)
            Spacer()
            Group {
                if state.hasFTP && state.hasPower {
                    ZoneBadge(
                        zone: state.zone,
                        ifPct: Int((state.intensityFactor * 100).rounded())
                    )
                    .transition(.opacity)
                } else if state.hasPower && !state.hasFTP {
                    Button {
                        state.showSettings = true
                    } label: {
                        Label("setFtpFirst", systemImage: "slider.horizontal.3")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.bpAccent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.bpAccent.opacity(0.1), in: Capsule())
                    }
                    .transition(.opacity)
                } else {
                    Text("—")
                        .font(.caption)
                        .foregroundStyle(Color.tertiaryLabel)
                        .transition(.opacity)
                }
            }
            .animation(anim(.spring(response: 0.3, dampingFraction: 0.8)), value: state.hasFTP && state.hasPower)
            .animation(anim(.spring(response: 0.3, dampingFraction: 0.8)), value: state.hasPower)
        }
    }

    // MARK: - Temperature row

    private var temperatureRow: some View {
        @Bindable var s = state
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "thermometer.medium")
                    .foregroundStyle(temperatureColor)
                    .frame(width: 20)
                Text("temperature", bundle: .main)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.secondaryLabel)
                Spacer()
                Text("\(Int(state.temperature))°C")
                    .font(.body.monospacedDigit())
                    .foregroundStyle(temperatureColor)
            }
            Slider(value: $s.temperature, in: 0...45, step: 1)
                .tint(temperatureColor)

            if state.heatBonus > 0 {
                Text("+\(state.heatBonus, specifier: "%.1f") L/h heat bonus")
                    .font(.caption)
                    .foregroundStyle(Color(hex: "#ef4444"))
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var temperatureColor: Color {
        let t = state.temperature
        if t <= 20 { return Color.secondaryLabel }
        let pct = min(1, (t - 20) / 25)
        return Color(
            red:   0.3 + pct * 0.7,
            green: max(0, 0.4 - pct * 0.4),
            blue:  max(0, 0.4 - pct * 0.4)
        )
    }

    // MARK: - Reset button (hold 2s)

    private var resetButton: some View {
        ZStack {
            Circle()
                .stroke(Color.separator, lineWidth: 1.5)
                .frame(width: 32, height: 32)
            if holdProgress > 0 {
                Circle()
                    .trim(from: 0, to: holdProgress)
                    .stroke(Color.bpAccent, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: 32, height: 32)
                    .rotationEffect(.degrees(-90))
                    .animation(anim(.linear), value: holdProgress)
            }
            Image(systemName: "xmark")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.secondaryLabel)
        }
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
        .accessibilityLabel("resetRide")
        .accessibilityHint("resetRideHint")
        .onLongPressGesture(minimumDuration: 3, pressing: { pressing in
            if pressing {
                startHoldTimer()
            } else {
                cancelHoldTimer()
            }
        }, perform: {
            // 3+ second hold — neuralyzer
            showNeuralizer = true
            performReset()
        })
        .simultaneousGesture(
            TapGesture().onEnded {
                showResetConfirm = true
            }
        )
    }

    private func startHoldTimer() {
        holdProgress = 0
        var elapsed: CGFloat = 0
        holdTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            elapsed += 0.05
            holdProgress = min(elapsed / 2.0, 1.0)
            if elapsed >= 2.0 {
                timer.invalidate()
            }
        }
    }

    private func cancelHoldTimer() {
        holdTimer?.invalidate()
        holdTimer = nil
        withAnimation { holdProgress = 0 }
    }

    // MARK: - Swipe to reset

    private var resetZoneBackground: some View {
        HStack {
            Spacer()
            VStack(spacing: 6) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.title3.weight(.semibold))
                Text("reset")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(.white)
            .frame(width: 80)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bpAccent)
        .opacity(dragOffset < 0 ? Double(-dragOffset) / 80 : 0)
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                guard value.translation.width < 0 else { return }
                dragOffset = max(-120, value.translation.width)
            }
            .onEnded { value in
                if dragOffset <= -80 {
                    // Snap to revealed
                    withAnimation(anim(.spring(response: 0.3))) {
                        dragOffset = -80
                        isResetRevealed = true
                    }
                    // After short delay, trigger reset
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        performReset()
                        withAnimation(anim(.spring(response: 0.3))) {
                            dragOffset = 0
                            isResetRevealed = false
                        }
                    }
                } else {
                    withAnimation(anim(.spring(response: 0.3))) {
                        dragOffset = 0
                        isResetRevealed = false
                    }
                }
            }
    }

    private func performReset() {
        withAnimation {
            state.resetRide()
        }
    }
}

// MARK: - Neuralyzer flash

private struct NeuralizerFlashView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()
                .opacity(opacity)
            VStack(spacing: 20) {
                Image(systemName: "memorychip")
                    .font(.system(size: 60))
                    .foregroundStyle(.black.opacity(0.6))
                Text("Hm? There was no ride...")
                    .font(.title2.weight(.medium))
                    .foregroundStyle(.black.opacity(0.7))
            }
            .opacity(opacity > 0.5 ? (opacity - 0.5) * 2 : 0)
        }
        .onAppear {
            withAnimation(.easeIn(duration: 0.15)) { opacity = 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeOut(duration: 0.4)) { opacity = 0 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    dismiss()
                }
            }
        }
    }
}
