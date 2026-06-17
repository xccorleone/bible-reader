import SwiftUI
import SwiftData

struct ReadingView: View {
    let store: BibleStore
    /// Optional parallel translation. When set, each verse shows this
    /// translation's text beneath the primary line.
    var secondaryStore: BibleStore? = nil
    let book: BookInfo
    let chapter: Int

    @Environment(ReadingSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @Environment(FocusCoordinator.self) private var focus
    @Environment(\.scenePhase) private var scenePhase
    @State private var timer = ReadingTimer()

    @State private var verses: [Verse] = []
    @State private var rows: [ParallelRow] = []
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

    /// Re-runs `load()` when the chapter or either translation changes, so
    /// switching the primary/secondary translation refreshes the page in place.
    private var reloadKey: String {
        "\(chapter)|\(store.translationID)|\(secondaryStore?.translationID ?? "")"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if let loadError {
                    Text(loadError).foregroundStyle(.red)
                }
                ForEach(rows) { row in
                    VerseRow(
                        verse: Verse(number: row.number, text: row.primary),
                        fontSize: settings.fontSize,
                        highlightHex: highlightHexByVerse[row.number],
                        isBookmarked: bookmarkedVerses.contains(row.number),
                        hasNote: notesByVerse[row.number] != nil,
                        secondaryText: row.secondary,
                        isParallel: secondaryStore != nil,
                        isSelected: selectedVerses.contains(row.number),
                        onTap: { toggleSelection(row.number) },
                        onTapNote: { editingNote = EditingNote(verse: row.number) }
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
        .task(id: reloadKey) { load() }
        .onAppear { timer.resume() }
        .onDisappear { flushReadingTime(); timer.pause() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { timer.resume() }
            else { flushReadingTime(); timer.pause() }
        }
        .task {
            // Flush accrued reading time every 5s while this view is alive.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                flushReadingTime()
            }
        }
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
        selectedVerses.removeAll()
        loadError = nil
        do {
            verses = try store.verses(book: book.id, chapter: chapter)
            let secondaryVerses = try secondaryStore?.verses(book: book.id, chapter: chapter)
            rows = ParallelVerses.join(primary: verses, secondary: secondaryVerses)
            LastReadPosition.update(
                in: modelContext, book: book.id, chapter: chapter, translationID: store.translationID)
            reloadAnnotations()
        } catch {
            loadError = "无法加载经文：\(error.localizedDescription)"
        }
    }

    private func flushReadingTime() {
        let seconds = timer.drain()
        if seconds > 0 { focus.recordReading(seconds: seconds) }
    }

    private func reloadAnnotations() {
        highlightHexByVerse = Highlight.versesForChapter(in: modelContext, book: book.id, chapter: chapter)
        bookmarkedVerses = Bookmark.versesForChapter(in: modelContext, book: book.id, chapter: chapter)
        notesByVerse = Note.versesForChapter(in: modelContext, book: book.id, chapter: chapter)
    }
}
