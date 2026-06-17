import Testing
import Foundation
@testable import bible_reader

struct TranslationManifestTests {
    private let json = """
    { "schemaVersion": 1, "translations": [
        { "id": "kjv", "nameZH": "英王钦定本", "nameEN": "King James Version",
          "abbrev": "KJV", "language": "en",
          "url": "https://example.com/kjv.sqlite", "bytes": 4500000, "sha256": "abc123" } ] }
    """

    @Test func decodesTranslations() throws {
        let manifest = try TranslationManifest.decode(Data(json.utf8))
        #expect(manifest.schemaVersion == 1)
        #expect(manifest.translations.count == 1)
        let t = try #require(manifest.translations.first)
        #expect(t.id == "kjv")
        #expect(t.nameZH == "英王钦定本")
        #expect(t.nameEN == "King James Version")
        #expect(t.language == "en")
        #expect(t.abbrev == "KJV")
        #expect(t.bytes == 4500000)
        #expect(t.sha256 == "abc123")
        #expect(t.url == URL(string: "https://example.com/kjv.sqlite"))
    }

    @Test func rejectsUnsupportedSchemaVersion() throws {
        let future = #"{ "schemaVersion": 99, "translations": [] }"#
        #expect(throws: TranslationManifestError.unsupportedSchema) {
            try TranslationManifest.decode(Data(future.utf8))
        }
    }
}
