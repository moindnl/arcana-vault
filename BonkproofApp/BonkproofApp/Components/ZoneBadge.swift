import SwiftUI

struct ZoneBadge: View {
    let zone: Zone
    let ifPct: Int?

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(zone.color)
                .frame(width: 8, height: 8)
            Text(LocalizedStringKey(zone.localizedKey))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(zone.color)
            if let pct = ifPct {
                Text("·")
                    .foregroundStyle(Color.tertiaryLabel)
                Text("\(pct)% IF")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.secondaryLabel)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(zone.color.opacity(0.12), in: Capsule())
    }
}

#Preview {
    VStack(spacing: 12) {
        ZoneBadge(zone: .recovery, ifPct: 52)
        ZoneBadge(zone: .endurance, ifPct: 68)
        ZoneBadge(zone: .tempo, ifPct: 83)
        ZoneBadge(zone: .threshold, ifPct: 98)
        ZoneBadge(zone: .vo2max, ifPct: 112)
        ZoneBadge(zone: .anaerobic, ifPct: 135)
        ZoneBadge(zone: .neuromuscular, ifPct: 160)
        ZoneBadge(zone: .tadej, ifPct: nil)
    }
    .padding()
}
