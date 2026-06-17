import SwiftUI

struct BookListView: View {
    let store: BibleStore
    @State private var books: [BookInfo] = []
    @State private var loadError: String?

    var body: some View {
        List {
            if let loadError {
                Text(loadError).foregroundStyle(.red)
            }
            Section("旧约") {
                ForEach(books.filter { $0.testament == "OT" }) { book in
                    NavigationLink(book.nameZH, value: NavRoute.chapters(book: book))
                }
            }
            Section("新约") {
                ForEach(books.filter { $0.testament == "NT" }) { book in
                    NavigationLink(book.nameZH, value: NavRoute.chapters(book: book))
                }
            }
        }
        .navigationTitle("圣经")
        .task { load() }
    }

    private func load() {
        do { books = try store.allBooks() }
        catch { loadError = "无法加载书卷：\(error.localizedDescription)" }
    }
}
