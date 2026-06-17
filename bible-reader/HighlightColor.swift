// bible-reader/HighlightColor.swift
import SwiftUI

/// Fixed 4-color highlight palette, stored as hex strings so the palette can
/// change without a schema migration.
enum HighlightPalette {
    /// Yellow, green, blue, pink.
    static let colors: [String] = ["#FFE08A", "#B5E8A0", "#A8D8F0", "#F4B8D0"]
}

extension Color {
    /// Creates a color from a "#RRGGBB" hex string. Unparseable input yields black.
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&rgb)
        let r = Double((rgb & 0xFF0000) >> 16) / 255
        let g = Double((rgb & 0x00FF00) >> 8) / 255
        let b = Double(rgb & 0x0000FF) / 255
        self = Color(red: r, green: g, blue: b)
    }
}
