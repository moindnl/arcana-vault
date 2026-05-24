import SwiftUI

struct SettingsSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var showCustomProducts = false
    @State private var showAbout = false

    var body: some View {
        NavigationStack {
            List {
                profileSection
                productsSection
                appearanceSection
                languageSection
                aboutRow
            }
            .listStyle(.insetGrouped)
            .navigationTitle("settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("done") { dismiss() }
                }
            }
            .navigationDestination(isPresented: $showCustomProducts) {
                CustomProductsView()
            }
            .navigationDestination(isPresented: $showAbout) {
                AboutView()
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(preferredColorScheme)
    }

    private var preferredColorScheme: ColorScheme? {
        switch state.theme {
        case .light:  return .light
        case .dark:   return .dark
        case .system: return nil
        }
    }

    // MARK: - Profile

    private var profileSection: some View {
        @Bindable var s = state
        return Section {
            // Weight
            HStack {
                Label(
                    s.imperial ? "bodyWeightLbs" : "bodyWeightKg",
                    systemImage: "scalemass.fill"
                )
                Spacer()
                TextField(s.imperial ? "165" : "72", text: $s.weightText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 70)
                    .accessibilityLabel(s.imperial ? "bodyWeightLbs" : "bodyWeightKg")
            }

            // FTP
            HStack {
                Label("FTP (W)", systemImage: "bolt.fill")
                Spacer()
                TextField("250", text: $s.ftpText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 70)
                    .accessibilityLabel("FTP (W)")
            }

            // Sweat rate
            Picker(
                selection: $s.sweatRate,
                label: Label("Sweat rate", systemImage: "humidity")
            ) {
                ForEach(SweatRate.allCases, id: \.self) { rate in
                    Text(LocalizedStringKey(rate.localizedKey)).tag(rate)
                }
            }

            // Units toggle
            Toggle(isOn: $s.imperial) {
                Label("imperialToggle", systemImage: "arrow.left.and.right")
            }
        } header: {
            Text("profile")
        }
    }

    // MARK: - Products

    private var productsSection: some View {
        @Bindable var s = state
        return Section {
            // Active solid
            Picker(
                selection: $s.solidProductId,
                label: Label("solidFood", systemImage: "fork.knife")
            ) {
                ForEach(state.allSolidProducts) { product in
                    Text(LocalizedStringKey(product.localizedNameKey)).tag(product.id)
                }
            }

            // Active drink
            Picker(
                selection: $s.drinkProductId,
                label: Label("drinkType", systemImage: "drop.fill")
            ) {
                ForEach(DrinkProduct.defaults) { drink in
                    Text(LocalizedStringKey(drink.id)).tag(drink.id)
                }
            }

            // Bottle size
            Picker(
                selection: $s.bottleSize,
                label: Label("bottleSize", systemImage: "waterbottle")
            ) {
                Text("500 ml").tag(500)
                Text("750 ml").tag(750)
                Text("1 L").tag(1000)
            }

            // Custom products link
            Button {
                showCustomProducts = true
            } label: {
                HStack {
                    Label("customProducts", systemImage: "plus.circle")
                    Spacer()
                    Text("\(state.customProducts.count)")
                        .foregroundStyle(Color.secondaryLabel)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.tertiaryLabel)
                }
            }
            .foregroundStyle(Color.label)
        } header: {
            Text("products")
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        @Bindable var s = state
        return Section {
            Picker(
                selection: $s.theme,
                label: Label("theme", systemImage: "circle.lefthalf.filled")
            ) {
                ForEach(AppTheme.allCases, id: \.self) { t in
                    Text(LocalizedStringKey(t.rawValue)).tag(t)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Text("appearance")
        }
    }

    // MARK: - Language

    private var languageSection: some View {
        @Bindable var s = state
        return Section {
            Picker(
                selection: $s.language,
                label: Label("language", systemImage: "globe")
            ) {
                ForEach(AppLanguage.allCases, id: \.self) { lang in
                    Text(verbatim: lang.rawValue).tag(lang)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Text("language")
        }
    }

    // MARK: - About row

    private var aboutRow: some View {
        Section {
            Button {
                showAbout = true
            } label: {
                HStack {
                    Label("about", systemImage: "info.circle")
                        .foregroundStyle(Color.label)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.tertiaryLabel)
                }
            }
        }
    }
}

// MARK: - Custom products view

struct CustomProductsView: View {
    @Environment(AppState.self) private var state
    @State private var newName:  String = ""
    @State private var newCarbs: String = ""
    @State private var errorMsg: LocalizedStringKey? = nil

    var body: some View {
        List {
            Section("addProductSection") {
                HStack(spacing: 10) {
                    TextField("productName", text: $newName)
                        .accessibilityLabel("productName")
                    Divider()
                    TextField("productCarbsUnit", text: $newCarbs)
                        .keyboardType(.numberPad)
                        .frame(width: 70)
                        .accessibilityLabel("productCarbsUnit")
                    Button {
                        addProduct()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color.bpAccent)
                            .font(.title3)
                    }
                    .accessibilityLabel("addProduct")
                    .disabled(newName.isEmpty || newCarbs.isEmpty)
                }
                if let msg = errorMsg {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(Color.bpAccent)
                }
            }

            if !state.customProducts.isEmpty {
                Section("yourProducts") {
                    ForEach(state.customProducts) { product in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: product.name)
                                    .font(.body)
                                Text("\(String(product.carbs))g carbs per unit")
                                    .font(.caption)
                                    .foregroundStyle(Color.secondaryLabel)
                            }
                            Spacer()
                        }
                    }
                    .onDelete { offsets in
                        state.customProducts.remove(atOffsets: offsets)
                    }
                }
            }

            Section("defaultProducts") {
                ForEach(NutritionProduct.defaults) { product in
                    HStack {
                        Text(LocalizedStringKey(product.localizedNameKey))
                        Spacer()
                        Text("\(String(product.carbs))g")
                            .foregroundStyle(Color.secondaryLabel)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("customProducts")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func addProduct() {
        guard let carbs = Int(newCarbs), carbs > 0 else {
            errorMsg = "enterValidCarb"
            return
        }
        errorMsg = nil
        let p = NutritionProduct(
            id: UUID().uuidString,
            name: newName,
            carbs: carbs,
            isCustom: true
        )
        withAnimation { state.customProducts.append(p) }
        newName  = ""
        newCarbs = ""
    }
}

#Preview {
    SettingsSheet()
        .environment(AppState())
}
