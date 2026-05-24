import SwiftUI

struct SettingsSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var showCustomProducts = false

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
            .navigationTitle(String(localized: "settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .navigationDestination(isPresented: $showCustomProducts) {
                CustomProductsView()
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Profile

    private var profileSection: some View {
        @Bindable var s = state
        return Section {
            // Weight
            HStack {
                Label(
                    s.imperial ? "Weight (lbs)" : "Weight (kg)",
                    systemImage: "scalemass.fill"
                )
                Spacer()
                TextField(s.imperial ? "165" : "72", text: $s.weightText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 70)
            }

            // FTP
            HStack {
                Label("FTP (W)", systemImage: "bolt.fill")
                Spacer()
                TextField("250", text: $s.ftpText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 70)
            }

            // Sweat rate
            Picker(
                selection: $s.sweatRate,
                label: Label("Sweat rate", systemImage: "humidity")
            ) {
                ForEach(SweatRate.allCases, id: \.self) { rate in
                    Text(rate.rawValue).tag(rate)
                }
            }

            // Units toggle
            Toggle(isOn: $s.imperial) {
                Label("Imperial (mi/lbs)", systemImage: "arrow.left.and.right")
            }
        } header: {
            Text("Profile")
        }
    }

    // MARK: - Products

    private var productsSection: some View {
        @Bindable var s = state
        return Section {
            // Active solid
            Picker(
                selection: $s.solidProductId,
                label: Label("Solid food", systemImage: "fork.knife")
            ) {
                ForEach(state.allSolidProducts) { product in
                    Text(product.name).tag(product.id)
                }
            }

            // Active drink
            Picker(
                selection: $s.drinkProductId,
                label: Label("Drink type", systemImage: "drop.fill")
            ) {
                ForEach(DrinkProduct.defaults) { drink in
                    Text(drink.name).tag(drink.id)
                }
            }

            // Bottle size
            Picker(
                selection: $s.bottleSize,
                label: Label("Bottle size", systemImage: "waterbottle")
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
                    Label("Custom products", systemImage: "plus.circle")
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
            Text("Products")
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        @Bindable var s = state
        return Section {
            Picker(
                selection: $s.theme,
                label: Label("Theme", systemImage: "circle.lefthalf.filled")
            ) {
                ForEach(AppTheme.allCases, id: \.self) { t in
                    Text(t.rawValue).tag(t)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Text("Appearance")
        }
    }

    // MARK: - Language

    private var languageSection: some View {
        @Bindable var s = state
        return Section {
            Picker(
                selection: $s.language,
                label: Label("Language", systemImage: "globe")
            ) {
                ForEach(AppLanguage.allCases, id: \.self) { lang in
                    Text(lang.rawValue).tag(lang)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Text("Language")
        }
    }

    // MARK: - About row

    private var aboutRow: some View {
        Section {
            Button {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    state.showAbout = true
                }
            } label: {
                Label("About bonkproof", systemImage: "info.circle")
                    .foregroundStyle(Color.label)
            }
        }
    }
}

// MARK: - Custom products view

struct CustomProductsView: View {
    @Environment(AppState.self) private var state
    @State private var newName:  String = ""
    @State private var newCarbs: String = ""
    @State private var errorMsg: String? = nil

    var body: some View {
        List {
            Section("Add product") {
                HStack(spacing: 10) {
                    TextField("Name", text: $newName)
                    Divider()
                    TextField("g carbs", text: $newCarbs)
                        .keyboardType(.numberPad)
                        .frame(width: 70)
                    Button {
                        addProduct()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color.bpAccent)
                            .font(.title3)
                    }
                    .disabled(newName.isEmpty || newCarbs.isEmpty)
                }
                if let msg = errorMsg {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(Color.bpAccent)
                }
            }

            if !state.customProducts.isEmpty {
                Section("Your products") {
                    ForEach(state.customProducts) { product in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(product.name)
                                    .font(.body)
                                Text("\(product.carbs)g carbs per unit")
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

            Section("Default products") {
                ForEach(NutritionProduct.defaults) { product in
                    HStack {
                        Text(product.name)
                        Spacer()
                        Text("\(product.carbs)g")
                            .foregroundStyle(Color.secondaryLabel)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Custom products")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func addProduct() {
        guard let carbs = Int(newCarbs), carbs > 0 else {
            errorMsg = "Enter a valid carb value"
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
