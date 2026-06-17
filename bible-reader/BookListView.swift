import SwiftUI

struct BookListView: View {
    let books: [BookInfo]

    var body: some View {
        List {
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
    }
}
