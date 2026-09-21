import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

/// Midnight re-arm. The app unlocks the shield when the daily target is met;
/// at 00:00 a new day starts with the target unmet, so the shield has to come
/// back without waiting for the user to open the app.
///
/// Extensions can't read the app's SwiftData store, so both the selection
/// token and the enabled flag arrive through the shared App Group
/// (`FocusSharedStore`), which the app keeps current.
class FocusMonitorExtension: DeviceActivityMonitor {
    private let store = ManagedSettingsStore()

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        reapplyShield()
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
    }

    /// Re-shield for the new day, mirroring FamilyControlsLockController.applyShield.
    private func reapplyShield() {
        guard FocusSharedStore.loadEnabled() else { return }
        guard let data = FocusSharedStore.loadSelection(),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
            store.shield.applications = nil
            store.shield.applicationCategories = nil
            return
        }
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil : .specific(selection.categoryTokens)
    }
}
