import SwiftUI

// MARK: - Zone

enum Zone: String, CaseIterable {
    case recovery = "Recovery"
    case endurance = "Endurance"
    case tempo = "Tempo"
    case threshold = "Threshold"
    case vo2max = "VO₂max+"
    case tadej = "Tadej"

    /// WCAG 2.1 AA compliant adaptive colors.
    /// Light-mode shades (700-level): ≥5:1 on white.
    /// Dark-mode shades (400-level): ≥6:1 on near-black.
    var color: Color {
        switch self {
        case .recovery:  return Zone.adaptive(light: "#4b5563", dark: "#9ca3af")
        case .endurance: return Zone.adaptive(light: "#1d4ed8", dark: "#60a5fa")
        case .tempo:     return Zone.adaptive(light: "#15803d", dark: "#4ade80")
        case .threshold: return Zone.adaptive(light: "#c2410c", dark: "#fb923c")
        case .vo2max:    return Zone.adaptive(light: "#b91c1c", dark: "#f87171")
        case .tadej:     return Zone.adaptive(light: "#b45309", dark: "#fde047")
        }
    }

    private static func adaptive(light: String, dark: String) -> Color {
        Color(UIColor { traits in
            uiColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }

    private static func uiColor(hex: String) -> UIColor {
        var h = hex.trimmingCharacters(in: .whitespaces)
        if h.hasPrefix("#") { h = String(h.dropFirst()) }
        var rgb: UInt64 = 0
        Scanner(string: h).scanHexInt64(&rgb)
        return UIColor(
            red:   CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >>  8) & 0xFF) / 255,
            blue:  CGFloat( rgb        & 0xFF) / 255,
            alpha: 1
        )
    }

    var ftpRange: String {
        switch self {
        case .recovery:  return "< 55%"
        case .endurance: return "55–75%"
        case .tempo:     return "76–90%"
        case .threshold: return "91–105%"
        case .vo2max:    return "> 105%"
        case .tadej:     return "≥ 500W"
        }
    }

    var carbRange: String {
        switch self {
        case .recovery:  return "< 30 g/h"
        case .endurance: return "30–45 g/h"
        case .tempo:     return "45–60 g/h"
        case .threshold: return "60–90 g/h"
        case .vo2max:    return "90–120 g/h"
        case .tadej:     return "120 g/h"
        }
    }

    var localizedKey: String {
        switch self {
        case .recovery:  return "zoneRecovery"
        case .endurance: return "zoneEndurance"
        case .tempo:     return "zoneTempo"
        case .threshold: return "zoneThreshold"
        case .vo2max:    return "zoneVO2"
        case .tadej:     return "zoneTadej"
        }
    }
}

// MARK: - SweatRate

enum SweatRate: String, CaseIterable, Codable {
    case light = "Light"
    case moderate = "Moderate"
    case heavy = "Heavy"

    var multiplier: Double {
        switch self {
        case .light:    return 0.8
        case .moderate: return 1.0
        case .heavy:    return 1.3
        }
    }

    var localizedKey: String {
        switch self {
        case .light:    return "sweatLight"
        case .moderate: return "sweatModerate"
        case .heavy:    return "sweatHeavy"
        }
    }

    /// Short label used in segmented pickers.
    var label: String { String(localized: String.LocalizationValue(localizedKey)) }
}

// MARK: - IntensityCategory

enum IntensityCategory: String {
    case low = "low"
    case moderate = "moderate"
    case high = "high"
    case extreme = "extreme"
}

// MARK: - FuelingEvent

struct FuelingEvent: Identifiable {
    let id = UUID()
    let minuteMark: Int   // e.g. 20, 40, 60 …
    let units: Int        // number of solid units
    let actualCarbs: Int  // units * solidCarbs
}

// MARK: - PackItem

struct PackItem: Identifiable {
    enum Content {
        /// Dynamic: bottle count + size
        case bottles(count: Int, sizeMl: Int)
        /// Dynamic: solid food units + product name (verbatim, user-defined)
        case solidFood(units: Int, name: String)
        /// Fixed: xcstrings localization key
        case key(String)

        var stableId: String {
            switch self {
            case .bottles(let n, let ml): return "bottles_\(n)_\(ml)"
            case .solidFood(let n, let name): return "solid_\(n)_\(name)"
            case .key(let k): return "key_\(k)"
            }
        }
    }

    var id: String { content.stableId }
    let content: Content
}

// MARK: - NutritionEngine

enum NutritionEngine {

    // MARK: Carb oxidation (Jeukendrup 2004)
    static func carbsFromIF(_ ifVal: Double) -> Int {
        if ifVal <= 0     { return 0 }
        if ifVal < 0.55   { return Int(((ifVal / 0.55) * 20).rounded()) }
        if ifVal < 0.75   { return Int((20 + (ifVal - 0.55) / 0.20 * 20).rounded()) }
        if ifVal < 0.90   { return Int((40 + (ifVal - 0.75) / 0.15 * 20).rounded()) }
        if ifVal < 1.05   { return Int((60 + (ifVal - 0.90) / 0.15 * 30).rounded()) }
        return min(120, Int((90 + (ifVal - 1.05) / 0.15 * 30).rounded()))
    }

    // MARK: Duration parser
    /// Accepts "1:30", "1.30" (mm if 2+ decimal digits), "1.5" (fractional hours), "2" (hours)
    static func parseDuration(_ raw: String) -> Double {
        let s = raw.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        if s.isEmpty { return 0 }

        if s.contains(":") {
            let parts = s.split(separator: ":", maxSplits: 1)
            let h = Double(parts[0]) ?? 0
            let m = Double(parts.count > 1 ? String(parts[1]) : "0") ?? 0
            return max(0, h + m / 60)
        }

        if let dotIndex = s.firstIndex(of: ".") {
            let dec = String(s[s.index(after: dotIndex)...])
            if dec.count >= 2 {
                let h = Int(s[..<dotIndex]) ?? 0
                let mRaw = Int(String(dec.prefix(2))) ?? 0
                let m = min(59, mRaw)
                return max(0, Double(h) + Double(m) / 60)
            }
        }

        return max(0, Double(s) ?? 0)
    }

    // MARK: Zone from power/FTP
    static func zone(power: Double, ftp: Double) -> Zone {
        guard ftp > 0, power > 0 else { return .recovery }
        if power >= 500 { return .tadej }
        let ifVal = power / ftp
        if ifVal < 0.55  { return .recovery }
        if ifVal < 0.76  { return .endurance }
        if ifVal < 0.91  { return .tempo }
        if ifVal < 1.06  { return .threshold }
        return .vo2max
    }

    // MARK: Zone from IF (no FTP context)
    static func zoneFromIF(_ ifVal: Double) -> Zone {
        if ifVal < 0.55  { return .recovery }
        if ifVal < 0.76  { return .endurance }
        if ifVal < 0.91  { return .tempo }
        if ifVal < 1.06  { return .threshold }
        return .vo2max
    }

    // MARK: Intensity category
    static func intensityCategory(_ ifVal: Double) -> IntensityCategory {
        if ifVal < 0.65  { return .low }
        if ifVal <= 0.80 { return .moderate }
        if ifVal < 0.95  { return .high }
        return .extreme
    }

    // MARK: Carb ranges
    static let carbRanges: [IntensityCategory: (min: Int, max: Int)] = [
        .low:      (30, 45),
        .moderate: (45, 60),
        .high:     (60, 90),
        .extreme:  (90, 120)
    ]

    static let fluidRanges: [IntensityCategory: (min: Double, max: Double)] = [
        .low:      (0.4, 0.5),
        .moderate: (0.5, 0.7),
        .high:     (0.7, 1.0),
        .extreme:  (1.0, 1.2)
    ]

    // MARK: Heat bonus
    static func heatBonus(temperature: Double) -> Double {
        guard temperature > 20 else { return 0 }
        let raw = (temperature - 20) / 5 * 0.3
        return (raw * 10).rounded() / 10
    }

    // MARK: Fluid per hour
    static func fluidPerHour(
        ifVal: Double,
        weightKg: Double,
        sweatRate: SweatRate,
        temperature: Double
    ) -> Double {
        let cat = intensityCategory(ifVal)
        let range = fluidRanges[cat] ?? (0.5, 0.7)
        let base = (range.min + range.max) / 2
        let adjusted = base * (weightKg / 70) * sweatRate.multiplier
        let heat = heatBonus(temperature: temperature)
        let raw = adjusted + heat
        return (raw * 10).rounded() / 10
    }

    // MARK: Carbs per hour
    static func carbsPerHour(ifVal: Double, hasPower: Bool) -> Int {
        if hasPower {
            return carbsFromIF(ifVal)
        }
        let cat = intensityCategory(ifVal)
        let range = carbRanges[cat] ?? (45, 60)
        return (range.min + range.max) / 2
    }

    // MARK: Kcal per hour
    static func kcalPerHour(power: Double) -> Int {
        Int((power * 3.6).rounded())
    }

    // MARK: Speed
    static func speedKmh(distanceKm: Double, durationH: Double) -> Double {
        guard durationH > 0 else { return 0 }
        return distanceKm / durationH
    }

    // MARK: Speed animal
    static func speedAnimal(speedKmh: Double) -> (label: String, emoji: String, wikipediaSlug: String?) {
        switch speedKmh {
        case ..<10:   return ("Turtle",     "🐢", "Turtle")
        case ..<15:   return ("Penguin",    "🐧", "Penguin")
        case ..<20:   return ("Gazelle",    "🦌", "Gazelle")
        case ..<25:   return ("Cheetah",    "🐆", "Cheetah")
        case ..<30:   return ("Falcon",     "🦅", "Falcon")
        case ..<40:   return ("Peregrine",  "🦅", "Peregrine_falcon")
        case ..<55:   return ("Greyhound",  "🐕", "Greyhound")
        case ..<75:   return ("Downhill",   "🚵", nil)
        case ..<100:  return ("Motorcycle", "🏍️", "Motorcycle")
        default:      return ("Ambulance",  "🚑", "Ambulance")
        }
    }

    // MARK: Bottle plan
    static func bottlePlan(
        totalFluidMl: Double,
        bottleSize: Int
    ) -> (count: Int, mlPerBottle: Int) {
        guard totalFluidMl > 0, bottleSize > 0 else { return (0, 0) }
        let count = Int(ceil(totalFluidMl / Double(bottleSize)))
        let ml = Int((totalFluidMl / Double(count)).rounded())
        return (count, ml)
    }

    // MARK: Drink carbs per hour
    static func drinkCarbsPerHour(
        drinkCarbsPer500: Double,
        fluidPerHourL: Double
    ) -> Int {
        let rate = drinkCarbsPer500 * (fluidPerHourL * 1000 / 500)
        return Int(rate.rounded())
    }

    // MARK: Fueling schedule
    static func fuelingSchedule(
        duration: Double,     // hours
        solidCarbsPerHour: Int,
        solidCarbsPerUnit: Int
    ) -> [FuelingEvent] {
        guard duration > 0, solidCarbsPerUnit > 0 else { return [] }
        let totalMins = Int((duration * 60).rounded())
        var events: [FuelingEvent] = []
        var t = 20
        while t <= totalMins {
            let carbsPerSlot = Int((Double(solidCarbsPerHour) / 3).rounded())
            let units = max(0, Int((Double(carbsPerSlot) / Double(solidCarbsPerUnit)).rounded()))
            let actual = units * solidCarbsPerUnit
            events.append(FuelingEvent(minuteMark: t, units: units, actualCarbs: actual))
            t += 20
        }
        return events
    }

    // MARK: Pack items
    static func packItems(
        bottleCount: Int,
        totalSolidUnits: Int,
        solidProductName: String,
        bottleSizeMl: Int
    ) -> [PackItem] {
        var items: [PackItem] = []
        if bottleCount > 0 {
            items.append(PackItem(content: .bottles(count: bottleCount, sizeMl: bottleSizeMl)))
        }
        if totalSolidUnits > 0 {
            items.append(PackItem(content: .solidFood(units: totalSolidUnits, name: solidProductName)))
        }
        items.append(PackItem(content: .key("packElectrolytes")))
        items.append(PackItem(content: .key("packSnack")))
        items.append(PackItem(content: .key("packPump")))
        items.append(PackItem(content: .key("packTube")))
        items.append(PackItem(content: .key("packPhone")))
        return items
    }
}

// MARK: - Color hex extension

extension Color {
    init(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespaces)
        if h.hasPrefix("#") { h = String(h.dropFirst()) }
        var rgb: UInt64 = 0
        Scanner(string: h).scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >> 8)  & 0xFF) / 255
        let b = Double(rgb         & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
