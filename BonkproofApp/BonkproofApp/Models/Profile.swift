import Foundation

enum AppTheme: String, CaseIterable, Codable {
    case light  = "Light"
    case system = "System"
    case dark   = "Dark"
}

enum AppLanguage: String, CaseIterable, Codable {
    case en     = "EN"
    case de     = "DE"
    case system = "System"
}
