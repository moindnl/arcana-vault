import SwiftUI

struct AboutSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var showFormula = false

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.0"
    }

    var body: some View {
        NavigationStack {
            List {
                // App header
                Section {
                    HStack(spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.bpAccent)
                                .frame(width: 60, height: 60)
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(.white)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            (Text("bonk").italic().fontWeight(.bold) +
                             Text("proof!").foregroundStyle(Color.bpAccent).fontWeight(.bold))
                                .font(.title3)
                            Text("Version \(appVersion)")
                                .font(.subheadline)
                                .foregroundStyle(Color.secondaryLabel)
                            Text("Cycling nutrition calculator")
                                .font(.caption)
                                .foregroundStyle(Color.tertiaryLabel)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Privacy / data
                Section("dataPrivacy") {
                    infoRow(icon: "iphone", iconColor: Color(hex: "#3b82f6"), title: "dataStorageVal", subtitle: "allDataOnDevice")
                    infoRow(icon: "network.slash", iconColor: Color(hex: "#22c55e"), title: "noServerRequests", subtitle: "noTracking")
                    infoRow(icon: "wifi.slash", iconColor: Color(hex: "#f59e0b"), title: "worksOffline", subtitle: "noInternet")
                }

                // Math
                Section("calculations") {
                    Button {
                        showFormula = true
                    } label: {
                        HStack {
                            Label("howMathWorks", systemImage: "function")
                                .foregroundStyle(Color.label)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.tertiaryLabel)
                        }
                    }
                }

                // Tour
                Section {
                    Button {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            state.showHowTo = true
                        }
                    } label: {
                        Label("replayTour", systemImage: "play.circle")
                            .foregroundStyle(Color.bpAccent)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("about")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("done") { dismiss() }
                }
            }
            .navigationDestination(isPresented: $showFormula) {
                FormulaView()
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func infoRow(icon: String, iconColor: Color, title: LocalizedStringKey, subtitle: LocalizedStringKey) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(iconColor)
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Color.secondaryLabel)
            }
        }
    }
}

// MARK: - Formula view

struct FormulaView: View {
    @Environment(\.openURL) private var openURL

    private let zones: [(zone: Zone, ftpRange: String, carbRange: String)] = [
        (.recovery,  "< 55%",    "< 30 g/h"),
        (.endurance, "55–75%",   "30–45 g/h"),
        (.tempo,     "76–90%",   "45–60 g/h"),
        (.threshold, "91–105%",  "60–90 g/h"),
        (.vo2max,    "> 105%",   "90–120 g/h"),
    ]

    private let sources: [(title: String, url: String)] = [
        ("Jeukendrup (2004) — Carbohydrate intake during exercise",
         "https://pubmed.ncbi.nlm.nih.gov/15212753/"),
        ("Burke et al. (2011) — Carbohydrates for training",
         "https://pubmed.ncbi.nlm.nih.gov/21660838/"),
        ("Sawka et al. (2007) — Exercise and fluid replacement",
         "https://pubmed.ncbi.nlm.nih.gov/17277604/"),
    ]

    var body: some View {
        List {
            Section("zoneTargets") {
                ForEach(zones, id: \.zone) { row in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(row.zone.color)
                            .frame(width: 10, height: 10)
                        Text(row.zone.rawValue)
                            .font(.subheadline.weight(.medium))
                            .frame(width: 80, alignment: .leading)
                        Text(row.ftpRange)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Color.secondaryLabel)
                            .frame(width: 70, alignment: .leading)
                        Spacer()
                        Text(row.carbRange)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(row.zone.color)
                    }
                }
            }

            Section("fluidFormula") {
                VStack(alignment: .leading, spacing: 8) {
                    formulaLine("Base fluid", "Zone midpoint (L/h)")
                    formulaLine("Weight adj.", "× (weight / 70 kg)")
                    formulaLine("Sweat rate", "× 0.8 / 1.0 / 1.3")
                    formulaLine("Heat bonus", "+0.3 L/h per 5°C above 20°C")
                }
                .padding(.vertical, 4)
            }

            Section("sources") {
                ForEach(sources, id: \.url) { source in
                    Button {
                        if let url = URL(string: source.url) {
                            openURL(url)
                        }
                    } label: {
                        HStack {
                            Text(source.title)
                                .font(.caption)
                                .foregroundStyle(Color.label)
                                .multilineTextAlignment(.leading)
                            Spacer()
                            Image(systemName: "arrow.up.right.circle")
                                .font(.caption)
                                .foregroundStyle(Color.tertiaryLabel)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("howMathWorks")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func formulaLine(_ key: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(key)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.secondaryLabel)
                .frame(width: 90, alignment: .leading)
            Text(value)
                .font(.caption)
                .foregroundStyle(Color.label)
            Spacer()
        }
    }
}

#Preview {
    AboutSheet()
        .environment(AppState())
}
