import SwiftUI
import Observation

@Observable
final class AppState {

    // MARK: - Ride inputs (transient)
    var distanceText: String = ""
    var durationText: String = ""
    var powerText:    String = ""
    var temperature:  Double = 20

    // MARK: - Profile (persisted)
    var weightText: String = "" {
        didSet { UserDefaults.standard.set(weightText, forKey: "weightText") }
    }
    var ftpText: String = "" {
        didSet { UserDefaults.standard.set(ftpText, forKey: "ftpText") }
    }
    var imperial: Bool = false {
        didSet { UserDefaults.standard.set(imperial, forKey: "imperial") }
    }
    var sweatRate: SweatRate = .moderate {
        didSet { UserDefaults.standard.set(sweatRate.rawValue, forKey: "sweatRate") }
    }

    // MARK: - Preferences (persisted)
    var theme: AppTheme = .system {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: "theme") }
    }
    var language: AppLanguage = .system {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: "language") }
    }
    var solidProductId: String = "gel" {
        didSet { UserDefaults.standard.set(solidProductId, forKey: "solidProductId") }
    }
    var drinkProductId: String = "water" {
        didSet { UserDefaults.standard.set(drinkProductId, forKey: "drinkProductId") }
    }
    var bottleSize: Int = 750 {
        didSet { UserDefaults.standard.set(bottleSize, forKey: "bottleSize") }
    }

    // MARK: - Custom products (persisted)
    var customProducts: [NutritionProduct] = [] {
        didSet {
            if let data = try? JSONEncoder().encode(customProducts) {
                UserDefaults.standard.set(data, forKey: "customProducts")
            }
        }
    }

    // MARK: - Flags (persisted)
    var onboardingDone: Bool = false {
        didSet { UserDefaults.standard.set(onboardingDone, forKey: "onboardingDone") }
    }
    var disclaimerAccepted: Bool = false {
        didSet { UserDefaults.standard.set(disclaimerAccepted, forKey: "disclaimerAccepted") }
    }

    // MARK: - UI state (transient)
    var showSettings: Bool = false
    var showHowTo:    Bool = false
    var howToSlide:   Int  = 0

    // Pack checklist checked state (transient per ride)
    var checkedPackItems: Set<String> = []

    // MARK: - Init (load from UserDefaults)
    init() {
        let ud = UserDefaults.standard
        weightText     = ud.string(forKey: "weightText")     ?? ""
        ftpText        = ud.string(forKey: "ftpText")        ?? ""
        imperial       = ud.bool(forKey: "imperial")
        sweatRate      = SweatRate(rawValue: ud.string(forKey: "sweatRate") ?? "") ?? .moderate
        theme          = AppTheme(rawValue: ud.string(forKey: "theme") ?? "") ?? .system
        language       = AppLanguage(rawValue: ud.string(forKey: "language") ?? "") ?? .system
        solidProductId = ud.string(forKey: "solidProductId") ?? "gel"
        drinkProductId = ud.string(forKey: "drinkProductId") ?? "water"
        bottleSize     = ud.integer(forKey: "bottleSize") == 0 ? 750 : ud.integer(forKey: "bottleSize")
        onboardingDone = ud.bool(forKey: "onboardingDone")
        disclaimerAccepted = ud.bool(forKey: "disclaimerAccepted")

        if let data = ud.data(forKey: "customProducts"),
           let decoded = try? JSONDecoder().decode([NutritionProduct].self, from: data) {
            customProducts = decoded
        }
    }

    // MARK: - Reset
    func resetRide() {
        distanceText = ""
        durationText = ""
        powerText    = ""
        temperature  = 20
        checkedPackItems = []
    }

    // MARK: - Products helpers
    var allSolidProducts: [NutritionProduct] {
        NutritionProduct.defaults + customProducts
    }

    var activeSolid: NutritionProduct {
        allSolidProducts.first(where: { $0.id == solidProductId }) ?? NutritionProduct.defaults[0]
    }

    var activeDrink: DrinkProduct {
        DrinkProduct.defaults.first(where: { $0.id == drinkProductId }) ?? DrinkProduct.defaults[0]
    }

    // MARK: - Parsed values
    var weight: Double {
        let w = Double(weightText) ?? 0
        return imperial ? w * 0.453592 : w
    }

    var ftp: Double {
        Double(ftpText) ?? 0
    }

    var distance: Double {
        let d = Double(distanceText) ?? 0
        return imperial ? d * 1.60934 : d
    }

    var duration: Double {
        NutritionEngine.parseDuration(durationText)
    }

    var power: Double {
        Double(powerText) ?? 0
    }

    var hasDuration: Bool { duration > 0 }
    var hasPower:    Bool { power > 0 }
    var hasFTP:      Bool { ftp > 0 }
    var hasDistance: Bool { distance > 0 }

    // MARK: - Derived nutrition values
    var intensityFactor: Double {
        guard hasFTP, hasPower else { return 0 }
        return power / ftp
    }

    var zone: Zone {
        guard hasPower else { return .recovery }
        if power >= 500 { return .tadej }
        return NutritionEngine.zone(power: power, ftp: ftp)
    }

    var carbsPerHour: Int {
        guard hasDuration else { return 0 }
        if hasPower && hasFTP {
            return NutritionEngine.carbsFromIF(intensityFactor)
        }
        // No power: use endurance default
        return 45
    }

    var heatBonus: Double {
        NutritionEngine.heatBonus(temperature: temperature)
    }

    var fluidPerHour: Double {
        guard hasDuration else { return 0 }
        let wt = weight > 0 ? weight : 70
        let ifVal = hasPower && hasFTP ? intensityFactor : 0.7
        return NutritionEngine.fluidPerHour(
            ifVal: ifVal,
            weightKg: wt,
            sweatRate: sweatRate,
            temperature: temperature
        )
    }

    var kcalPerHour: Int {
        guard hasPower else { return 0 }
        return NutritionEngine.kcalPerHour(power: power)
    }

    var speedKmh: Double {
        guard hasDistance else { return 0 }
        return NutritionEngine.speedKmh(distanceKm: distance, durationH: duration)
    }

    var speedDisplay: Double {
        imperial ? speedKmh * 0.621371 : speedKmh
    }

    var speedUnit: String { imperial ? "mph" : "km/h" }

    var totalCarbs: Int  { Int((Double(carbsPerHour) * duration).rounded()) }
    var totalFluid: Double { (fluidPerHour * duration * 10).rounded() / 10 }
    var totalKcal:  Int  { Int((Double(kcalPerHour) * duration).rounded()) }

    var bottleCountAndMl: (count: Int, mlPerBottle: Int) {
        NutritionEngine.bottlePlan(
            totalFluidMl: totalFluid * 1000,
            bottleSize: bottleSize
        )
    }

    var bottleCount: Int  { bottleCountAndMl.count }
    var mlPerBottle: Int  { bottleCountAndMl.mlPerBottle }

    var drinkCarbsPerHourVal: Int {
        NutritionEngine.drinkCarbsPerHour(
            drinkCarbsPer500: activeDrink.carbsPer500,
            fluidPerHourL: fluidPerHour
        )
    }

    var solidCarbsPerHour: Int {
        max(0, carbsPerHour - drinkCarbsPerHourVal)
    }

    var totalSolidUnits: Int {
        fuelingEvents.reduce(0) { $0 + $1.units }
    }

    var fuelingEvents: [FuelingEvent] {
        NutritionEngine.fuelingSchedule(
            duration: duration,
            solidCarbsPerHour: solidCarbsPerHour,
            solidCarbsPerUnit: activeSolid.carbs
        )
    }

    var packItems: [PackItem] {
        NutritionEngine.packItems(
            bottleCount: bottleCount,
            totalSolidUnits: totalSolidUnits,
            solidProductName: activeSolid.localizedNameKey,
            bottleSizeMl: bottleSize
        )
    }
}
