import Foundation

/// One display row in parallel reading: a verse number, the primary text, and
/// the aligned secondary text (nil when the secondary translation lacks that
/// verse, e.g. versification differences).
struct ParallelRow: Identifiable, Equatable {
    let number: Int
    let primary: String
    let secondary: String?
    /// True when this verse begins a new paragraph (分段) in the primary text.
    var startsParagraph: Bool = false
    var id: Int { number }
}

enum ParallelVerses {
    /// Joins primary and secondary verses by verse number. When `secondary` is
    /// nil, every row's `.secondary` is nil (single-translation reading).
    static func join(primary: [Verse], secondary: [Verse]?) -> [ParallelRow] {
        let secondaryByNumber: [Int: String]
        if let secondary {
            secondaryByNumber = Dictionary(secondary.map { ($0.number, $0.text) },
                                           uniquingKeysWith: { first, _ in first })
        } else {
            secondaryByNumber = [:]
        }
        return primary.map { verse in
            ParallelRow(number: verse.number, primary: verse.text,
                        secondary: secondary == nil ? nil : secondaryByNumber[verse.number],
                        startsParagraph: verse.startsParagraph)
        }
    }
}
