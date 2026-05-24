import SwiftUI

struct BPCard<Content: View>: View {
    var cornerRadius: CGFloat = 16
    var padding: CGFloat = 16
    var background: Color = .systemBackground
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

// Convenience color shorthands
extension Color {
    static var systemBackground: Color       { Color(UIColor.systemBackground) }
    static var secondarySystemBackground: Color { Color(UIColor.secondarySystemBackground) }
    static var systemGroupedBackground: Color { Color(UIColor.systemGroupedBackground) }
    static var label: Color                  { Color(UIColor.label) }
    static var secondaryLabel: Color         { Color(UIColor.secondaryLabel) }
    static var tertiaryLabel: Color          { Color(UIColor.tertiaryLabel) }
    static var separator: Color              { Color(UIColor.separator) }
    static var bpAccent: Color               { Color(hex: "#f73b20") }
    static var bpInputBg: Color              { Color(hex: "#f0f0f3") }
    static var bpDarkCard: Color             { Color(hex: "#1c1c1f") }
}

#Preview {
    BPCard {
        Text("Hello Card")
            .font(.headline)
    }
    .padding()
}
