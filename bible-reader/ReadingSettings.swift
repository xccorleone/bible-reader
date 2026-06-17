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
    var fontSize: Double {
        didSet { UserDefaults.standard.set(fontSize, forKey: "fontSize") }
    }
    var colorScheme: AppColorScheme {
        didSet { UserDefaults.standard.set(colorScheme.rawValue, forKey: "colorScheme") }
    }

    init() {
        let stored = UserDefaults.standard.double(forKey: "fontSize")
        self.fontSize = stored == 0 ? 18 : stored
        let raw = UserDefaults.standard.string(forKey: "colorScheme") ?? AppColorScheme.system.rawValue
        self.colorScheme = AppColorScheme(rawValue: raw) ?? .system
    }
}
