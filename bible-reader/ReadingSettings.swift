import SwiftUI

enum AppColorScheme: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// Observable reading preferences, persisted via UserDefaults.
@Observable
final class ReadingSettings {
    @ObservationIgnored private let defaults: UserDefaults

    var fontSize: Double {
        didSet { defaults.set(fontSize, forKey: "fontSize") }
    }
    var colorScheme: AppColorScheme {
        didSet { defaults.set(colorScheme.rawValue, forKey: "colorScheme") }
    }
    var primaryTranslationID: String {
        didSet { defaults.set(primaryTranslationID, forKey: "primaryTranslationID") }
    }
    var secondaryTranslationID: String? {
        didSet {
            if let v = secondaryTranslationID {
                defaults.set(v, forKey: "secondaryTranslationID")
            } else {
                defaults.removeObject(forKey: "secondaryTranslationID")
            }
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.double(forKey: "fontSize")
        self.fontSize = stored == 0 ? 18 : stored
        let raw = defaults.string(forKey: "colorScheme") ?? AppColorScheme.system.rawValue
        self.colorScheme = AppColorScheme(rawValue: raw) ?? .system
        self.primaryTranslationID = defaults.string(forKey: "primaryTranslationID") ?? "cuv"
        self.secondaryTranslationID = defaults.string(forKey: "secondaryTranslationID")
    }
}
