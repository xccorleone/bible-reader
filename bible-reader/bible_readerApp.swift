//
//  bible_readerApp.swift
//  bible-reader
//

import SwiftUI
import SwiftData

@main @MainActor
struct bible_readerApp: App {
    @State private var settings = ReadingSettings()
    @Environment(\.scenePhase) private var scenePhase
    private let sharedModelContainer: ModelContainer
    @State private var focus: FocusCoordinator

    init() {
        let schema = Schema([LastReadPosition.self, Bookmark.self, Highlight.self, Note.self,
                             ReadingPlan.self, ReadingSession.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        let container: ModelContainer
        do {
            container = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
        self.sharedModelContainer = container
        _focus = State(initialValue: FocusCoordinator(
            context: container.mainContext, lock: FamilyControlsLockController()))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(settings)
                .environment(focus)
                .preferredColorScheme(settings.colorScheme.colorScheme)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { focus.reconcile() }
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
