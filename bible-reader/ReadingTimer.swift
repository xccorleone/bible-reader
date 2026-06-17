import Foundation

/// Accrues elapsed seconds only while running (Reading view foreground).
/// Clock is injectable for testing. Not thread-safe; used on the main actor.
final class ReadingTimer {
    private let now: () -> Date
    private var segmentStart: Date?
    private var pendingSeconds: Double = 0

    init(now: @escaping () -> Date = Date.init) {
        self.now = now
    }

    var isRunning: Bool { segmentStart != nil }

    func resume() {
        guard segmentStart == nil else { return }   // idempotent
        segmentStart = now()
    }

    func pause() {
        guard let start = segmentStart else { return }
        pendingSeconds += now().timeIntervalSince(start)
        segmentStart = nil
    }

    /// Returns seconds accrued since the last drain. If still running, folds the
    /// elapsed-so-far into the result and continues the segment from now.
    func drain() -> Double {
        if let start = segmentStart {
            let t = now()
            pendingSeconds += t.timeIntervalSince(start)
            segmentStart = t
        }
        let result = pendingSeconds
        pendingSeconds = 0
        return result
    }
}
