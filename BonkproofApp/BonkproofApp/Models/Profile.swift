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

    /// Label shown in language picker.
    var displayName: String {
        switch self {
        case .en:     return "English"
        case .de:     return "Deutsch"
        case .system: return String(localized: "system")
        }
    }
}
