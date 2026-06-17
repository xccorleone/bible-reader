import Testing
@testable import bible_reader

struct ReferenceTests {
    @Test func referenceIsEquatableByComponents() {
        let a = Reference(book: 1, chapter: 1, verse: 1)
        let b = Reference(book: 1, chapter: 1, verse: 1)
        #expect(a == b)
    }

    @Test func displayStringUsesChineseBookName() {
        let ref = Reference(book: 43, chapter: 3, verse: 16)
        #expect(ref.displayString(bookName: "约翰福音") == "约翰福音 3:16")
    }
}
