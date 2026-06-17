//
//  ContentView.swift
//  bible-reader
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
    @State private var selectedTab = 0

    var body: some View {
        Group {
            if let store {
                TabView(selection: $selectedTab) {
                    readingTab(store: store)
                        .tabItem { Label("阅读", systemImage: "book") }
                        .tag(0)
                    NavigationStack {
                        SearchView(service: SearchService(store: store), books: books, onOpen: openReference)
                    }
                    .tabItem { Label("搜索", systemImage: "magnifyingglass") }
                    .tag(1)
                    NavigationStack {
                        AnnotationsView(books: books, onOpen: openReference)
                    }
                    .tabItem { Label("我的标注", systemImage: "bookmark") }
                    .tag(2)
                }
            } else if let fatalMessage {
                ContentUnavailableView("无法打开圣经数据", systemImage: "exclamationmark.triangle", description: Text(fatalMessage))
            } else {
                ProgressView()
            }
        }
        .task { openStore() }
    }

    @ViewBuilder
    private func readingTab(store: BibleStore) -> some View {
        NavigationStack(path: $path) {
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
        }
    }

    /// Jumps the reading tab to the chapter containing `ref`, replacing the
    /// current reading stack so Back returns to the book list.
    private func openReference(_ ref: Reference) {
        guard let book = books.first(where: { $0.id == ref.book }) else { return }
        selectedTab = 0
        path = NavigationPath()
        path.append(NavRoute.reading(book: book, chapter: ref.chapter))
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
