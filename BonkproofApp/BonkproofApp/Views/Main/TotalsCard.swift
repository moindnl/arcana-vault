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
    @State private var contentVisible: Bool = true
    @State private var showProductPicker: Bool = false
    @State private var showConfetti: Bool = false
    @State private var preRideExpanded: Bool = false
    @State private var showNotifSheet: Bool = false
    @State private var pickedStartTime: Date = Date().addingTimeInterval(4 * 3600)
    @State private var notifDenied: Bool = false

    var body: some View {
        BPCard(cornerRadius: 16, padding: 0) {
            VStack(spacing: 0) {
                tabBar
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                Divider()

                Group {
                    if activeTab == .overview {
                        overviewTab.padding(16)
                    } else {
                        checklistTab.padding(16)
                    }
                }
                .opacity(contentVisible ? 1 : 0)
            }
        }
        .shadow(color: .black.opacity(0.18), radius: 16, y: 8)
        .overlay {
            if showConfetti && !reduceMotion {
                ConfettiView()
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .allowsHitTesting(false)
            }
        }
        .sheet(isPresented: $showNotifSheet) {
            PreRideNotifSheet(
                startTime: $pickedStartTime,
                onSchedule: { time in
                    guard let range = state.preRideCarbRange else { return }
                    Task {
                        let ok = await NotificationManager.schedulePreRideMeal(
                            startTime: time,
                            carbMin: range.min,
                            carbMax: range.max,
                            isGerman: state.isGermanUI
                        )
                        await MainActor.run {
                            if ok {
                                state.preRideNotificationStartTime = time
                            } else {
                                notifDenied = true
                            }
                        }
                    }
                }
            )
        }
        .alert("notifDeniedTitle", isPresented: $notifDenied) {
            Button("notifDeniedSettings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("cancel", role: .cancel) {}
        } message: {
            Text("notifDeniedBody")
        }
    }

    // MARK: - Tab bar

    private var tabBar: some View {
        SegmentedPicker(
            options: Tab.allCases,
            selection: Binding(
                get: { activeTab },
                set: { newTab in
                    guard newTab != activeTab else { return }
                    if reduceMotion {
                        activeTab = newTab
                    } else {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            contentVisible = false
                        } completion: {
                            activeTab = newTab
                            withAnimation(.easeInOut(duration: 0.15)) {
                                contentVisible = true
                            }
                        }
                    }
                }
            ),
            label: { tab in LocalizedStringKey(tab.rawValue) },
            backgroundColor: Color.primary.opacity(0.1)
        )
    }

    // MARK: - Overview tab

    private var overviewTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            Text("totalNeeds")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            // 3-column grid
            HStack(spacing: 0) {
                totalCell(value: "\(state.totalCarbs)", unit: "g", label: "carbs")
                Divider().frame(height: 40)
                totalCell(value: "\(state.totalKcal)", unit: "kcal", label: "energy")
                Divider().frame(height: 40)
                totalCell(value: String(format: "%.1f", state.totalFluid), unit: "L", label: "fluids")
            }
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))

            // Solid food picker
            solidFoodSection

            // Fueling schedule
            if !state.fuelingEvents.isEmpty {
                fuelingScheduleSection
            }

            // Pre-ride meal
            if state.preRideCarbRange != nil {
                preRideMealSection
            }
        }
    }

    private func totalCell(value: String, unit: String, label: LocalizedStringKey) -> some View {
        VStack(spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(verbatim: value)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                Text(verbatim: unit)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
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
                .foregroundStyle(.secondary)

            Button {
                showProductPicker = true
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(LocalizedStringKey(state.activeSolid.localizedNameKey))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("\(String(state.activeSolid.carbs))g carbs per unit · \(String(state.totalSolidUnits)) needed")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .confirmationDialog("solidFood", isPresented: $showProductPicker, titleVisibility: .visible) {
                ForEach(state.allSolidProducts) { product in
                    Button {
                        s.solidProductId = product.id
                    } label: {
                        HStack {
                            Text(LocalizedStringKey(product.localizedNameKey))
                            Text("(\(product.carbs)g)")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Fueling schedule

    private var fuelingScheduleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("fuelingSchedule")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            LazyVStack(spacing: 4) {
                ForEach(state.fuelingEvents) { event in
                    HStack {
                        Text(verbatim: formatMinutes(event.minuteMark))
                            .font(.caption.monospacedDigit().weight(.medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 42, alignment: .leading)

                        if event.units > 0 {
                            Text(verbatim: "\(event.units)× ")
                                .font(.caption)
                                .foregroundStyle(.primary)
                            Text(LocalizedStringKey(state.activeSolid.localizedNameKey))
                                .font(.caption)
                                .foregroundStyle(.primary)
                            Text(verbatim: "(\(event.actualCarbs)g)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("noSolidNeeded")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 5)
                    .padding(.horizontal, 10)
                    .background(Color.primary.opacity(event.units > 0 ? 0.05 : 0.02),
                                in: RoundedRectangle(cornerRadius: 7))
                }
            }
        }
    }

    // MARK: - Pre-ride meal section

    private var preRideMealSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("preRideMeal")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                // Header row — always visible, tap to expand
                Button {
                    withAnimation(anim(.spring(response: 0.35, dampingFraction: 0.8))) {
                        preRideExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "fork.knife")
                            .foregroundStyle(Color.bpSuccess)
                            .font(.subheadline)
                            .frame(width: 20)
                        if let range = state.preRideCarbRange {
                            Text(verbatim: "\(range.min)–\(range.max) g carbs")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(preRideExpanded ? 90 : 0))
                    }
                    .padding(12)
                }
                .buttonStyle(.plain)

                // Expanded detail
                if preRideExpanded {
                    Divider()
                        .padding(.horizontal, 12)

                    VStack(alignment: .leading, spacing: 10) {
                        if let range = state.preRideCarbRange {
                            // Formula breakdown
                            HStack(spacing: 4) {
                                Text(verbatim: "\(Int(state.weight)) kg × 3–4 g =")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                Text(verbatim: "\(range.min)–\(range.max) g")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.primary)
                            }
                        }

                        Text("preRideMealExplain")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        // Food chips
                        FlowLayout(spacing: 6) {
                            ForEach(["preRideFood1", "preRideFood2", "preRideFood3",
                                     "preRideFood4", "preRideFood5", "preRideFood6"], id: \.self) { key in
                                Text(LocalizedStringKey(key))
                                    .font(.caption.weight(.medium))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.bpSuccess.opacity(0.12),
                                                in: Capsule())
                                    .foregroundStyle(Color.bpSuccess)
                            }
                        }

                        Divider()

                        // Notification reminder row
                        notifRow
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
            }
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
            .task(id: state.preRideNotificationStartTime) {
                // Clean up expired reminder state outside the view body
                if let t = state.preRideNotificationStartTime, t < Date.now {
                    state.preRideNotificationStartTime = nil
                }
            }
        }
    }

    @ViewBuilder
    private var notifRow: some View {
        let isExpired = state.preRideNotificationStartTime.map { $0 < Date.now } ?? false

        if let startTime = state.preRideNotificationStartTime, !isExpired {
            // Reminder set — show fire time + cancel
            let fireTime = startTime.addingTimeInterval(-3 * 3600)
            HStack(spacing: 8) {
                Image(systemName: "bell.fill")
                    .font(.caption)
                    .foregroundStyle(Color.bpSuccess)
                Text(fireTime, style: .time)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Text("notifSetLabel")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    NotificationManager.cancelPreRideMeal()
                    state.preRideNotificationStartTime = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            // No reminder set
            Button {
                pickedStartTime = Date().addingTimeInterval(4 * 3600)
                showNotifSheet = true
            } label: {
                Label("notifSetReminder", systemImage: "bell")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.bpAccent)
            }
            .buttonStyle(.plain)
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

            Divider()

            // Bottle size
            bottleSizeSection

            Divider()

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
                .foregroundStyle(.secondary)

            SegmentedPicker(
                options: DrinkProduct.defaults,
                selection: Binding(
                    get: { s.activeDrink },
                    set: { s.drinkProductId = $0.id }
                ),
                label: { LocalizedStringKey($0.id) },
                backgroundColor: Color.primary.opacity(0.1)
            )
        }
    }

    @ViewBuilder
    private var bottleSizeSection: some View {
        @Bindable var s = state
        VStack(alignment: .leading, spacing: 8) {
            Text("bottleSize", bundle: .main)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            SegmentedPicker(
                options: [500, 750, 1000],
                selection: $s.bottleSize,
                label: { size -> LocalizedStringKey in
                    switch size {
                    case 1000: return "1 L"
                    case 750:  return "750 ml"
                    default:   return "500 ml"
                    }
                },
                backgroundColor: Color.primary.opacity(0.1)
            )

            if state.bottleCount > 0 {
                Text("\(state.bottleCount)× \(state.mlPerBottle)ml per bottle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var packListSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("packList")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

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
                    let allDone = state.packItems.allSatisfy { state.checkedPackItems.contains($0.id) }
                    if allDone && !showConfetti {
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                        showConfetti = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            withAnimation { showConfetti = false }
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                    .foregroundStyle(isChecked ? Color.bpAccent : Color.secondary)
                    .font(.subheadline)
                packItemLabel(item)
                    .font(.subheadline)
                    .foregroundStyle(isChecked ? Color.secondary : Color.primary)
                    .strikethrough(isChecked, color: Color.secondary)
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(Color.primary.opacity(isChecked ? 0.03 : 0.05),
                        in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func packItemLabel(_ item: PackItem) -> Text {
        switch item.content {
        case .bottles(let count, let ml):
            return Text("\(count)× \(ml)ml per bottle")
        case .solidFood(let units, let name):
            return Text("\(units)× \(Text(LocalizedStringKey(name)))")
        case .key(let k):
            return Text(LocalizedStringKey(k))
        }
    }
}

// MARK: - Pre-ride notification sheet

private struct PreRideNotifSheet: View {
    @Binding var startTime: Date
    let onSchedule: (Date) -> Void
    @Environment(\.dismiss) private var dismiss

    private var fireDate: Date { startTime.addingTimeInterval(-3 * 3600) }
    private var isTooSoon: Bool { fireDate <= Date.now }

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                // Icon + title
                VStack(spacing: 12) {
                    Image(systemName: "bell.badge")
                        .font(.system(size: 44))
                        .foregroundStyle(Color.bpAccent)
                    Text("notifSheetTitle")
                        .font(.title3.weight(.bold))
                    Text("notifSheetSub")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                // Date picker
                DatePicker("notifStartLabel",
                           selection: $startTime,
                           in: Date.now...,
                           displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.compact)
                    .padding(.horizontal, 24)

                // Calculated fire time
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "bell")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                        .padding(.top, 1)
                    if isTooSoon {
                        Text("notifTooSoon")
                            .font(.caption)
                            .foregroundStyle(Color.bpDanger)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("notifFiresAt")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 4) {
                                Text(fireDate, style: .time)
                                    .font(.caption.weight(.semibold))
                                Text(fireDate, style: .date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)

                Spacer()

                // CTA
                Button {
                    onSchedule(startTime)
                    dismiss()
                } label: {
                    Text("notifSetReminder")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            isTooSoon ? Color.tertiaryLabel : Color.bpAccent,
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                }
                .disabled(isTooSoon)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .padding(.top, 32)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Confetti

private struct ConfettiView: View {
    private let startDate = Date()

    private struct Flake: Identifiable {
        let id = UUID()
        let x: CGFloat
        let hue: Double
        let speed: Double
        let wobble: Double
        let wobbleAmp: CGFloat
        let rotation: Double
        let rotSpeed: Double
        let size: CGSize
    }

    private let flakes: [Flake] = (0..<55).map { _ in
        Flake(
            x: .random(in: 0...1),
            hue: .random(in: 0...1),
            speed: .random(in: 0.35...1.1),
            wobble: .random(in: 1.5...4.0),
            wobbleAmp: .random(in: 8...28),
            rotation: .random(in: 0...360),
            rotSpeed: .random(in: 80...300) * (Bool.random() ? 1 : -1),
            size: CGSize(width: .random(in: 6...12), height: .random(in: 4...8))
        )
    }

    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSince(startDate)
            Canvas { canvas, size in
                for flake in flakes {
                    let progress = t * flake.speed
                    let y = size.height * CGFloat(progress) * 0.55
                    guard y < size.height + 20 else { continue }
                    let x = size.width * flake.x
                        + flake.wobbleAmp * CGFloat(sin(flake.wobble * t + flake.x * 10))
                    let angle = Angle(degrees: flake.rotation + flake.rotSpeed * t)
                    var c = canvas
                    c.translateBy(x: x, y: y)
                    c.rotate(by: angle)
                    let rect = CGRect(
                        x: -flake.size.width / 2,
                        y: -flake.size.height / 2,
                        width: flake.size.width,
                        height: flake.size.height
                    )
                    c.fill(Path(rect),
                           with: .color(Color(hue: flake.hue, saturation: 0.85, brightness: 0.95)))
                }
            }
        }
        .ignoresSafeArea()
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
