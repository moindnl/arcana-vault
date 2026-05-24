import SwiftUI

struct OnboardingView: View {
    @Environment(AppState.self) private var state

    @State private var currentStep: Int = 0
    @State private var animationDirection: Int = 1  // +1 forward, -1 back
    @State private var startTour: Bool = false

    // Step 1 local state
    @FocusState private var onboardFocus: OnboardField?
    enum OnboardField: Hashable { case weight, ftp }

    // Step 2 local state
    @State private var newProductName: String = ""
    @State private var newProductCarbs: String = ""
    @State private var addProductError: String? = nil

    var body: some View {
        ZStack {
            Color.systemGroupedBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress dots (steps 1–4)
                if currentStep > 0 {
                    progressDots
                        .padding(.top, 16)
                        .padding(.bottom, 4)
                }

                // Step content with slide transition
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
                    .frame(
                        width:  i == currentStep ? 8 : 6,
                        height: i == currentStep ? 8 : 6
                    )
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
                // Logo — custom app icon + wordmark
                VStack(spacing: 12) {
                    Image(uiImage: UIImage(named: "AppIcon") ?? UIImage())
                        .resizable()
                        .frame(width: 88, height: 88)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)

                    (Text("bonk").italic().fontWeight(.bold) +
                     Text("proof!").foregroundStyle(Color.bpAccent).fontWeight(.bold))
                        .font(.largeTitle)
                }

                Text(String(localized: "onboardingTagline"))
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
                            Text(lang.displayName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(s.language == lang ? .white : Color.label)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    s.language == lang
                                        ? Color.label
                                        : Color.secondarySystemBackground,
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
                // Title + back row
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(String(localized: "onboardingProfileTitle"))
                            .font(.title2.weight(.bold))
                        Text(String(localized: "onboardingProfileSub"))
                            .font(.subheadline)
                            .foregroundStyle(Color.secondaryLabel)
                    }
                }
                .padding(.top, 8)

                // Units segmented picker
                BPCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(String(localized: "units"))
                            .font(.subheadline.weight(.semibold))
                        SegmentedPicker(
                            options: [false, true],
                            selection: $s.imperial,
                            label: { $0 ? String(localized: "miLbs") : String(localized: "kmKg") }
                        )
                    }
                }

                // Weight + FTP
                BPCard {
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "scalemass.fill")
                                .foregroundStyle(Color.secondaryLabel)
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(s.imperial
                                     ? "\(String(localized: "bodyWeight")) (lbs)"
                                     : "\(String(localized: "bodyWeight")) (kg)")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(Color.secondaryLabel)
                                TextField(s.imperial ? "e.g. 165" : "e.g. 72",
                                          text: $s.weightText)
                                    .keyboardType(.decimalPad)
                                    .focused($onboardFocus, equals: .weight)
                            }
                        }

                        Divider()

                        HStack {
                            Image(systemName: "bolt.fill")
                                .foregroundStyle(Color.secondaryLabel)
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(String(localized: "ftpLabel")) (W)")
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
                        Text(String(localized: "sweatRate"))
                            .font(.subheadline.weight(.semibold))
                        SegmentedPicker(
                            options: SweatRate.allCases,
                            selection: $s.sweatRate,
                            label: { $0.label }
                        )
                    }
                }

                backNextButtons(
                    canContinue: !s.weightText.isEmpty && !s.ftpText.isEmpty
                )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 48)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(String(localized: "done")) { onboardFocus = nil }
            }
        }
    }

    // MARK: - Step 2: Products

    private var productsStep: some View {
        @Bindable var s = state
        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "onboardingProductsTitle"))
                        .font(.title2.weight(.bold))
                    Text(String(localized: "onboardingProductsSub"))
                        .font(.subheadline)
                        .foregroundStyle(Color.secondaryLabel)
                }
                .padding(.top, 8)

                // Add product form
                BPCard {
                    VStack(spacing: 12) {
                        TextField(String(localized: "productNamePlaceholder"),
                                  text: $newProductName)
                            .textFieldStyle(.plain)
                        Divider()
                        HStack {
                            TextField(String(localized: "productCarbsUnit"),
                                      text: $newProductCarbs)
                                .keyboardType(.numberPad)
                            Spacer()
                            Button { addProduct() } label: {
                                Text(String(localized: "addProduct"))
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
                                        Text(String(localized: "\(product.carbs)g carbs"))
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
                } else {
                    Text(String(localized: "noCustomProducts"))
                        .font(.subheadline)
                        .foregroundStyle(Color.secondaryLabel)
                        .padding(.horizontal, 4)
                }

                backNextButtons(canContinue: true, skipLabel: String(localized: "onboardingSkip"))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 48)
        }
    }

    private func addProduct() {
        guard let carbs = Int(newProductCarbs), carbs > 0 else {
            addProductError = String(localized: "productCarbsHint")
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

                Text(String(localized: "onboardingReadyTitle"))
                    .font(.largeTitle.weight(.bold))

                Text(String(localized: "onboardingReadySub"))
                    .font(.subheadline)
                    .foregroundStyle(Color.secondaryLabel)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Spacer()
            VStack(spacing: 12) {
                primaryButton(title: String(localized: "tourStartTour")) {
                    startTour = true
                    nextStep()
                }
                .padding(.horizontal, 32)

                Button {
                    startTour = false
                    nextStep()
                } label: {
                    Text(String(localized: "tourSkipTour"))
                        .font(.subheadline)
                        .foregroundStyle(Color.secondaryLabel)
                }

                // Back button
                Button {
                    previousStep()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.caption.weight(.semibold))
                        Text(String(localized: "back"))
                            .font(.subheadline.weight(.medium))
                    }
                    .foregroundStyle(Color.secondaryLabel)
                }
                .padding(.top, 4)
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

                    Text(String(localized: "onboardingDisclaimerTitle"))
                        .font(.title2.weight(.bold))
                        .frame(maxWidth: .infinity, alignment: .center)

                    Text(String(localized: "onboardingDisclaimerBody"))
                        .font(.subheadline)
                        .foregroundStyle(Color.secondaryLabel)
                        .lineSpacing(4)

                    Text(String(localized: "onboardingDisclaimerSources"))
                        .font(.caption)
                        .foregroundStyle(Color.tertiaryLabel)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }

            // Mandatory accept — no back, no skip
            primaryButton(title: String(localized: "onboardingDisclaimerAccept")) {
                s.disclaimerAccepted = true
                s.onboardingDone = true
                if startTour { s.showHowTo = true }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 48)
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

    /// Primary CTA button (full-width, accent red).
    private func primaryButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    Color.bpAccent,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
        }
    }

    /// Back + Next/Skip row used on steps 1 and 2.
    private func backNextButtons(
        canContinue: Bool,
        skipLabel: String? = nil
    ) -> some View {
        HStack(spacing: 12) {
            // Back button (steps 1+)
            Button {
                previousStep()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.caption.weight(.semibold))
                    Text(String(localized: "back"))
                        .font(.subheadline.weight(.medium))
                }
                .foregroundStyle(Color.secondaryLabel)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    Color.secondarySystemBackground,
                    in: RoundedRectangle(cornerRadius: 14)
                )
            }

            // Next / Skip button
            Button {
                nextStep()
            } label: {
                Text((!canContinue && skipLabel != nil) ? skipLabel! : String(localized: "onboardingNext"))
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

// MARK: - Preview

#Preview {
    OnboardingView()
        .environment(AppState())
}
