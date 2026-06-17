//
//  bible_readerApp.swift
//  bible-reader
//
//  Created by Corleone on 2026/6/17.
//

import SwiftUI
import SwiftData

@main
struct bible_readerApp: App {
    @State private var settings = ReadingSettings()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([LastReadPosition.self, Bookmark.self, Highlight.self, Note.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(settings)
                .preferredColorScheme(settings.colorScheme.colorScheme)
        }
        .modelContainer(sharedModelContainer)
    }
}
