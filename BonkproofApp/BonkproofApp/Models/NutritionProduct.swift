import Foundation

// MARK: - NutritionProduct (solid food)

struct NutritionProduct: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var carbs: Int          // carbs per unit (g)
    var isCustom: Bool

    static let defaults: [NutritionProduct] = [
        NutritionProduct(id: "gel",      name: "Energy Gel",    carbs: 22, isCustom: false),
        NutritionProduct(id: "bar",      name: "Energy Bar",    carbs: 40, isCustom: false),
        NutritionProduct(id: "chew",     name: "Energy Chews",  carbs: 27, isCustom: false),
        NutritionProduct(id: "banana",   name: "Banana",        carbs: 25, isCustom: false),
        NutritionProduct(id: "rice",     name: "Rice Cake",     carbs: 30, isCustom: false),
        NutritionProduct(id: "dates",    name: "Medjool Dates", carbs: 18, isCustom: false),
        NutritionProduct(id: "waffle",   name: "Stroopwafel",   carbs: 16, isCustom: false),
    ]
}

// MARK: - DrinkProduct

struct DrinkProduct: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var name: String
    var carbsPer500: Double  // grams of carbs per 500 ml

    static let defaults: [DrinkProduct] = [
        DrinkProduct(id: "water",     name: "Water only",    carbsPer500: 0),
        DrinkProduct(id: "carbmix",   name: "Carb mix",      carbsPer500: 40),
        DrinkProduct(id: "isotonic",  name: "Isotonic",      carbsPer500: 22),
    ]
}
