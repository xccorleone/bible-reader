import Foundation

/// App-Group-shared handoff between the app and the DeviceActivityMonitor
/// extension (the extension can't read SwiftData). The app writes; the
/// extension reads at midnight to decide whether and what to re-shield.
enum FocusSharedStore {
    static let appGroupID = "group.com.trcfoundation.bible-reader"
    private static var defaults: UserDefaults? { UserDefaults(suiteName: appGroupID) }
    private static let key = "selectionToken"
    private static let enabledKey = "focusEnabled"

    static func saveSelection(_ data: Data?) { defaults?.set(data, forKey: key) }
    static func loadSelection() -> Data? { defaults?.data(forKey: key) }

    static func saveEnabled(_ enabled: Bool) { defaults?.set(enabled, forKey: enabledKey) }
    static func loadEnabled() -> Bool { defaults?.bool(forKey: enabledKey) ?? false }
}
