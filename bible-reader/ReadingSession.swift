import Foundation
import SwiftData

/// One row per local calendar day; drives lock/unlock and streaks.
@Model
final class ReadingSession {
    var dayKey: String          // local "yyyy-MM-dd"
    var accumulatedSeconds: Double
    var isComplete: Bool
    var updatedAt: Date

    init(dayKey: String, accumulatedSeconds: Double = 0,
         isComplete: Bool = false, updatedAt: Date = .now) {
        self.dayKey = dayKey
        self.accumulatedSeconds = accumulatedSeconds
        self.isComplete = isComplete
        self.updatedAt = updatedAt
    }
}

extension ReadingSession {
    /// Returns the session for `dayKey`, creating it on first access.
    static func session(for dayKey: String, in context: ModelContext) -> ReadingSession {
        let key = dayKey
        let descriptor = FetchDescriptor<ReadingSession>(
            predicate: #Predicate { $0.dayKey == key })
        if let existing = try? context.fetch(descriptor).first { return existing }
        let session = ReadingSession(dayKey: dayKey)
        context.insert(session)
        try? context.save()
        return session
    }
}
