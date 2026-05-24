import SwiftUI

struct OnboardingView: View {
    @Environment(AppState.self) private var state

    @State private var currentStep: Int = 0
    @State private var animationDirection: Int = 1  // +1 forward, -1 back

    // Step 1 local state
    @FocusState private var onboardFocus: OnboardField?
    enum OnboardField: Hashable { case weight, ftp }

    // Step 2 local state
    @State private var newProductName: String = ""
    @State private var newProductCarbs: String = ""

    var body: some View {
        ZStack {
            Color.systemGroupedBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress dots
                if currentStep > 0 && currentStep < 4 {
                    progressDots
                        .padding(.top, 16)
                        .padding(.bottom, 8)
                }

                // Step content
                ZStack {
                    ForEach(0..<5) { step in
                        if step == currentStep {
                            stepView(step: step)
                                .transition(.asymmetric(
                                    insertion: .move(edge: animationDirection > 0 ? .trailing : .leading),
                                    removal:   .move(edge: animationDirection > 0 ? .leading  : .trailing)
                                ))
                        }
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: currentStep)
            }
        }
    }

    // MARK: - Progress dots

    private var progressDots: some View {
        HStack(spacing: 8) {
            ForEach(1..<5) { i in
                Circle()
                    .fill(i == currentStep ? Color.label : Color.tertiaryLabel)
                    .frame(width: i == currentStep ? 8 : 6, height: i == currentStep ? 8 : 6)
                    .animation(.spring(response: 0.3), value: currentStep)
            }
        }
    }

    // MARK: - Step dispatcher

    @ViewBuilder
    private func stepView(step: Int) -> some View {
        switch step {
        case 0: welcomeStep
        case 1: profileStep
        case 2: productsStep
        case 3: readyStep
        case 4: disclaimerStep
        default: EmptyView()
        }
    }

    // MARK: - Step 0: Welcome

    private var welcomeStep: some View {
        @Bindable var s = state
        return VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 20) {
                // Logo
                VStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(Color.bpAccent)

                    (Text("bonk").italic().fontWeight(.bold) +
                     Text("proof!").foregroundStyle(Color.bpAccent).fontWeight(.bold))
                        .font(.largeTitle)
                }

                Text("onboardingTagline", bundle: .main)
                    .font(.body)
                    .foregroundStyle(Color.secondaryLabel)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            VStack(spacing: 16) {
                // Language picker
                HStack(spacing: 12) {
                    ForEach(AppLanguage.allCases, id: \.self) { lang in
                        Button {
                            s.language = lang
                        } label: {
                            Text(lang.rawValue)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(s.language == lang ? .white : Color.label)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    s.language == lang ? Color.label : Color.secondarySystemBackground,
                                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                                )
                        }
                    }
                }
                .padding(.horizontal, 32)

                primaryButton(
                    title: String(localized: "onboardingStart"),
                    action: nextStep
                )
                .padding(.horizontal, 32)
            }
            .padding(.bottom, 48)
        }
    }

    // MARK: - Step 1: Profile

    private var profileStep: some View {
        @Bindable var s = state
        return ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("step1Title", bundle: .main)
                        .font(.title2.weight(.bold))
                    Text("Tell us about you to personalise your targets.")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondaryLabel)
                }
                .padding(.top, 8)

                // Units toggle
                BPCard {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Units")
                                .font(.subheadline.weight(.semibold))
                            Text(s.imperial ? "Miles & pounds" : "Kilometres & kilograms")
                                .font(.caption)
                                .foregroundStyle(Color.secondaryLabel)
                        }
                        Spacer()
                        Toggle("", isOn: $s.imperial)
                    }
                }

                BPCard {
                    VStack(spacing: 12) {
                        // Weight
                        HStack {
                            Image(systemName: "scalemass.fill")
                                .foregroundStyle(Color.secondaryLabel)
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(s.imperial ? "Weight (lbs)" : "Weight (kg)")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(Color.secondaryLabel)
                                TextField(s.imperial ? "e.g. 165" : "e.g. 72", text: $s.weightText)
                                    .keyboardType(.decimalPad)
                                    .focused($onboardFocus, equals: .weight)
                            }
                        }

                        Divider()

                        // FTP
                        HStack {
                            Image(systemName: "bolt.fill")
                                .foregroundStyle(Color.secondaryLabel)
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("FTP (W)")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(Color.secondaryLabel)
                                TextField("e.g. 250", text: $s.ftpText)
                                    .keyboardType(.numberPad)
                                    .focused($onboardFocus, equals: .ftp)
                            }
                        }
                    }
                }

                // Sweat rate
                BPCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Sweat rate")
                            .font(.subheadline.weight(.semibold))
                        SegmentedPicker(
                            options: SweatRate.allCases,
                            selection: $s.sweatRate,
                            label: { $0.rawValue }
                        )
                    }
                }

                navigationButtons(
                    canContinue: !s.weightText.isEmpty && !s.ftpText.isEmpty
                )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 48)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { onboardFocus = nil }
            }
        }
    }

    // MARK: - Step 2: Products

    @State private var addProductError: String? = nil

    private var productsStep: some View {
        @Bindable var s = state
        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("step2Title", bundle: .main)
                        .font(.title2.weight(.bold))
                    Text("Add your favourite gels, bars or snacks.")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondaryLabel)
                }
                .padding(.top, 8)

                // Add product form
                BPCard {
                    VStack(spacing: 12) {
                        TextField("Product name", text: $newProductName)
                            .textFieldStyle(.plain)
                        Divider()
                        HStack {
                            TextField("Carbs per unit (g)", text: $newProductCarbs)
                                .keyboardType(.numberPad)
                            Spacer()
                            Button {
                                addProduct()
                            } label: {
                                Text("Add")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 7)
                                    .background(
                                        newProductName.isEmpty || newProductCarbs.isEmpty
                                            ? Color.tertiaryLabel
                                            : Color.bpAccent,
                                        in: Capsule()
                                    )
                            }
                            .disabled(newProductName.isEmpty || newProductCarbs.isEmpty)
                        }
                        if let error = addProductError {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(Color.bpAccent)
                        }
                    }
                }

                if !s.customProducts.isEmpty {
                    BPCard {
                        VStack(spacing: 0) {
                            ForEach(s.customProducts) { product in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(product.name)
                                            .font(.subheadline.weight(.medium))
                                        Text("\(product.carbs)g carbs")
                                            .font(.caption)
                                            .foregroundStyle(Color.secondaryLabel)
                                    }
                                    Spacer()
                                    Button {
                                        s.customProducts.removeAll { $0.id == product.id }
                                    } label: {
                                        Image(systemName: "trash")
                                            .foregroundStyle(Color.bpAccent)
                                    }
                                }
                                .padding(.vertical, 8)
                                if product.id != s.customProducts.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                }

                navigationButtons(canContinue: true, skipLabel: "Skip")
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 48)
        }
    }

    private func addProduct() {
        guard let carbs = Int(newProductCarbs), carbs > 0 else {
            addProductError = "Enter a valid carb value"
            return
        }
        addProductError = nil
        let product = NutritionProduct(
            id: UUID().uuidString,
            name: newProductName,
            carbs: carbs,
            isCustom: true
        )
        withAnimation { state.customProducts.append(product) }
        newProductName = ""
        newProductCarbs = ""
    }

    // MARK: - Step 3: Ready

    private var readyStep: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(Color(hex: "#22c55e"))

                Text("All set!")
                    .font(.largeTitle.weight(.bold))

                Text("Your profile is ready. Want a quick tour of how it works?")
                    .font(.subheadline)
                    .foregroundStyle(Color.secondaryLabel)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Spacer()
            VStack(spacing: 12) {
                primaryButton(title: "Take the tour") {
                    state.showHowTo = true
                    // Continue to disclaimer
                    nextStep()
                }
                .padding(.horizontal, 32)

                Button {
                    nextStep()
                } label: {
                    Text("Skip tour")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondaryLabel)
                }
            }
            .padding(.bottom, 48)
        }
    }

    // MARK: - Step 4: Disclaimer

    private var disclaimerStep: some View {
        @Bindable var s = state
        return VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Spacer(minLength: 24)

                    HStack {
                        Spacer()
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(Color(hex: "#f59e0b"))
                        Spacer()
                    }

                    Text("onboardingDisclaimerTitle", bundle: .main)
                        .font(.title2.weight(.bold))
                        .frame(maxWidth: .infinity, alignment: .center)

                    BPCard {
                        VStack(alignment: .leading, spacing: 12) {
                            disclaimerParagraph(
                                icon: "info.circle",
                                text: "This app provides general nutrition estimates based on exercise science research. These are starting points, not medical advice."
                            )
                            Divider()
                            disclaimerParagraph(
                                icon: "person.fill",
                                text: "Individual needs vary significantly. Always listen to your body and consult a sports dietitian for personalised guidance."
                            )
                            Divider()
                            disclaimerParagraph(
                                icon: "heart.fill",
                                text: "If you have any medical conditions affecting nutrition or metabolism, please seek professional advice before following these recommendations."
                            )
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }

            primaryButton(title: String(localized: "onboardingDisclaimerAccept")) {
                s.disclaimerAccepted = true
                s.onboardingDone = true
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 48)
        }
    }

    private func disclaimerParagraph(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(Color.bpAccent)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Color.label)
        }
    }

    // MARK: - Navigation helpers

    private func nextStep() {
        animationDirection = 1
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            currentStep = min(currentStep + 1, 4)
        }
    }

    private func previousStep() {
        animationDirection = -1
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            currentStep = max(currentStep - 1, 0)
        }
    }

    private func primaryButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.bpAccent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func navigationButtons(canContinue: Bool, skipLabel: String? = nil) -> some View {
        HStack(spacing: 12) {
            if currentStep > 1 {
                Button {
                    previousStep()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.caption.weight(.semibold))
                        Text("Back")
                            .font(.subheadline.weight(.medium))
                    }
                    .foregroundStyle(Color.secondaryLabel)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.secondarySystemBackground, in: RoundedRectangle(cornerRadius: 14))
                }
            }

            Button {
                nextStep()
            } label: {
                Text(skipLabel != nil && !canContinue ? skipLabel! : "Next")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        canContinue ? Color.bpAccent : Color.tertiaryLabel,
                        in: RoundedRectangle(cornerRadius: 14)
                    )
            }
            .disabled(!canContinue && skipLabel == nil)
        }
    }
}

#Preview {
    OnboardingView()
        .environment(AppState())
}
