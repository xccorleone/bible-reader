import Testing
import SwiftData
import Foundation
@testable import bible_reader

@MainActor
struct FocusCoordinatorTests {
    final class FakeLock: LockControlling {
        var authorized = true
        var shielded = false
        var lastSelection: Data?
        var monitoring = false
        var requestCalled = false
        var isAuthorized: Bool { authorized }
        func requestAuthorization() async throws { requestCalled = true }
        func applyShield(selectionData: Data?) { shielded = true; lastSelection = selectionData }
        func removeShield() { shielded = false }
        func startDailyMonitoring() { monitoring = true }
        func stopDailyMonitoring() { monitoring = false }
    }

    final class Clock { var t = Date(timeIntervalSince1970: 1_781_697_600) } // 2026-06-17 12:00 UTC

    private var utc: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: ReadingPlan.self, ReadingSession.self, configurations: config)
        return ModelContext(container)
    }

    @Test func enablingShieldsThenUnlocksAtTarget() throws {
        let context = try makeContext()
        let lock = FakeLock()
        let clock = Clock()
        let coord = FocusCoordinator(context: context, lock: lock, now: { clock.t }, calendar: utc)
        coord.setTarget(minutes: 1)                 // 60s target
        coord.setSelection(data: Data([1, 2, 3]))
        coord.setEnabled(true)
        #expect(lock.monitoring == true)
        #expect(lock.shielded == true)              // enabled + incomplete → shielded
        #expect(lock.lastSelection == Data([1, 2, 3]))
        coord.recordReading(seconds: 30)
        #expect(lock.shielded == true)              // not yet at target
        coord.recordReading(seconds: 40)            // total 70 ≥ 60
        #expect(lock.shielded == false)             // unlocked
        #expect(coord.todayProgress().isComplete == true)
    }

    @Test func newDayReReconcilesToShielded() throws {
        let context = try makeContext()
        let lock = FakeLock()
        let clock = Clock()
        let coord = FocusCoordinator(context: context, lock: lock, now: { clock.t }, calendar: utc)
        coord.setTarget(minutes: 1)
        coord.setSelection(data: Data([9]))
        coord.setEnabled(true)
        coord.recordReading(seconds: 60)            // complete today → unlocked
        #expect(lock.shielded == false)
        clock.t = clock.t.addingTimeInterval(86_400) // next day
        coord.reconcile()
        #expect(lock.shielded == true)              // new day starts locked
    }

    @Test func disablingRemovesShieldAndStopsMonitoring() throws {
        let context = try makeContext()
        let lock = FakeLock()
        let coord = FocusCoordinator(context: context, lock: lock, now: { Date(timeIntervalSince1970: 1_781_697_600) }, calendar: utc)
        coord.setTarget(minutes: 1)
        coord.setEnabled(true)
        coord.setEnabled(false)
        #expect(lock.shielded == false)
        #expect(lock.monitoring == false)
    }

    @Test func authorizeAndEnableRequestsAuthorization() async throws {
        let context = try makeContext()
        let lock = FakeLock()
        let coord = FocusCoordinator(context: context, lock: lock, now: { Date(timeIntervalSince1970: 1_781_697_600) }, calendar: utc)
        try await coord.authorizeAndEnable()
        #expect(lock.requestCalled == true)
        #expect(coord.plan.isEnabled == true)
    }

    @Test func loweringTargetBelowReadCompletesAndStaysUnlocked() throws {
        let context = try makeContext()
        let lock = FakeLock()
        let clock = Clock()
        let coord = FocusCoordinator(context: context, lock: lock, now: { clock.t }, calendar: utc)
        coord.setTarget(minutes: 10)            // 600s target
        coord.setSelection(data: Data([5]))
        coord.setEnabled(true)
        coord.recordReading(seconds: 120)       // 2 min < 10 → still shielded
        #expect(lock.shielded == true)
        coord.setTarget(minutes: 1)             // 120s ≥ 60 → completes today
        #expect(coord.todayProgress().isComplete == true)
        #expect(lock.shielded == false)
        coord.reconcile()                       // a later foreground must NOT re-shield
        #expect(lock.shielded == false)
    }
}
