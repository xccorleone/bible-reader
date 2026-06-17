import Foundation
#if os(iOS)
import FamilyControls
import ManagedSettings
import DeviceActivity
#endif

/// Real OS-backed lock. iOS-only effects; on platforms without FamilyControls
/// (macOS) every method is a no-op and `isAuthorized` is false.
final class FamilyControlsLockController: LockControlling {
#if os(iOS)
    private let store = ManagedSettingsStore()
    private let center = DeviceActivityCenter()
    private let activityName = DeviceActivityName("dailyReadingLock")
#endif

    var isAuthorized: Bool {
#if os(iOS)
        AuthorizationCenter.shared.authorizationStatus == .approved
#else
        false
#endif
    }

    func requestAuthorization() async throws {
#if os(iOS)
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
#endif
    }

    func applyShield(selectionData: Data?) {
#if os(iOS)
        FocusSharedStore.saveSelection(selectionData)            // keep extension's token fresh
        guard let data = selectionData,
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
            store.shield.applications = nil
            store.shield.applicationCategories = nil
            return
        }
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil : .specific(selection.categoryTokens)
#endif
    }

    func removeShield() {
#if os(iOS)
        store.shield.applications = nil
        store.shield.applicationCategories = nil
#endif
    }

    func startDailyMonitoring() {
#if os(iOS)
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true)
        try? center.startMonitoring(activityName, during: schedule)
#endif
    }

    func stopDailyMonitoring() {
#if os(iOS)
        center.stopMonitoring([activityName])
#endif
    }
}
