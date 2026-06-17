/// A single verse within a chapter, returned by `BibleStore`.
struct Verse: Identifiable, Hashable {
    let number: Int      // verse number within the chapter
    let text: String
    var id: Int { number }
}
