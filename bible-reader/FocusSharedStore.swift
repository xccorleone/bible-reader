import Foundation

/// App-Group-shared handoff of the shield selection token between the app and
/// the DeviceActivityMonitor extension (the extension can't read SwiftData).
enum FocusSharedStore {
    static let appGroupID = "group.com.example.bible-reader"   // TODO: set to real group id in Task 7
    private static var defaults: UserDefaults? { UserDefaults(suiteName: appGroupID) }
    private static let key = "selectionToken"

    static func saveSelection(_ data: Data?) { defaults?.set(data, forKey: key) }
    static func loadSelection() -> Data? { defaults?.data(forKey: key) }
}
