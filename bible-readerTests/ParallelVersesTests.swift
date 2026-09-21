import Testing
@testable import bible_reader

struct ParallelVersesTests {
    @Test func alignsByVerseNumber() {
        let primary = [Verse(number: 1, text: "起初"), Verse(number: 2, text: "地是空虚")]
        let secondary = [Verse(number: 1, text: "In the beginning"), Verse(number: 2, text: "And the earth")]
        let rows = ParallelVerses.join(primary: primary, secondary: secondary)
        #expect(rows.count == 2)
        #expect(rows[0].number == 1)
        #expect(rows[0].primary == "起初")
        #expect(rows[0].secondary == "In the beginning")
    }

    @Test func missingSecondaryVerseIsNil() {
        let primary = [Verse(number: 1, text: "a"), Verse(number: 2, text: "b")]
        let secondary = [Verse(number: 1, text: "x")]  // no verse 2
        let rows = ParallelVerses.join(primary: primary, secondary: secondary)
        #expect(rows.count == 2)
        #expect(rows[1].number == 2)
        #expect(rows[1].secondary == nil)
    }

    @Test func nilSecondaryArrayGivesNoSecondaryText() {
        let primary = [Verse(number: 1, text: "a")]
        let rows = ParallelVerses.join(primary: primary, secondary: nil)
        #expect(rows == [ParallelRow(number: 1, primary: "a", secondary: nil)])
    }

    @Test func carriesParagraphStartFromPrimary() {
        let primary = [
            Verse(number: 1, text: "a", startsParagraph: true),
            Verse(number: 2, text: "b", startsParagraph: false),
            Verse(number: 3, text: "c", startsParagraph: true),
        ]
        let rows = ParallelVerses.join(primary: primary, secondary: nil)
        #expect(rows.map(\.startsParagraph) == [true, false, true])
    }
}
