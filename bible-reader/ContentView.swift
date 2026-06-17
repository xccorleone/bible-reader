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
    @Query(sort: \LastReadPosition.updatedAt, order: .reverse) private var positions: [LastReadPosition]

    @State private var store: BibleStore?
    @State private var books: [BookInfo] = []
    @State private var fatalMessage: String?
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if let store {
                    BookListView(books: books)
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
                               let book = books.first(where: { $0.id == last.book }) {
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
        do {
            let opened = try BibleStore.bundled(translationID: "cuv")
            books = try opened.allBooks()
            store = opened
        } catch {
            fatalMessage = "请确认 bible.sqlite 已打包。(\(error))"
        }
    }
}
