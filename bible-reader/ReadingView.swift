import SwiftUI
import SwiftData

struct ReadingView: View {
    let store: BibleStore
    let book: BookInfo
    let chapter: Int

    @Environment(ReadingSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext

    @State private var verses: [Verse] = []
    @State private var loadError: String?

    // Annotations for this chapter, loaded once and refreshed on change.
    @State private var highlightHexByVerse: [Int: String] = [:]
    @State private var bookmarkedVerses: Set<Int> = []
    @State private var notesByVerse: [Int: Note] = [:]

    // Selection + note editing.
    @State private var selectedVerses: Set<Int> = []
    @State private var editingNote: EditingNote?

    /// Identifiable wrapper so a verse number can drive `.sheet(item:)`.
    private struct EditingNote: Identifiable { let verse: Int; var id: Int { verse } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if let loadError {
                    Text(loadError).foregroundStyle(.red)
                }
                ForEach(verses) { verse in
                    VerseRow(
                        verse: verse,
                        fontSize: settings.fontSize,
                        highlightHex: highlightHexByVerse[verse.number],
                        isBookmarked: bookmarkedVerses.contains(verse.number),
                        hasNote: notesByVerse[verse.number] != nil,
                        isSelected: selectedVerses.contains(verse.number),
                        onTap: { toggleSelection(verse.number) },
                        onTapNote: { editingNote = EditingNote(verse: verse.number) }
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            if !selectedVerses.isEmpty {
                VerseSelectionToolbar(
                    canAddNote: selectedVerses.count == 1,
                    onBookmark: applyBookmark,
                    onHighlight: applyHighlight,
                    onNote: openNoteForSelection,
                    onCancel: { selectedVerses.removeAll() }
                )
            }
        }
        .navigationTitle("\(book.nameZH) \(chapter)")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .task(id: chapter) { load() }
        .sheet(item: $editingNote) { editing in
            let ref = Reference(book: book.id, chapter: chapter, verse: editing.verse)
            NoteEditorView(
                reference: ref,
                bookName: book.nameZH,
                existingBody: notesByVerse[editing.verse]?.body ?? ""
            ) { newBody in
                Note.upsert(in: modelContext, ref: ref, body: newBody)
                reloadAnnotations()
                selectedVerses.removeAll()
            }
        }
    }

    private func toggleSelection(_ verse: Int) {
        if selectedVerses.contains(verse) {
            selectedVerses.remove(verse)
        } else {
            selectedVerses.insert(verse)
        }
    }

    private func applyBookmark() {
        for v in selectedVerses {
            Bookmark.toggle(in: modelContext, ref: Reference(book: book.id, chapter: chapter, verse: v))
        }
        reloadAnnotations()
        selectedVerses.removeAll()
    }

    private func applyHighlight(_ hex: String) {
        for v in selectedVerses {
            let ref = Reference(book: book.id, chapter: chapter, verse: v)
            if highlightHexByVerse[v] == hex {
                Highlight.remove(in: modelContext, ref: ref)
            } else {
                Highlight.setColor(in: modelContext, ref: ref, colorHex: hex)
            }
        }
        reloadAnnotations()
        selectedVerses.removeAll()
    }

    private func openNoteForSelection() {
        guard selectedVerses.count == 1, let v = selectedVerses.first else { return }
        editingNote = EditingNote(verse: v)
    }

    private func load() {
        do {
            verses = try store.verses(book: book.id, chapter: chapter)
            LastReadPosition.update(
                in: modelContext, book: book.id, chapter: chapter, translationID: store.translationID)
            reloadAnnotations()
        } catch {
            loadError = "无法加载经文：\(error.localizedDescription)"
        }
    }

    private func reloadAnnotations() {
        highlightHexByVerse = Highlight.versesForChapter(in: modelContext, book: book.id, chapter: chapter)
        bookmarkedVerses = Bookmark.versesForChapter(in: modelContext, book: book.id, chapter: chapter)
        notesByVerse = Note.versesForChapter(in: modelContext, book: book.id, chapter: chapter)
    }
}
