//
//  ContentView.swift
//  bible-reader
//
//  Created by Corleone on 2026/6/17.
//

import SwiftUI
import SwiftData

/// Navigation destinations pushed onto the reading stack.
enum NavRoute: Hashable {
    case chapters(book: BookInfo)
    case reading(book: BookInfo, chapter: Int)
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var positions: [LastReadPosition]

    @State private var store: BibleStore?
    @State private var fatalMessage: String?
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if let store {
                    BookListView(store: store)
                        .navigationDestination(for: NavRoute.self) { route in
                            switch route {
                            case let .chapters(book):
                                ChapterListView(store: store, book: book)
                            case let .reading(book, chapter):
                                ReadingView(store: store, book: book, chapter: chapter)
                            }
                        }
                        .toolbar {
                            ToolbarItem(placement: .primaryAction) {
                                NavigationLink { SettingsView() } label: {
                                    Image(systemName: "textformat.size")
                                }
                            }
                            if let last = positions.first,
                               let book = try? store.allBooks().first(where: { $0.id == last.book }) {
                                ToolbarItem(placement: .navigation) {
                                    Button("续读") {
                                        path.append(NavRoute.reading(book: book, chapter: last.chapter))
                                    }
                                }
                            }
                        }
                } else if let fatalMessage {
                    ContentUnavailableView("无法打开圣经数据", systemImage: "exclamationmark.triangle", description: Text(fatalMessage))
                } else {
                    ProgressView()
                }
            }
        }
        .task { openStore() }
    }

    private func openStore() {
        guard store == nil else { return }
        do { store = try BibleStore.bundled(translationID: "cuv") }
        catch { fatalMessage = "请确认 bible.sqlite 已打包。(\(error))" }
    }
}
