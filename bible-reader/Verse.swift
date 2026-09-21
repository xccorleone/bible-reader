/// A single verse within a chapter, returned by `BibleStore`.
struct Verse: Identifiable, Hashable {
    let number: Int      // verse number within the chapter
    let text: String
    /// True when this verse begins a new paragraph (分段) in the source text.
    var startsParagraph: Bool = false
    var id: Int { number }
}
