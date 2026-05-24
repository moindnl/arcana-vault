import SwiftUI

/// Custom segmented control with a sliding pill indicator.
/// Works on both light and dark backgrounds.
struct SegmentedPicker<T: Hashable>: View {
    let options: [T]
    @Binding var selection: T
    let label: (T) -> LocalizedStringKey
    var pillColor: Color = Color(UIColor.systemBackground)
    var textColorSelected: Color = .label
    var textColorUnselected: Color = .secondaryLabel
    var backgroundColor: Color = Color(hex: "#f0f0f3")
    var cornerRadius: CGFloat = 10

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selection = option
                    }
                } label: {
                    Text(label(option))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(selection == option ? textColorSelected : textColorUnselected)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background {
                            if selection == option {
                                RoundedRectangle(cornerRadius: cornerRadius - 2, style: .continuous)
                                    .fill(pillColor)
                                    .shadow(color: .black.opacity(0.08), radius: 4, y: 1)
                                    .matchedGeometryEffect(id: "pill", in: pillNamespace)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(backgroundColor, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    @Namespace private var pillNamespace
}

/// Dark-surface variant (for TotalsCard)
struct DarkSegmentedPicker<T: Hashable>: View {
    let options: [T]
    @Binding var selection: T
    let label: (T) -> LocalizedStringKey

    var body: some View {
        SegmentedPicker(
            options: options,
            selection: $selection,
            label: label,
            pillColor: Color.white.opacity(0.15),
            textColorSelected: .white,
            textColorUnselected: Color.white.opacity(0.55),
            backgroundColor: Color.white.opacity(0.08),
            cornerRadius: 10
        )
    }
}
