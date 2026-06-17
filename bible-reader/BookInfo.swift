/// Metadata for one book of the Bible, returned by `BibleStore`.
struct BookInfo: Identifiable, Hashable {
    let id: Int          // book number 1…66
    let nameZH: String
    let nameEN: String
    let testament: String
    let chapterCount: Int
}
