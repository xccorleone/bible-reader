// bible-reader/AnnotationsView.swift
import SwiftUI
import SwiftData

/// "我的标注" — bookmarks, highlights, and notes grouped in sections.
/// Tapping an entry calls `onOpen` with its reference for cross-tab navigation.
struct AnnotationsView: View {
    let books: [BookInfo]
    let onOpen: (Reference) -> Void

    @Query(sort: \Bookmark.createdAt, order: .reverse) private var bookmarks: [Bookmark]
    @Query(sort: \Highlight.createdAt, order: .reverse) private var highlights: [Highlight]
    @Query(sort: \Note.updatedAt, order: .reverse) private var notes: [Note]

    private var bookNames: [Int: String] {
        Dictionary(books.map { ($0.id, $0.nameZH) }, uniquingKeysWith: { a, _ in a })
    }

    var body: some View {
        Group {
            if bookmarks.isEmpty && highlights.isEmpty && notes.isEmpty {
                ContentUnavailableView(
                    "还没有标注",
                    systemImage: "bookmark",
                    description: Text("在阅读时点选经节即可添加书签、高亮或笔记。"))
            } else {
                List {
                    if !bookmarks.isEmpty {
                        Section("书签") {
                            ForEach(bookmarks) { bm in
                                Button { onOpen(bm.ref) } label: {
                                    Text(bm.ref.displayString(bookName: name(bm.ref.book)))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    if !highlights.isEmpty {
                        Section("高亮") {
                            ForEach(highlights) { hl in
                                Button { onOpen(hl.ref) } label: {
                                    HStack {
                                        Circle().fill(Color(hex: hl.colorHex))
                                            .frame(width: 16, height: 16)
                                        Text(hl.ref.displayString(bookName: name(hl.ref.book)))
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    if !notes.isEmpty {
                        Section("笔记") {
                            ForEach(notes) { note in
                                Button { onOpen(note.ref) } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(note.ref.displayString(bookName: name(note.ref.book)))
                                            .font(.headline)
                                        Text(note.body)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("我的标注")
    }

    private func name(_ book: Int) -> String { bookNames[book] ?? "书卷\(book)" }
}
