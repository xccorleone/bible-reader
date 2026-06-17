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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let loadError {
                    Text(loadError).foregroundStyle(.red)
                }
                ForEach(verses) { verse in
                    (Text("\(verse.number) ").font(.system(size: settings.fontSize * 0.7))
                        .foregroundStyle(.secondary)
                     + Text(verse.text).font(.system(size: settings.fontSize)))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle("\(book.nameZH) \(chapter)")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .task(id: chapter) { load() }
    }

    private func load() {
        do {
            verses = try store.verses(book: book.id, chapter: chapter)
            savePosition()
        } catch {
            loadError = "无法加载经文：\(error.localizedDescription)"
        }
    }

    private func savePosition() {
        let descriptor = FetchDescriptor<LastReadPosition>()
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.book = book.id
            existing.chapter = chapter
            existing.translationID = store.translationID
            existing.updatedAt = .now
        } else {
            modelContext.insert(LastReadPosition(
                book: book.id, chapter: chapter, translationID: store.translationID))
        }
    }
}
