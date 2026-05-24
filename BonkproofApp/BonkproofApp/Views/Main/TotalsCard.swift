import SwiftUI

struct TotalsCard: View {
    @Environment(AppState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private func anim(_ a: Animation) -> Animation? { reduceMotion ? nil : a }

    enum Tab: String, CaseIterable {
        case overview  = "tabTotals"
        case checklist = "tabPack"
    }

    @State private var activeTab: Tab = .overview

    var body: some View {
        BPCard(cornerRadius: 16, padding: 0, background: Color.bpDarkCard) {
            VStack(spacing: 0) {
                tabBar
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                Divider()
                    .background(Color.white.opacity(0.12))

                switch activeTab {
                case .overview:  overviewTab.padding(16)
                case .checklist: checklistTab.padding(16)
                }
            }
        }
    }

    // MARK: - Tab bar

    private var tabBar: some View {
        DarkSegmentedPicker(
            options: Tab.allCases,
            selection: $activeTab,
            label: { tab in LocalizedStringKey(tab.rawValue) }
        )
    }

    // MARK: - Overview tab

    private var overviewTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            Text("totalNeeds")
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.white.opacity(0.55))

            // 3-column grid
            HStack(spacing: 0) {
                totalCell(value: "\(state.totalCarbs)", unit: "g", label: "carbs")
                Divider().frame(height: 40).background(Color.white.opacity(0.15))
                totalCell(value: "\(state.totalKcal)", unit: "kcal", label: "energy")
                Divider().frame(height: 40).background(Color.white.opacity(0.15))
                totalCell(value: String(format: "%.1f", state.totalFluid), unit: "L", label: "fluids")
            }
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))

            // Solid food picker
            solidFoodSection

            // Fueling schedule
            if !state.fuelingEvents.isEmpty {
                fuelingScheduleSection
            }
        }
    }

    private func totalCell(value: String, unit: String, label: LocalizedStringKey) -> some View {
        VStack(spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(verbatim: value)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                Text(verbatim: unit)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.6))
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    // MARK: - Solid food section

    @ViewBuilder
    private var solidFoodSection: some View {
        @Bindable var s = state
        VStack(alignment: .leading, spacing: 8) {
            Text("solidFood", bundle: .main)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.white.opacity(0.55))

            Menu {
                ForEach(state.allSolidProducts) { product in
                    Button {
                        s.solidProductId = product.id
                    } label: {
                        HStack {
                            Text(LocalizedStringKey(product.localizedNameKey))
                            Spacer()
                            Text("\(String(product.carbs))g")
                                .foregroundStyle(Color.secondaryLabel)
                        }
                    }
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(LocalizedStringKey(state.activeSolid.localizedNameKey))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text("\(String(state.activeSolid.carbs))g carbs per unit · \(String(state.totalSolidUnits)) needed")
                            .font(.caption)
                            .foregroundStyle(Color.white.opacity(0.6))
                    }
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.5))
                }
                .padding(12)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    // MARK: - Fueling schedule

    private var fuelingScheduleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("fuelingSchedule")
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.white.opacity(0.55))

            LazyVStack(spacing: 4) {
                ForEach(state.fuelingEvents) { event in
                    HStack {
                        Text(verbatim: formatMinutes(event.minuteMark))
                            .font(.caption.monospacedDigit().weight(.medium))
                            .foregroundStyle(Color.white.opacity(0.7))
                            .frame(width: 42, alignment: .leading)

                        if event.units > 0 {
                            (Text(verbatim: "\(event.units)× ") + Text(LocalizedStringKey(state.activeSolid.localizedNameKey)))
                                .font(.caption)
                                .foregroundStyle(.white)
                            Text(verbatim: "(\(event.actualCarbs)g)")
                                .font(.caption)
                                .foregroundStyle(Color.white.opacity(0.5))
                        } else {
                            Text("noSolidNeeded")
                                .font(.caption)
                                .foregroundStyle(Color.white.opacity(0.35))
                        }
                        Spacer()
                    }
                    .padding(.vertical, 5)
                    .padding(.horizontal, 10)
                    .background(Color.white.opacity(event.units > 0 ? 0.05 : 0.02),
                                in: RoundedRectangle(cornerRadius: 7))
                }
            }
        }
    }

    private func formatMinutes(_ mins: Int) -> String {
        let h = mins / 60
        let m = mins % 60
        return String(format: "%d:%02d", h, m)
    }

    // MARK: - Checklist tab

    private var checklistTab: some View {
        @Bindable var s = state
        return VStack(alignment: .leading, spacing: 16) {
            // Drink type
            drinkSection

            Divider().background(Color.white.opacity(0.12))

            // Bottle size
            bottleSizeSection

            Divider().background(Color.white.opacity(0.12))

            // Pack list
            packListSection
        }
    }

    @ViewBuilder
    private var drinkSection: some View {
        @Bindable var s = state
        VStack(alignment: .leading, spacing: 8) {
            Text("drinkType", bundle: .main)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.white.opacity(0.55))

            DarkSegmentedPicker(
                options: DrinkProduct.defaults,
                selection: Binding(
                    get: { s.activeDrink },
                    set: { s.drinkProductId = $0.id }
                ),
                label: { LocalizedStringKey($0.id) }
            )
        }
    }

    @ViewBuilder
    private var bottleSizeSection: some View {
        @Bindable var s = state
        VStack(alignment: .leading, spacing: 8) {
            Text("bottleSize", bundle: .main)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.white.opacity(0.55))

            DarkSegmentedPicker(
                options: [500, 750, 1000],
                selection: $s.bottleSize,
                label: { size in
                    switch size {
                    case 1000: return "1 L"
                    case 750:  return "750 ml"
                    default:   return "500 ml"
                    }
                }
            )

            if state.bottleCount > 0 {
                Text("\(state.bottleCount)× \(state.mlPerBottle)ml per bottle")
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.5))
            }
        }
    }

    private var packListSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("packList")
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.white.opacity(0.55))

            VStack(spacing: 2) {
                ForEach(state.packItems) { item in
                    packRow(item: item)
                }
            }
        }
    }

    private func packRow(item: PackItem) -> some View {
        let isChecked = state.checkedPackItems.contains(item.id)
        return Button {
            withAnimation(anim(.spring(response: 0.25))) {
                if isChecked {
                    state.checkedPackItems.remove(item.id)
                } else {
                    state.checkedPackItems.insert(item.id)
                }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                    .foregroundStyle(isChecked ? Color.bpAccent : Color.white.opacity(0.5))
                    .font(.subheadline)
                packItemLabel(item)
                    .font(.subheadline)
                    .foregroundStyle(isChecked ? Color.white.opacity(0.4) : .white)
                    .strikethrough(isChecked, color: Color.white.opacity(0.3))
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(Color.white.opacity(isChecked ? 0.03 : 0.05),
                        in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func packItemLabel(_ item: PackItem) -> Text {
        switch item.content {
        case .bottles(let count, let ml):
            return Text("\(count)× \(ml)ml per bottle")
        case .solidFood(let units, let name):
            return Text(verbatim: "\(units)× ") + Text(LocalizedStringKey(name))
        case .key(let k):
            return Text(LocalizedStringKey(k))
        }
    }
}

#Preview {
    let s = AppState()
    s.durationText = "3"
    s.powerText    = "250"
    s.ftpText      = "280"
    s.weightText   = "72"
    return TotalsCard()
        .environment(s)
        .padding()
        .background(Color.systemGroupedBackground)
}
