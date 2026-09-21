import SwiftUI
import SwiftData

struct ReadingView: View {
    let store: BibleStore
    /// Optional parallel translation. When set, each verse shows this
    /// translation's text beneath the primary line.
    var secondaryStore: BibleStore? = nil
    /// Full book list (sorted), used to cross book boundaries when swiping.
    let books: [BookInfo]

    // Current position. Mutable so left/right swipes can page through chapters
    // (and into adjacent books) in place.
    @State private var book: BookInfo
    @State private var chapter: Int

    init(store: BibleStore, secondaryStore: BibleStore? = nil,
         book: BookInfo, chapter: Int, books: [BookInfo] = []) {
        self.store = store
        self.secondaryStore = secondaryStore
        self.books = books
        _book = State(initialValue: book)
        _chapter = State(initialValue: chapter)
    }

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
        "\(book.id)|\(chapter)|\(store.translationID)|\(secondaryStore?.translationID ?? "")"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 3) {
                if let loadError {
                    Text(loadError).foregroundStyle(.red)
                }
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
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
                    // Open a gap before each new paragraph (分段), except the
                    // chapter's first verse which needs no leading space.
                    .padding(.top, row.startsParagraph && index > 0 ? 13 : 0)
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
        // Horizontal swipe pages chapters: left → next, right → previous.
        // Runs alongside the ScrollView's vertical pan; we only act on a
        // clearly horizontal drag so it never hijacks normal scrolling.
        .simultaneousGesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    let dx = value.translation.width
                    let dy = value.translation.height
                    guard abs(dx) > 60, abs(dx) > abs(dy) * 1.5 else { return }
                    move(by: dx < 0 ? 1 : -1)
                }
        )
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

    /// Moves `delta` chapters, crossing into the adjacent book at a boundary.
    /// No-op past the first/last chapter of the whole Bible.
    private func move(by delta: Int) {
        let target = chapter + delta
        if target >= 1 && target <= book.chapterCount {
            chapter = target
            return
        }
        guard let idx = books.firstIndex(where: { $0.id == book.id }) else { return }
        if delta > 0, idx + 1 < books.count {
            book = books[idx + 1]
            chapter = 1
        } else if delta < 0, idx > 0 {
            let prev = books[idx - 1]
            book = prev
            chapter = prev.chapterCount
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
