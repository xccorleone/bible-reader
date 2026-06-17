// bible-reader/SearchView.swift
import SwiftUI

/// 搜索 — full-text search over the Bible. Typing a term lists matching verses
/// (reference + snippet); tapping one jumps to its chapter via `onOpen`.
struct SearchView: View {
    let service: SearchService
    let books: [BookInfo]
    let onOpen: (Reference) -> Void

    @State private var query = ""
    @State private var results: [SearchResult] = []
    @State private var didSearch = false

    private var bookNames: [Int: String] {
        Dictionary(books.map { ($0.id, $0.nameZH) }, uniquingKeysWith: { a, _ in a })
    }

    var body: some View {
        Group {
            if query.trimmingCharacters(in: .whitespaces).isEmpty {
                ContentUnavailableView(
                    "搜索经文",
                    systemImage: "magnifyingglass",
                    description: Text("输入字词查找包含它的经节。"))
            } else if didSearch && results.isEmpty {
                ContentUnavailableView.search(text: query)
            } else {
                List(results) { result in
                    Button { onOpen(result.ref) } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(result.ref.displayString(bookName: name(result.ref.book)))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.tint)
                            Text(highlighted(result.snippet))
                                .font(.body)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("搜索")
        .searchable(text: $query, prompt: "搜索经文")
        .task(id: query) { await runSearch() }
    }

    private func runSearch() async {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else {
            results = []
            didSearch = false
            return
        }
        // Debounce rapid keystrokes; the task is cancelled and restarted on
        // each change to `query`.
        try? await Task.sleep(for: .milliseconds(200))
        guard !Task.isCancelled else { return }
        results = (try? service.search(term)) ?? []
        didSearch = true
    }

    /// Bolds occurrences of the search term within a snippet.
    private func highlighted(_ text: String) -> AttributedString {
        var attributed = AttributedString(text)
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return attributed }
        var range = attributed.range(of: term)
        while let found = range {
            attributed[found].font = .body.weight(.bold)
            let rest = found.upperBound..<attributed.endIndex
            range = attributed[rest].range(of: term).map { $0 }
        }
        return attributed
    }

    private func name(_ book: Int) -> String { bookNames[book] ?? "书卷\(book)" }
}
