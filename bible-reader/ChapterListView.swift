import SwiftUI

struct ChapterListView: View {
    let store: BibleStore
    let book: BookInfo

    private let columns = [GridItem(.adaptive(minimum: 56))]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(1...book.chapterCount, id: \.self) { chapter in
                    NavigationLink(value: NavRoute.reading(book: book, chapter: chapter)) {
                        Text("\(chapter)")
                            .frame(width: 56, height: 56)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .navigationTitle(book.nameZH)
    }
}
