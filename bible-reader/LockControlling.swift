import Foundation

/// Facade over the OS focus-enforcement stack (FamilyControls / ManagedSettings /
/// DeviceActivity). Protocol-based so FocusCoordinator is testable with a fake.
protocol LockControlling: AnyObject {
    var isAuthorized: Bool { get }
    func requestAuthorization() async throws
    /// Shield the apps encoded in `selectionData` (JSON FamilyActivitySelection).
    func applyShield(selectionData: Data?)
    func removeShield()
    /// Persist the selection token for the midnight extension, independent of
    /// whether a shield is currently applied.
    func persistSelection(data: Data?)
    /// Schedule a daily midnight re-arm (DeviceActivity).
    func startDailyMonitoring()
    func stopDailyMonitoring()
}
