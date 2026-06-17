import Foundation
import SwiftData

/// Decision center: turns reading time into lock/unlock actions and owns the
/// daily session lifecycle. Pure logic — all OS effects go through LockControlling.
@Observable
@MainActor
final class FocusCoordinator {
    private let context: ModelContext
    private let lock: LockControlling
    private let now: () -> Date
    private let calendar: Calendar

    init(context: ModelContext, lock: LockControlling,
         now: @escaping () -> Date = Date.init, calendar: Calendar = .current) {
        self.context = context
        self.lock = lock
        self.now = now
        self.calendar = calendar
    }

    var plan: ReadingPlan { ReadingPlan.current(in: context) }
    var isAuthorized: Bool { lock.isAuthorized }

    private var todayKey: String { DayKey.key(for: now(), calendar: calendar) }
    private var todaySession: ReadingSession { ReadingSession.session(for: todayKey, in: context) }

    /// Add foreground reading time; unlock the moment the daily target is reached.
    func recordReading(seconds: Double) {
        guard seconds > 0 else { return }
        let plan = self.plan
        let session = todaySession
        session.accumulatedSeconds += seconds
        session.updatedAt = now()
        if !session.isComplete && session.accumulatedSeconds >= Double(plan.dailyTargetMinutes * 60) {
            session.isComplete = true
            if plan.isEnabled { lock.removeShield() }
        }
        try? context.save()
    }

    /// Make the shield state match today's progress. Called on launch/foreground
    /// and after config changes; the foreground backstop for the midnight extension.
    func reconcile() {
        let plan = self.plan
        guard plan.isEnabled else { lock.removeShield(); return }
        let session = todaySession
        // Self-heal completion: a lowered target can complete today retroactively.
        if !session.isComplete && session.accumulatedSeconds >= Double(plan.dailyTargetMinutes * 60) {
            session.isComplete = true
        }
        if session.isComplete {
            lock.removeShield()
        } else {
            lock.applyShield(selectionData: plan.selectionToken)
        }
        try? context.save()
    }

    func authorizeAndEnable() async throws {
        try await lock.requestAuthorization()
        setEnabled(true)
    }

    func setEnabled(_ enabled: Bool) {
        let plan = self.plan
        plan.isEnabled = enabled
        try? context.save()
        if enabled {
            lock.startDailyMonitoring()
            reconcile()
        } else {
            lock.stopDailyMonitoring()
            lock.removeShield()
        }
    }

    func setTarget(minutes: Int) {
        plan.dailyTargetMinutes = minutes
        try? context.save()
        reconcile()   // lowering the target may complete today
    }

    func setSelection(data: Data?) {
        plan.selectionToken = data
        try? context.save()
        reconcile()
    }

    func todayProgress() -> (seconds: Double, target: Int, isComplete: Bool) {
        let session = todaySession
        return (session.accumulatedSeconds, plan.dailyTargetMinutes, session.isComplete)
    }

    func currentStreak() -> Int {
        let completed = (try? context.fetch(
            FetchDescriptor<ReadingSession>(predicate: #Predicate { $0.isComplete }))) ?? []
        return StreakCalculator.streak(
            completedDayKeys: Set(completed.map(\.dayKey)), today: now(), calendar: calendar)
    }
}
