import Foundation

struct RaceTemplate: Identifiable {
    let id: String
    let nameKey: String          // localization key
    let distanceKm: Double
    let intensityFactor: Double  // IF target (fraction of FTP)

    static let all: [RaceTemplate] = [
        RaceTemplate(id: "gf100",        nameKey: "templateGF100",   distanceKm: 100, intensityFactor: 0.75),
        RaceTemplate(id: "gf150",        nameKey: "templateGF150",   distanceKm: 150, intensityFactor: 0.72),
        RaceTemplate(id: "ironman",      nameKey: "templateIronman", distanceKm: 180, intensityFactor: 0.70),
        RaceTemplate(id: "703",          nameKey: "template703",     distanceKm: 90,  intensityFactor: 0.75),
        RaceTemplate(id: "cyclosport",   nameKey: "templateCyclo",   distanceKm: 200, intensityFactor: 0.65),
        RaceTemplate(id: "criterium",    nameKey: "templateCrit",    distanceKm: 80,  intensityFactor: 0.85),
    ]
}
