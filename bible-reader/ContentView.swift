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

/// Hosted catalog of downloadable translations. Points at the committed
/// manifest; the referenced .sqlite assets live on the GitHub Release.
/// TODO(deploy): replace OWNER/REPO once the repo has a remote + release.
let translationManifestURL = URL(string:
    "https://raw.githubusercontent.com/OWNER/REPO/main/translations/manifest.json")!

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ReadingSettings.self) private var settings
    @Query(sort: \LastReadPosition.updatedAt, order: .reverse) private var positions: [LastReadPosition]

    @State private var store: BibleStore?
    @State private var translationManager: TranslationManager?
    @State private var books: [BookInfo] = []
    @State private var fatalMessage: String?
    @State private var path = NavigationPath()
    @State private var selectedTab = 0

    var body: some View {
        Group {
            if let store, let manager = translationManager {
                let primary = primaryStore(manager)
                TabView(selection: $selectedTab) {
                    readingTab(store: primary, secondary: secondaryStore(manager), manager: manager)
                        .tabItem { Label("阅读", systemImage: "book") }
                        .tag(0)
                    NavigationStack {
                        SearchView(service: SearchService(store: primary), books: books, onOpen: openReference)
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
    private func readingTab(store: BibleStore, secondary: BibleStore?, manager: TranslationManager) -> some View {
        NavigationStack(path: $path) {
            BookListView(books: books)
                .navigationDestination(for: NavRoute.self) { route in
                    switch route {
                    case let .chapters(book):
                        ChapterListView(store: store, book: book)
                    case let .reading(book, chapter):
                        ReadingView(store: store, secondaryStore: secondary, book: book, chapter: chapter)
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            translationMenu(manager: manager)
                        } label: { Image(systemName: "character.book.closed") }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        NavigationLink { SettingsView(translationManager: manager) } label: {
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

    /// Picks the primary translation and toggles an optional parallel secondary.
    @ViewBuilder
    private func translationMenu(manager: TranslationManager) -> some View {
        @Bindable var settings = settings
        Picker("主译本", selection: $settings.primaryTranslationID) {
            ForEach(manager.installed) { item in
                Text(manager.displayName(for: item.id)).tag(item.id)
            }
        }
        Divider()
        Picker("对照译本", selection: Binding(
            get: { settings.secondaryTranslationID ?? "" },
            set: { settings.secondaryTranslationID = $0.isEmpty ? nil : $0 })) {
            Text("无").tag("")
            ForEach(manager.installed.filter { $0.id != settings.primaryTranslationID }) { item in
                Text(manager.displayName(for: item.id)).tag(item.id)
            }
        }
    }

    /// The active primary store, falling back to the bundled one if the
    /// selected translation was deleted.
    private func primaryStore(_ manager: TranslationManager) -> BibleStore {
        manager.store(for: settings.primaryTranslationID) ?? manager.store(for: "cuv")!
    }

    /// The active secondary store (nil if none selected, same as primary, or deleted).
    private func secondaryStore(_ manager: TranslationManager) -> BibleStore? {
        guard let id = settings.secondaryTranslationID, id != settings.primaryTranslationID else { return nil }
        return manager.store(for: id)
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
            translationManager = TranslationManager(
                bundledStore: opened, downloader: URLSessionDownloader(),
                directory: translationsDirectory(), manifestURL: translationManifestURL)
            store = opened
        } catch {
            fatalMessage = "请确认 bible.sqlite 已打包。(\(error))"
        }
    }

    /// Directory for downloaded translation databases. Only needed for the
    /// download feature, so a filesystem error here must NOT block reading the
    /// bundled translation — fall back to a temporary directory.
    private func translationsDirectory() -> URL {
        if let support = try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true) {
            let dir = support.appending(path: "Translations")
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            return dir
        }
        return URL.temporaryDirectory.appending(path: "Translations")
    }
}
