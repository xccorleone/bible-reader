import Foundation
import SwiftData

/// Persisted reading-plan config. A single row is kept (fetch-or-create).
@Model
final class ReadingPlan {
    var dailyTargetMinutes: Int
    var isEnabled: Bool
    /// JSON-encoded FamilyActivitySelection (opaque app-shield tokens), nil until chosen.
    var selectionToken: Data?
    var createdAt: Date

    init(dailyTargetMinutes: Int = 20, isEnabled: Bool = false,
         selectionToken: Data? = nil, createdAt: Date = .now) {
        self.dailyTargetMinutes = dailyTargetMinutes
        self.isEnabled = isEnabled
        self.selectionToken = selectionToken
        self.createdAt = createdAt
    }
}

extension ReadingPlan {
    /// Returns the single plan row, creating it on first access.
    static func current(in context: ModelContext) -> ReadingPlan {
        let descriptor = FetchDescriptor<ReadingPlan>(sortBy: [SortDescriptor(\.createdAt)])
        if let existing = try? context.fetch(descriptor).first { return existing }
        let plan = ReadingPlan()
        context.insert(plan)
        try? context.save()
        return plan
    }
}
