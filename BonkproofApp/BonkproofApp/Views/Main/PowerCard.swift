import SwiftUI

struct PowerCard: View {
    @Environment(AppState.self) private var state
    @Environment(\.openURL) private var openURL

    var body: some View {
        BPCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(state.zone.color)
                        .font(.title3)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(Int(state.power))")
                                .font(.system(.title, design: .rounded, weight: .bold))
                                .foregroundStyle(Color.label)
                                .contentTransition(.numericText())
                                .animation(.spring(response: 0.4), value: Int(state.power))
                            Text("W")
                                .font(.callout.weight(.medium))
                                .foregroundStyle(Color.secondaryLabel)
                        }
                        Text("ridePower", bundle: .main)
                            .font(.caption)
                            .foregroundStyle(Color.secondaryLabel)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        ZoneBadge(
                            zone: state.zone,
                            ifPct: state.hasFTP ? Int((state.intensityFactor * 100).rounded()) : nil
                        )
                        if state.kcalPerHour > 0 {
                            Text("\(state.kcalPerHour) kcal/h")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Color.secondaryLabel)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.secondarySystemBackground, in: Capsule())
                        }
                    }
                }

                if state.hasDistance && state.speedKmh > 0 {
                    Divider()
                    speedRow
                }
            }
        }
    }

    private var speedRow: some View {
        let animal = NutritionEngine.speedAnimal(speedKmh: state.speedKmh)
        return HStack(spacing: 8) {
            Image(systemName: "gauge.with.needle")
                .foregroundStyle(Color.secondaryLabel)
                .font(.subheadline)

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(state.speedDisplay, specifier: "%.1f")")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(Color.label)
                    .contentTransition(.numericText())
                Text(state.speedUnit)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.secondaryLabel)
            }

            Spacer()

            Button {
                if let slug = animal.wikipediaSlug,
                   let url = URL(string: "https://en.wikipedia.org/wiki/\(slug)") {
                    openURL(url)
                }
            } label: {
                HStack(spacing: 4) {
                    Text(animal.emoji)
                        .font(.subheadline)
                    Text(animal.label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.label)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.secondarySystemBackground, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(animal.wikipediaSlug == nil)
        }
    }
}

#Preview {
    let s = AppState()
    s.powerText    = "280"
    s.ftpText      = "280"
    s.distanceText = "60"
    s.durationText = "2"
    return PowerCard()
        .environment(s)
        .padding()
        .background(Color.systemGroupedBackground)
}
