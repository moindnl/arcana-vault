import SwiftUI

struct ResultCardsRow: View {
    @Environment(AppState.self) private var state

    var body: some View {
        HStack(spacing: 12) {
            // Carbs card
            resultCard(
                icon: "leaf.fill",
                iconColor: Color(hex: "#f59e0b"),
                value: state.carbsPerHour,
                unit: "g/h",
                subtitle: "carbsSub"
            )

            // Fluids card
            resultCard(
                icon: "drop.fill",
                iconColor: Color(hex: "#3b82f6"),
                value: Double(Int(state.fluidPerHour * 10)) / 10,
                unit: "L/h",
                subtitle: "fluidsSub",
                isDouble: true
            )
        }
    }

    @ViewBuilder
    private func resultCard(
        icon: String,
        iconColor: Color,
        value: Any,
        unit: String,
        subtitle: LocalizedStringKey,
        isDouble: Bool = false
    ) -> some View {
        BPCard {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .foregroundStyle(iconColor)
                        .font(.subheadline)
                    Text(isDouble ? "fluids" : "carbohydrates", bundle: .main)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.secondaryLabel)
                }

                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    if isDouble, let d = value as? Double {
                        Text("\(d, specifier: "%.1f")")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.label)
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.4), value: d)
                    } else if let i = value as? Int {
                        Text("\(i)")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.label)
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.4), value: i)
                    }
                    Text(unit)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(Color.secondaryLabel)
                }

                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(Color.tertiaryLabel)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    let s = AppState()
    s.durationText = "2"
    s.powerText = "220"
    s.ftpText = "280"
    return ResultCardsRow()
        .environment(s)
        .padding()
        .background(Color.systemGroupedBackground)
}
