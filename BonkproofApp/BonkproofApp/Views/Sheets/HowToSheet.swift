import SwiftUI

struct HowToSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss

    @State private var currentSlide: Int = 0
    @State private var triggered: [Int: Bool] = [:]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TabView(selection: $currentSlide) {
                    slide0.tag(0)
                    slide1.tag(1)
                    slide2.tag(2)
                    slide3.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: currentSlide)

                // Dot indicators
                HStack(spacing: 8) {
                    ForEach(0..<4) { i in
                        Circle()
                            .fill(i == currentSlide ? Color.label : Color.tertiaryLabel)
                            .frame(width: i == currentSlide ? 8 : 6,
                                   height: i == currentSlide ? 8 : 6)
                            .animation(.spring(response: 0.3), value: currentSlide)
                    }
                }
                .padding(.vertical, 12)

                // Next / Done button
                Button {
                    if currentSlide < 3 {
                        withAnimation(.spring(response: 0.35)) {
                            currentSlide += 1
                        }
                    } else {
                        dismiss()
                    }
                } label: {
                    Text(currentSlide < 3 ? LocalizedStringKey("onboardingNext") : LocalizedStringKey("done"))
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.bpAccent, in: RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .navigationTitle("howItWorks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("close") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Slide 0: Two inputs. One plan.

    private var slide0: some View {
        SlideContainer(
            title: "tourSlide0Title",
            subtitle: "tourSlide0Body"
        ) {
            Slide0Illustration(triggered: triggered[0] ?? false)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            triggered[0] = true
                        }
                    }
                }
        }
    }

    // MARK: - Slide 1: Zone targets

    private var slide1: some View {
        SlideContainer(
            title: "tourSlide1Title",
            subtitle: "tourSlide1Body"
        ) {
            Slide1ZoneChart(triggered: triggered[1] ?? false)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            triggered[1] = true
                        }
                    }
                }
        }
    }

    // MARK: - Slide 2: Schedule

    private var slide2: some View {
        SlideContainer(
            title: "tourSlide2Title",
            subtitle: "tourSlide2Body"
        ) {
            Slide2Schedule(triggered: triggered[2] ?? false)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            triggered[2] = true
                        }
                    }
                }
        }
    }

    // MARK: - Slide 3: Products

    private var slide3: some View {
        SlideContainer(
            title: "tourSlide3Title",
            subtitle: "tourSlide3Body"
        ) {
            Slide3Products(triggered: triggered[3] ?? false)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            triggered[3] = true
                        }
                    }
                }
        }
    }
}

// MARK: - Slide container

private struct SlideContainer<Content: View>: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 20) {
            content()
                .frame(height: 200)
                .padding(.top, 24)

            VStack(spacing: 8) {
                Text(title)
                    .font(.title3.weight(.bold))
                    .multilineTextAlignment(.center)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Color.secondaryLabel)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Spacer()
        }
    }
}

// MARK: - Slide 0 illustration

private struct Slide0Illustration: View {
    let triggered: Bool

    var body: some View {
        VStack(spacing: 12) {
            // Input row 1: Duration
            mockInputRow(
                icon: "clock",
                label: "Duration",
                value: "1:30h",
                delay: 0
            )

            // Input row 2: Power
            mockInputRow(
                icon: "bolt.fill",
                label: "Power",
                value: "220 W",
                delay: 0.18
            )

            // Arrow
            Image(systemName: "arrow.down")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.secondaryLabel)
                .opacity(triggered ? 1 : 0)
                .offset(y: triggered ? 0 : -10)
                .animation(.easeOut(duration: 0.3).delay(0.36), value: triggered)

            // Badge
            HStack(spacing: 6) {
                Circle()
                    .fill(Zone.tempo.color)
                    .frame(width: 8, height: 8)
                Text("Tempo · 60 g/h")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Zone.tempo.color)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Zone.tempo.color.opacity(0.12), in: Capsule())
            .opacity(triggered ? 1 : 0)
            .scaleEffect(triggered ? 1 : 0.7)
            .animation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.5), value: triggered)
        }
        .padding(.horizontal, 40)
    }

    private func mockInputRow(icon: String, label: String, value: String, delay: Double) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(Color.secondaryLabel)
                .frame(width: 22)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color.secondaryLabel)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.label)
        }
        .padding(12)
        .background(Color.systemBackground, in: RoundedRectangle(cornerRadius: 10))
        .opacity(triggered ? 1 : 0)
        .offset(x: triggered ? 0 : 20)
        .animation(.easeOut(duration: 0.3).delay(delay), value: triggered)
    }
}

// MARK: - Slide 1: Zone bar chart

private struct Slide1ZoneChart: View {
    let triggered: Bool

    private let bars: [(zone: Zone, label: String, height: CGFloat, carbs: String)] = [
        (.recovery,  "R",  30, "< 30"),
        (.endurance, "E",  55, "30–45"),
        (.tempo,     "T",  80, "45–60"),
        (.threshold, "S", 110, "60–90"),
        (.vo2max,    "V", 140, "90–120"),
    ]

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            ForEach(Array(bars.enumerated()), id: \.offset) { idx, bar in
                VStack(spacing: 4) {
                    Text(bar.carbs)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(idx == 3 ? Color.bpAccent : Color.secondaryLabel)
                        .fixedSize()

                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(bar.zone.color)
                        .frame(width: 34, height: triggered ? bar.height : 4)
                        .animation(
                            .spring(response: 0.5, dampingFraction: 0.7)
                                .delay(Double(idx) * 0.08),
                            value: triggered
                        )

                    Text(bar.label)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(bar.zone.color)
                }
            }
        }
    }
}

// MARK: - Slide 2: Schedule

private struct Slide2Schedule: View {
    let triggered: Bool

    private let events = [20, 40, 60, 80, 100]

    var body: some View {
        VStack(spacing: 16) {
            // Timeline dots
            HStack(spacing: 0) {
                ForEach(Array(events.enumerated()), id: \.offset) { idx, mins in
                    VStack(spacing: 8) {
                        Image(systemName: "fork.knife.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.bpAccent)
                            .opacity(triggered ? 1 : 0)
                            .scaleEffect(triggered ? 1 : 0.5)
                            .animation(
                                .spring(response: 0.4, dampingFraction: 0.6)
                                    .delay(Double(idx) * 0.12),
                                value: triggered
                            )

                        Circle()
                            .fill(Color.bpAccent)
                            .frame(width: 10, height: 10)
                            .opacity(triggered ? 1 : 0)
                            .animation(.easeOut(duration: 0.2).delay(Double(idx) * 0.12), value: triggered)

                        Text(formatMins(mins))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(Color.secondaryLabel)
                    }
                    .frame(maxWidth: .infinity)

                    if idx < events.count - 1 {
                        // Line segment
                        Rectangle()
                            .fill(Color.bpAccent.opacity(0.3))
                            .frame(height: 2)
                            .offset(y: 8)  // align with dots
                            .scaleEffect(x: triggered ? 1 : 0, anchor: .leading)
                            .animation(
                                .easeOut(duration: 0.3).delay(Double(idx) * 0.12 + 0.1),
                                value: triggered
                            )
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func formatMins(_ m: Int) -> String {
        String(format: "%d:%02d", m / 60, m % 60)
    }
}

// MARK: - Slide 3: Products

private struct Slide3Products: View {
    let triggered: Bool

    private let products: [(name: String, carbs: String, highlight: Bool)] = [
        ("SIS Beta Fuel",  "40g", true),
        ("Energy Gel",     "22g", false),
    ]

    var body: some View {
        VStack(spacing: 10) {
            ForEach(Array(products.enumerated()), id: \.offset) { idx, product in
                HStack(spacing: 12) {
                    Image(systemName: "figure.outdoor.cycle")
                        .font(.title3)
                        .foregroundStyle(product.highlight ? Color.bpAccent : Color.secondaryLabel)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(product.name)
                            .font(.subheadline.weight(.semibold))
                        Text("\(product.carbs) carbs per unit")
                            .font(.caption)
                            .foregroundStyle(Color.secondaryLabel)
                    }

                    Spacer()

                    if product.highlight {
                        Text("Custom")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.bpAccent, in: Capsule())
                    }
                }
                .padding(14)
                .background(
                    product.highlight ? Color.bpAccent.opacity(0.08) : Color.secondarySystemBackground,
                    in: RoundedRectangle(cornerRadius: 12)
                )
                .overlay(
                    product.highlight
                        ? RoundedRectangle(cornerRadius: 12).stroke(Color.bpAccent.opacity(0.3), lineWidth: 1)
                        : nil
                )
                .opacity(triggered ? 1 : 0)
                .offset(y: triggered ? 0 : 20)
                .animation(
                    .spring(response: 0.4, dampingFraction: 0.7).delay(Double(idx) * 0.15),
                    value: triggered
                )
            }
        }
        .padding(.horizontal, 24)
    }
}

#Preview {
    HowToSheet()
        .environment(AppState())
}
