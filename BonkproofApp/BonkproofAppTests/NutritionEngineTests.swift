import XCTest
@testable import BonkproofApp

final class NutritionEngineTests: XCTestCase {

    // MARK: - carbsFromIF

    func testCarbsFromIF_zero() {
        XCTAssertEqual(NutritionEngine.carbsFromIF(0), 0)
    }

    func testCarbsFromIF_below55() {
        // At exactly 0.55 → 20
        XCTAssertEqual(NutritionEngine.carbsFromIF(0.55), 20)
        // Midpoint of first segment (0.275) → ~10
        XCTAssertEqual(NutritionEngine.carbsFromIF(0.275), 10)
    }

    func testCarbsFromIF_segment2() {
        // At 0.75 → 40
        XCTAssertEqual(NutritionEngine.carbsFromIF(0.75), 40)
        // At midpoint 0.65 → 30
        XCTAssertEqual(NutritionEngine.carbsFromIF(0.65), 30)
    }

    func testCarbsFromIF_segment3() {
        // At 0.90 → 60
        XCTAssertEqual(NutritionEngine.carbsFromIF(0.90), 60)
    }

    func testCarbsFromIF_segment4() {
        // At 1.05 → 90
        XCTAssertEqual(NutritionEngine.carbsFromIF(1.05), 90)
    }

    func testCarbsFromIF_highIF() {
        // At 1.20 → min(120, 90 + (0.15/0.15)*30) = 120
        XCTAssertEqual(NutritionEngine.carbsFromIF(1.20), 120)
        // Cap at 120 beyond 1.20
        XCTAssertEqual(NutritionEngine.carbsFromIF(2.0), 120)
    }

    func testCarbsFromIF_negative() {
        XCTAssertEqual(NutritionEngine.carbsFromIF(-1), 0)
    }

    // MARK: - parseDuration

    func testParseDuration_colon() {
        let result = NutritionEngine.parseDuration("1:30")
        XCTAssertEqual(result, 1.5, accuracy: 0.001)
    }

    func testParseDuration_dotTwoDecimalDigits() {
        // "1.30" → 1h30min = 1.5h
        let result = NutritionEngine.parseDuration("1.30")
        XCTAssertEqual(result, 1.5, accuracy: 0.001)
    }

    func testParseDuration_dotOneDecimalDigit() {
        // "1.5" → 1.5h
        let result = NutritionEngine.parseDuration("1.5")
        XCTAssertEqual(result, 1.5, accuracy: 0.001)
    }

    func testParseDuration_integer() {
        let result = NutritionEngine.parseDuration("2")
        XCTAssertEqual(result, 2.0, accuracy: 0.001)
    }

    func testParseDuration_empty() {
        XCTAssertEqual(NutritionEngine.parseDuration(""), 0.0)
    }

    func testParseDuration_colonMinutesOnly() {
        // "0:45" → 0.75h
        let result = NutritionEngine.parseDuration("0:45")
        XCTAssertEqual(result, 0.75, accuracy: 0.001)
    }

    func testParseDuration_minutesCapped() {
        // "1.75" decimal digits ≥2, minutes capped to 59 → 1 + 59/60
        let result = NutritionEngine.parseDuration("1.75")
        XCTAssertEqual(result, 1 + 59.0/60.0, accuracy: 0.001)
    }

    // MARK: - Zone classification

    func testZone_recovery() {
        XCTAssertEqual(NutritionEngine.zone(power: 100, ftp: 280), .recovery)
    }

    func testZone_endurance() {
        // 0.65 * 280 = 182
        XCTAssertEqual(NutritionEngine.zone(power: 182, ftp: 280), .endurance)
    }

    func testZone_tempo() {
        // 0.83 * 280 = 232
        XCTAssertEqual(NutritionEngine.zone(power: 232, ftp: 280), .tempo)
    }

    func testZone_threshold() {
        // 0.97 * 280 = 271.6
        XCTAssertEqual(NutritionEngine.zone(power: 272, ftp: 280), .threshold)
    }

    func testZone_vo2max() {
        // 1.1 * 280 = 308
        XCTAssertEqual(NutritionEngine.zone(power: 308, ftp: 280), .vo2max)
    }

    func testZone_tadej() {
        XCTAssertEqual(NutritionEngine.zone(power: 550, ftp: 400), .tadej)
    }

    func testZone_noFTP() {
        XCTAssertEqual(NutritionEngine.zone(power: 200, ftp: 0), .recovery)
    }

    // MARK: - Fluid calculation

    func testFluidPerHour_70kg_moderate_20C() {
        // IF 0.75 → moderate category → range (0.5, 0.7) → base 0.6
        // 0.6 * (70/70) * 1.0 + 0 = 0.6
        let result = NutritionEngine.fluidPerHour(
            ifVal: 0.75,
            weightKg: 70,
            sweatRate: .moderate,
            temperature: 20
        )
        XCTAssertEqual(result, 0.6, accuracy: 0.05)
    }

    func testFluidPerHour_heavySweat() {
        let result = NutritionEngine.fluidPerHour(
            ifVal: 0.75,
            weightKg: 70,
            sweatRate: .heavy,
            temperature: 20
        )
        // 0.6 * 1.3 = 0.78
        XCTAssertEqual(result, 0.78, accuracy: 0.05)
    }

    // MARK: - Heat bonus

    func testHeatBonus_at20C() {
        XCTAssertEqual(NutritionEngine.heatBonus(temperature: 20), 0.0)
    }

    func testHeatBonus_at25C() {
        // (25-20)/5 * 0.3 = 0.3
        XCTAssertEqual(NutritionEngine.heatBonus(temperature: 25), 0.3, accuracy: 0.01)
    }

    func testHeatBonus_at30C() {
        // (30-20)/5 * 0.3 = 0.6
        XCTAssertEqual(NutritionEngine.heatBonus(temperature: 30), 0.6, accuracy: 0.01)
    }

    func testHeatBonus_below20C() {
        XCTAssertEqual(NutritionEngine.heatBonus(temperature: 10), 0.0)
    }

    // MARK: - Speed

    func testSpeedKmh() {
        let speed = NutritionEngine.speedKmh(distanceKm: 60, durationH: 2)
        XCTAssertEqual(speed, 30, accuracy: 0.01)
    }

    func testSpeedAnimal_turtle() {
        let animal = NutritionEngine.speedAnimal(speedKmh: 5)
        XCTAssertEqual(animal.label, "Turtle")
    }

    func testSpeedAnimal_cheetah() {
        let animal = NutritionEngine.speedAnimal(speedKmh: 22)
        XCTAssertEqual(animal.label, "Cheetah")
    }

    // MARK: - Bottle plan

    func testBottlePlan_standard() {
        let plan = NutritionEngine.bottlePlan(totalFluidMl: 1500, bottleSize: 750)
        XCTAssertEqual(plan.count, 2)
        XCTAssertEqual(plan.mlPerBottle, 750)
    }

    func testBottlePlan_oddAmount() {
        let plan = NutritionEngine.bottlePlan(totalFluidMl: 800, bottleSize: 500)
        XCTAssertEqual(plan.count, 2)  // ceil(800/500) = 2
    }

    // MARK: - Fueling schedule

    func testFuelingSchedule_2h() {
        let events = NutritionEngine.fuelingSchedule(
            duration: 2,
            solidCarbsPerHour: 60,
            solidCarbsPerUnit: 22
        )
        // 2h = 120 min → marks at 20,40,60,80,100,120 = 6 events
        XCTAssertEqual(events.count, 6)
        XCTAssertEqual(events.first?.minuteMark, 20)
        XCTAssertEqual(events.last?.minuteMark, 120)
    }

    func testFuelingSchedule_empty() {
        let events = NutritionEngine.fuelingSchedule(duration: 0, solidCarbsPerHour: 60, solidCarbsPerUnit: 22)
        XCTAssertTrue(events.isEmpty)
    }
}
