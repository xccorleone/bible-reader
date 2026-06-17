import Foundation

/// A canonical pointer to a single verse. Book numbers are stable across
/// translations (1 = Genesis … 66 = Revelation).
struct Reference: Equatable, Hashable, Codable {
    var book: Int
    var chapter: Int
    var verse: Int

    func displayString(bookName: String) -> String {
        "\(bookName) \(chapter):\(verse)"
    }
}
