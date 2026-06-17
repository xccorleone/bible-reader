# Bible Reader Phase 2 (个人标注) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add personal annotations — bookmarks, whole-verse highlights, and per-verse notes — to the existing reader, plus a "我的标注" summary tab.

**Architecture:** Annotations are local-only SwiftData `@Model`s, separate from the read-only GRDB Bible text. Each model stores flat `book/chapter/verse` Int columns (queryable by `#Predicate`, mirroring `LastReadPosition`) and exposes a computed `Reference`. The reading view gains a tap-to-select interaction with a bottom toolbar; rendering loads the chapter's annotations once into lookup dictionaries. Root navigation becomes a `TabView` (阅读 / 我的标注) with cross-tab jump to a referenced chapter.

**Tech Stack:** Swift 5 / SwiftUI / SwiftData (Xcode 26.5, iOS 26.5), GRDB.swift (existing), Swift Testing.

**Design deviation (intentional):** The spec §3 says models "embed `Reference`". SwiftData `#Predicate` cannot filter on members of an embedded `Codable` struct, so models store flat `book/chapter/verse` Ints (like `LastReadPosition`) and expose a computed `var ref: Reference`. Same data, queryable.

---

## File Structure

**New — annotation models (under `bible-reader/`, auto-added to target):**
- `Bookmark.swift` — `@Model Bookmark` + `toggle` / `versesForChapter` helpers.
- `Highlight.swift` — `@Model Highlight` + `setColor` / `remove` / `versesForChapter`.
- `Note.swift` — `@Model Note` + `upsert` / `fetch` / `versesForChapter`.
- `HighlightColor.swift` — `HighlightPalette` (4 hex colors) + `Color(hex:)` init.

**New — views:**
- `VerseRow.swift` — renders one verse (highlight bg, bookmark/note icons, selection border, tap handling).
- `VerseSelectionToolbar.swift` — bottom action bar shown while verses are selected.
- `NoteEditorView.swift` — note edit sheet.
- `AnnotationsView.swift` — "我的标注" summary page.

**Modified:**
- `bible_readerApp.swift` — register the 3 new models in `Schema`.
- `ReadingView.swift` — selection state, annotation loading/rendering, toolbar, note sheet.
- `ContentView.swift` — `TabView` root + cross-tab jump.

**Tests (under `bible-readerTests/`):**
- `BookmarkTests.swift`, `HighlightTests.swift`, `NoteTests.swift`.

---

## Task 1: Highlight palette + Color(hex)

**Files:**
- Create: `bible-reader/HighlightColor.swift`

- [ ] **Step 1: Create the palette and hex color initializer**

```swift
// bible-reader/HighlightColor.swift
import SwiftUI

/// Fixed 4-color highlight palette, stored as hex strings so the palette can
/// change without a schema migration.
enum HighlightPalette {
    /// Yellow, green, blue, pink.
    static let colors: [String] = ["#FFE08A", "#B5E8A0", "#A8D8F0", "#F4B8D0"]
}

extension Color {
    /// Creates a color from a "#RRGGBB" hex string. Unparseable input yields black.
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&rgb)
        let r = Double((rgb & 0xFF0000) >> 16) / 255
        let g = Double((rgb & 0x00FF00) >> 8) / 255
        let b = Double(rgb & 0x0000FF) / 255
        self = Color(red: r, green: g, blue: b)
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run:
```bash
xcodebuild -project bible-reader.xcodeproj -scheme bible-reader -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add bible-reader/HighlightColor.swift
git commit -m "Add highlight palette and Color(hex:) initializer"
```

---

## Task 2: Bookmark model (TDD)

**Files:**
- Create: `bible-reader/Bookmark.swift`
- Test: `bible-readerTests/BookmarkTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// bible-readerTests/BookmarkTests.swift
import Testing
import SwiftData
@testable import bible_reader

@MainActor
struct BookmarkTests {
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Bookmark.self, configurations: config)
        return ModelContext(container)
    }

    @Test func toggleAddsThenRemoves() throws {
        let ctx = try makeContext()
        let ref = Reference(book: 1, chapter: 1, verse: 1)
        Bookmark.toggle(in: ctx, ref: ref)
        #expect(Bookmark.versesForChapter(in: ctx, book: 1, chapter: 1) == [1])
        Bookmark.toggle(in: ctx, ref: ref)
        #expect(Bookmark.versesForChapter(in: ctx, book: 1, chapter: 1).isEmpty)
    }

    @Test func versesForChapterScopedToChapter() throws {
        let ctx = try makeContext()
        Bookmark.toggle(in: ctx, ref: Reference(book: 1, chapter: 1, verse: 2))
        Bookmark.toggle(in: ctx, ref: Reference(book: 1, chapter: 2, verse: 1))
        #expect(Bookmark.versesForChapter(in: ctx, book: 1, chapter: 1) == [2])
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run:
```bash
xcodebuild -project bible-reader.xcodeproj -scheme bible-reader -destination 'platform=iOS Simulator,name=iPhone 17' test 2>&1 | tail -15
```
Expected: compile failure — `cannot find 'Bookmark' in scope`.

- [ ] **Step 3: Implement the model**

```swift
// bible-reader/Bookmark.swift
import Foundation
import SwiftData

/// A bookmark on a single verse. Flat columns keep it queryable by #Predicate.
@Model
final class Bookmark {
    var book: Int
    var chapter: Int
    var verse: Int
    var createdAt: Date

    init(book: Int, chapter: Int, verse: Int, createdAt: Date = .now) {
        self.book = book
        self.chapter = chapter
        self.verse = verse
        self.createdAt = createdAt
    }

    convenience init(ref: Reference, createdAt: Date = .now) {
        self.init(book: ref.book, chapter: ref.chapter, verse: ref.verse, createdAt: createdAt)
    }

    var ref: Reference { Reference(book: book, chapter: chapter, verse: verse) }
}

extension Bookmark {
    /// Adds a bookmark for `ref` if absent, removes it if present.
    static func toggle(in context: ModelContext, ref: Reference) {
        let b = ref.book; let c = ref.chapter; let v = ref.verse
        let descriptor = FetchDescriptor<Bookmark>(
            predicate: #Predicate { $0.book == b && $0.chapter == c && $0.verse == v })
        if let existing = (try? context.fetch(descriptor))?.first {
            context.delete(existing)
        } else {
            context.insert(Bookmark(ref: ref))
        }
        try? context.save()
    }

    /// Verse numbers bookmarked in the given chapter.
    static func versesForChapter(in context: ModelContext, book: Int, chapter: Int) -> Set<Int> {
        let descriptor = FetchDescriptor<Bookmark>(
            predicate: #Predicate { $0.book == book && $0.chapter == chapter })
        let rows = (try? context.fetch(descriptor)) ?? []
        return Set(rows.map(\.verse))
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run:
```bash
xcodebuild -project bible-reader.xcodeproj -scheme bible-reader -destination 'platform=iOS Simulator,name=iPhone 17' test 2>&1 | tail -15
```
Expected: tests pass.

- [ ] **Step 5: Commit**

```bash
git add bible-reader/Bookmark.swift bible-readerTests/BookmarkTests.swift
git commit -m "Add Bookmark model with toggle and chapter query"
```

---

## Task 3: Highlight model (TDD)

**Files:**
- Create: `bible-reader/Highlight.swift`
- Test: `bible-readerTests/HighlightTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// bible-readerTests/HighlightTests.swift
import Testing
import SwiftData
@testable import bible_reader

@MainActor
struct HighlightTests {
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Highlight.self, configurations: config)
        return ModelContext(container)
    }

    @Test func setColorThenChangeColorKeepsSingleRow() throws {
        let ctx = try makeContext()
        let ref = Reference(book: 1, chapter: 1, verse: 1)
        Highlight.setColor(in: ctx, ref: ref, colorHex: "#FFE08A")
        Highlight.setColor(in: ctx, ref: ref, colorHex: "#A8D8F0")
        #expect(Highlight.versesForChapter(in: ctx, book: 1, chapter: 1) == [1: "#A8D8F0"])
    }

    @Test func removeDeletesHighlight() throws {
        let ctx = try makeContext()
        let ref = Reference(book: 1, chapter: 1, verse: 1)
        Highlight.setColor(in: ctx, ref: ref, colorHex: "#FFE08A")
        Highlight.remove(in: ctx, ref: ref)
        #expect(Highlight.versesForChapter(in: ctx, book: 1, chapter: 1).isEmpty)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run:
```bash
xcodebuild -project bible-reader.xcodeproj -scheme bible-reader -destination 'platform=iOS Simulator,name=iPhone 17' test 2>&1 | tail -15
```
Expected: compile failure — `cannot find 'Highlight' in scope`.

- [ ] **Step 3: Implement the model**

```swift
// bible-reader/Highlight.swift
import Foundation
import SwiftData

/// A whole-verse highlight. One row per verse (not a start/end range), so
/// rendering and recolor/remove are direct single-verse operations.
@Model
final class Highlight {
    var book: Int
    var chapter: Int
    var verse: Int
    var colorHex: String
    var createdAt: Date

    init(book: Int, chapter: Int, verse: Int, colorHex: String, createdAt: Date = .now) {
        self.book = book
        self.chapter = chapter
        self.verse = verse
        self.colorHex = colorHex
        self.createdAt = createdAt
    }

    convenience init(ref: Reference, colorHex: String, createdAt: Date = .now) {
        self.init(book: ref.book, chapter: ref.chapter, verse: ref.verse,
                  colorHex: colorHex, createdAt: createdAt)
    }

    var ref: Reference { Reference(book: book, chapter: chapter, verse: verse) }
}

extension Highlight {
    /// Upserts the highlight for `ref`, setting its color.
    static func setColor(in context: ModelContext, ref: Reference, colorHex: String) {
        let b = ref.book; let c = ref.chapter; let v = ref.verse
        let descriptor = FetchDescriptor<Highlight>(
            predicate: #Predicate { $0.book == b && $0.chapter == c && $0.verse == v })
        if let existing = (try? context.fetch(descriptor))?.first {
            existing.colorHex = colorHex
        } else {
            context.insert(Highlight(ref: ref, colorHex: colorHex))
        }
        try? context.save()
    }

    /// Removes the highlight on `ref`, if any.
    static func remove(in context: ModelContext, ref: Reference) {
        let b = ref.book; let c = ref.chapter; let v = ref.verse
        let descriptor = FetchDescriptor<Highlight>(
            predicate: #Predicate { $0.book == b && $0.chapter == c && $0.verse == v })
        if let existing = (try? context.fetch(descriptor))?.first {
            context.delete(existing)
            try? context.save()
        }
    }

    /// Map of verse number → color hex for the given chapter.
    static func versesForChapter(in context: ModelContext, book: Int, chapter: Int) -> [Int: String] {
        let descriptor = FetchDescriptor<Highlight>(
            predicate: #Predicate { $0.book == book && $0.chapter == chapter })
        let rows = (try? context.fetch(descriptor)) ?? []
        return Dictionary(rows.map { ($0.verse, $0.colorHex) }, uniquingKeysWith: { _, new in new })
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run:
```bash
xcodebuild -project bible-reader.xcodeproj -scheme bible-reader -destination 'platform=iOS Simulator,name=iPhone 17' test 2>&1 | tail -15
```
Expected: tests pass.

- [ ] **Step 5: Commit**

```bash
git add bible-reader/Highlight.swift bible-readerTests/HighlightTests.swift
git commit -m "Add Highlight model with per-verse color upsert"
```

---

## Task 4: Note model (TDD)

**Files:**
- Create: `bible-reader/Note.swift`
- Test: `bible-readerTests/NoteTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// bible-readerTests/NoteTests.swift
import Testing
import SwiftData
@testable import bible_reader

@MainActor
struct NoteTests {
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Note.self, configurations: config)
        return ModelContext(container)
    }

    @Test func upsertCreatesThenUpdatesKeepingSingleRow() throws {
        let ctx = try makeContext()
        let ref = Reference(book: 1, chapter: 1, verse: 1)
        Note.upsert(in: ctx, ref: ref, body: "first")
        Note.upsert(in: ctx, ref: ref, body: "second")
        let all = try ctx.fetch(FetchDescriptor<Note>())
        #expect(all.count == 1)
        #expect(Note.fetch(in: ctx, ref: ref)?.body == "second")
    }

    @Test func upsertEmptyBodyDeletes() throws {
        let ctx = try makeContext()
        let ref = Reference(book: 1, chapter: 1, verse: 1)
        Note.upsert(in: ctx, ref: ref, body: "x")
        Note.upsert(in: ctx, ref: ref, body: "   ")
        #expect(Note.fetch(in: ctx, ref: ref) == nil)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run:
```bash
xcodebuild -project bible-reader.xcodeproj -scheme bible-reader -destination 'platform=iOS Simulator,name=iPhone 17' test 2>&1 | tail -15
```
Expected: compile failure — `cannot find 'Note' in scope`.

- [ ] **Step 3: Implement the model**

```swift
// bible-reader/Note.swift
import Foundation
import SwiftData

/// A free-text note on a single verse.
@Model
final class Note {
    var book: Int
    var chapter: Int
    var verse: Int
    var body: String
    var createdAt: Date
    var updatedAt: Date

    init(book: Int, chapter: Int, verse: Int, body: String,
         createdAt: Date = .now, updatedAt: Date = .now) {
        self.book = book
        self.chapter = chapter
        self.verse = verse
        self.body = body
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    convenience init(ref: Reference, body: String) {
        self.init(book: ref.book, chapter: ref.chapter, verse: ref.verse, body: body)
    }

    var ref: Reference { Reference(book: book, chapter: chapter, verse: verse) }
}

extension Note {
    /// Creates/updates the note for `ref`. A blank body deletes the note.
    static func upsert(in context: ModelContext, ref: Reference, body: String) {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        let b = ref.book; let c = ref.chapter; let v = ref.verse
        let descriptor = FetchDescriptor<Note>(
            predicate: #Predicate { $0.book == b && $0.chapter == c && $0.verse == v })
        let existing = (try? context.fetch(descriptor))?.first
        if trimmed.isEmpty {
            if let existing { context.delete(existing) }
        } else if let existing {
            existing.body = trimmed
            existing.updatedAt = .now
        } else {
            context.insert(Note(ref: ref, body: trimmed))
        }
        try? context.save()
    }

    /// The note on `ref`, if any.
    static func fetch(in context: ModelContext, ref: Reference) -> Note? {
        let b = ref.book; let c = ref.chapter; let v = ref.verse
        let descriptor = FetchDescriptor<Note>(
            predicate: #Predicate { $0.book == b && $0.chapter == c && $0.verse == v })
        return (try? context.fetch(descriptor))?.first
    }

    /// Map of verse number → Note for the given chapter.
    static func versesForChapter(in context: ModelContext, book: Int, chapter: Int) -> [Int: Note] {
        let descriptor = FetchDescriptor<Note>(
            predicate: #Predicate { $0.book == book && $0.chapter == chapter })
        let rows = (try? context.fetch(descriptor)) ?? []
        return Dictionary(rows.map { ($0.verse, $0) }, uniquingKeysWith: { _, new in new })
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run:
```bash
xcodebuild -project bible-reader.xcodeproj -scheme bible-reader -destination 'platform=iOS Simulator,name=iPhone 17' test 2>&1 | tail -15
```
Expected: tests pass.

- [ ] **Step 5: Commit**

```bash
git add bible-reader/Note.swift bible-readerTests/NoteTests.swift
git commit -m "Add Note model with upsert and chapter query"
```

---

## Task 5: Register annotation models in the schema

**Files:**
- Modify: `bible-reader/bible_readerApp.swift:16`

- [ ] **Step 1: Add the three models to the schema**

Replace the schema line in `bible_readerApp.swift`:

```swift
        let schema = Schema([LastReadPosition.self])
```

with:

```swift
        let schema = Schema([LastReadPosition.self, Bookmark.self, Highlight.self, Note.self])
```

- [ ] **Step 2: Verify it builds**

Run:
```bash
xcodebuild -project bible-reader.xcodeproj -scheme bible-reader -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add bible-reader/bible_readerApp.swift
git commit -m "Register annotation models in SwiftData schema"
```

---

## Task 6: VerseRow view

**Files:**
- Create: `bible-reader/VerseRow.swift`

- [ ] **Step 1: Implement the row**

```swift
// bible-reader/VerseRow.swift
import SwiftUI

/// One verse line: optional bookmark icon, verse number + text with optional
/// highlight background, optional note icon, and a selection border.
struct VerseRow: View {
    let verse: Verse
    let fontSize: Double
    let highlightHex: String?
    let isBookmarked: Bool
    let hasNote: Bool
    let isSelected: Bool
    let onTap: () -> Void
    let onTapNote: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            if isBookmarked {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: fontSize * 0.6))
                    .foregroundStyle(.orange)
            }
            (Text("\(verse.number) ")
                .font(.system(size: fontSize * 0.7))
                .foregroundStyle(.secondary)
             + Text(verse.text).font(.system(size: fontSize)))
            if hasNote {
                Button(action: onTapNote) {
                    Image(systemName: "note.text")
                        .font(.system(size: fontSize * 0.6))
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(highlightHex.map { Color(hex: $0) } ?? .clear)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 2)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}
```

- [ ] **Step 2: Verify it builds**

Run:
```bash
xcodebuild -project bible-reader.xcodeproj -scheme bible-reader -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add bible-reader/VerseRow.swift
git commit -m "Add VerseRow view with highlight, bookmark, note, selection"
```

---

## Task 7: VerseSelectionToolbar view

**Files:**
- Create: `bible-reader/VerseSelectionToolbar.swift`

- [ ] **Step 1: Implement the toolbar**

```swift
// bible-reader/VerseSelectionToolbar.swift
import SwiftUI

/// Bottom action bar shown while one or more verses are selected.
/// Note is enabled only for a single selected verse.
struct VerseSelectionToolbar: View {
    let canAddNote: Bool
    let onBookmark: () -> Void
    let onHighlight: (String) -> Void
    let onNote: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Button(action: onBookmark) {
                Image(systemName: "bookmark")
            }
            ForEach(HighlightPalette.colors, id: \.self) { hex in
                Button {
                    onHighlight(hex)
                } label: {
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 24, height: 24)
                        .overlay(Circle().stroke(.secondary, lineWidth: 0.5))
                }
                .buttonStyle(.plain)
            }
            Button(action: onNote) {
                Image(systemName: "note.text")
            }
            .disabled(!canAddNote)
            Spacer()
            Button("取消", action: onCancel)
        }
        .padding()
        .background(.bar)
    }
}
```

- [ ] **Step 2: Verify it builds**

Run:
```bash
xcodebuild -project bible-reader.xcodeproj -scheme bible-reader -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add bible-reader/VerseSelectionToolbar.swift
git commit -m "Add verse selection toolbar"
```

---

## Task 8: NoteEditorView sheet

**Files:**
- Create: `bible-reader/NoteEditorView.swift`

- [ ] **Step 1: Implement the editor**

```swift
// bible-reader/NoteEditorView.swift
import SwiftUI

/// Modal editor for a single verse's note. Calls `onSave` with the edited text;
/// the caller is responsible for persisting (blank body deletes the note).
struct NoteEditorView: View {
    let reference: Reference
    let bookName: String
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String

    init(reference: Reference, bookName: String, existingBody: String, onSave: @escaping (String) -> Void) {
        self.reference = reference
        self.bookName = bookName
        self.onSave = onSave
        _text = State(initialValue: existingBody)
    }

    var body: some View {
        NavigationStack {
            TextEditor(text: $text)
                .padding()
                .navigationTitle(reference.displayString(bookName: bookName))
#if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
#endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存") {
                            onSave(text)
                            dismiss()
                        }
                    }
                }
        }
    }
}
```

- [ ] **Step 2: Verify it builds**

Run:
```bash
xcodebuild -project bible-reader.xcodeproj -scheme bible-reader -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add bible-reader/NoteEditorView.swift
git commit -m "Add note editor sheet"
```

---

## Task 9: Wire annotations into ReadingView

**Files:**
- Modify: `bible-reader/ReadingView.swift` (full rewrite)

- [ ] **Step 1: Rewrite ReadingView**

Replace the entire contents of `bible-reader/ReadingView.swift` with:

```swift
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
```

- [ ] **Step 2: Verify it builds**

Run:
```bash
xcodebuild -project bible-reader.xcodeproj -scheme bible-reader -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add bible-reader/ReadingView.swift
git commit -m "Wire bookmarks, highlights, notes into ReadingView"
```

---

## Task 10: AnnotationsView (我的标注)

**Files:**
- Create: `bible-reader/AnnotationsView.swift`

- [ ] **Step 1: Implement the summary page**

```swift
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
```

- [ ] **Step 2: Verify it builds**

Run:
```bash
xcodebuild -project bible-reader.xcodeproj -scheme bible-reader -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add bible-reader/AnnotationsView.swift
git commit -m "Add 我的标注 annotations summary page"
```

---

## Task 11: TabView root + cross-tab jump

**Files:**
- Modify: `bible-reader/ContentView.swift` (full rewrite)

- [ ] **Step 1: Rewrite ContentView with a TabView and jump handler**

Replace the entire contents of `bible-reader/ContentView.swift` with:

```swift
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
                        AnnotationsView(books: books, onOpen: openReference)
                    }
                    .tabItem { Label("我的标注", systemImage: "bookmark") }
                    .tag(1)
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

    /// Jumps the reading tab to the chapter containing `ref`.
    private func openReference(_ ref: Reference) {
        guard let book = books.first(where: { $0.id == ref.book }) else { return }
        selectedTab = 0
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
```

- [ ] **Step 2: Build and verify**

Run:
```bash
xcodebuild -project bible-reader.xcodeproj -scheme bible-reader -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Run the full test suite**

Run:
```bash
xcodebuild -project bible-reader.xcodeproj -scheme bible-reader -destination 'platform=iOS Simulator,name=iPhone 17' test 2>&1 | tail -15
```
Expected: all tests pass (Reference, BibleStore, LastReadPosition, Bookmark, Highlight, Note).

- [ ] **Step 4: Manual smoke test on the simulator**

Launch the app (Xcode ▸ Run, or boot `iPhone 17`). Verify:
- 阅读 tab: open 创世记 1. Tap verse 1 → selection border + bottom toolbar appears.
- Tap a color swatch → verse 1 gets that background. Tap same color again → highlight removed.
- Select verses 1–3 (multi-tap) → tap a color → all three highlighted at once.
- With a single verse selected, tap the note button → editor opens → type text → 保存 → note icon appears at the verse end. Tap the note icon → editor reopens with the text.
- Tap the bookmark button on a verse → bookmark icon appears at the verse start.
- 我的标注 tab: the bookmark/highlight/note appear under their sections. Tap an entry → switches to 阅读 tab and opens that chapter.
- Empty-state: with no annotations (fresh install), 我的标注 shows the empty message.

- [ ] **Step 5: Commit**

```bash
git add bible-reader/ContentView.swift
git commit -m "Make root a TabView with 我的标注 and cross-tab jump"
```

---

## Self-Review Notes (coverage against spec)

- Spec §2 interaction (tap-to-select + bottom toolbar, multi-verse, toggle) → Tasks 6, 7, 9.
- Spec §2 visual feedback (highlight bg, bookmark icon, note icon) → Task 6 (VerseRow), rendering data in Task 9.
- Spec §2 palette (4 hex colors) → Task 1.
- Spec §3 models (Bookmark/Highlight/Note) with per-verse Highlight rows → Tasks 2–4. **Deviation:** flat `book/chapter/verse` Ints + computed `ref` instead of embedded `Reference`, for `#Predicate` queryability (noted in header).
- Spec §3 helper methods (toggle, setColor/remove, upsert, chapter queries) → Tasks 2–4 with unit tests.
- Spec §3 schema registration → Task 5.
- Spec §4 render data flow (one-time chapter load into dicts, refresh on change) → Task 9 (`reloadAnnotations`).
- Spec §5 root TabView (阅读 / 我的标注) + cross-tab jump → Task 11; AnnotationsView → Task 10.
- Spec §6 error handling (silent `try?` save, book-name fallback "书卷N", empty states) → Tasks 2–4 (`try?`), Task 10 (`name(_:)` fallback + ContentUnavailableView).
- Spec §6 empty note body deletes → Task 4 (`Note.upsert`).
- Spec §7 testing (model logic unit-tested; UI manual smoke) → Tasks 2–4 tests; Task 11 step 4.

**Known manual step:** Task 11 step 4 (simulator smoke test) cannot be scripted.
