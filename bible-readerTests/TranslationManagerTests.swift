import Testing
import Foundation
@testable import bible_reader

@MainActor
struct TranslationManagerTests {
    /// A stub Downloader returning canned manifest bytes and a prebuilt file.
    final class StubDownloader: Downloader {
        var manifestData = Data()
        var fileToReturn: URL?
        var thrownError: Error?
        func data(from url: URL) async throws -> Data {
            if let thrownError { throw thrownError }
            return manifestData
        }
        func downloadToFile(from url: URL, progress: @escaping @Sendable (Double) -> Void) async throws -> URL {
            if let thrownError { throw thrownError }
            progress(1.0)
            return fileToReturn!
        }
    }

    /// Writes a real on-disk SQLite for `id` and returns (fileURL, sha256, bytes).
    func makeTranslationFile(id: String, dir: URL, text: String) throws -> (URL, String, Int) {
        let path = dir.appending(path: "\(id).sqlite").path
        let seed = try BibleStore.inMemory(seedSQL: """
            CREATE TABLE verses (translation_id TEXT, book INTEGER, chapter INTEGER,
                verse INTEGER, text TEXT, PRIMARY KEY(translation_id, book, chapter, verse));
            INSERT INTO verses VALUES ('\(id)',1,1,1,'\(text)');
            """, translationID: id)
        try seed.vacuum(into: path)
        let url = URL(filePath: path)
        let bytes = try Data(contentsOf: url).count
        return (url, try sha256(ofFileAt: url), bytes)
    }

    func makeManager(dir: URL, downloader: Downloader) throws -> TranslationManager {
        let bundled = try BibleStore.inMemory(seedSQL:
            "CREATE TABLE verses (translation_id TEXT, book INTEGER, chapter INTEGER, verse INTEGER, text TEXT);",
            translationID: "cuv")
        return TranslationManager(
            bundledStore: bundled,
            downloader: downloader,
            directory: dir,
            manifestURL: URL(string: "https://example.com/manifest.json")!)
    }

    func tempDir() throws -> URL {
        let dir = URL.temporaryDirectory.appending(path: "mgr-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test func builtInAlwaysInstalled() throws {
        let dir = try tempDir()
        let mgr = try makeManager(dir: dir, downloader: StubDownloader())
        mgr.refreshInstalled()
        #expect(mgr.installed.contains { $0.id == "cuv" && $0.isBuiltIn })
    }

    @Test func scansInstalledFiles() throws {
        let dir = try tempDir()
        _ = try makeTranslationFile(id: "kjv", dir: dir, text: "x")
        let mgr = try makeManager(dir: dir, downloader: StubDownloader())
        mgr.refreshInstalled()
        #expect(mgr.installed.contains { $0.id == "kjv" && !$0.isBuiltIn })
        #expect(mgr.store(for: "kjv") != nil)
    }

    @Test func installVerifiesChecksumAndAppears() async throws {
        let dir = try tempDir()
        let srcDir = try tempDir()
        let (file, hash, bytes) = try makeTranslationFile(id: "kjv", dir: srcDir, text: "In the beginning")
        let stub = StubDownloader()
        stub.fileToReturn = file
        let mgr = try makeManager(dir: dir, downloader: stub)
        let remote = RemoteTranslation(id: "kjv", nameZH: "英王钦定本", nameEN: "KJV",
            abbrev: "KJV", language: "en", url: file, bytes: bytes, sha256: hash)

        try await mgr.install(remote)

        #expect(mgr.installed.contains { $0.id == "kjv" })
        #expect(FileManager.default.fileExists(atPath: dir.appending(path: "kjv.sqlite").path))
        let verses = try #require(mgr.store(for: "kjv")).verses(book: 1, chapter: 1)
        #expect(verses.first?.text == "In the beginning")
    }

    @Test func installRejectsTamperedChecksum() async throws {
        let dir = try tempDir()
        let srcDir = try tempDir()
        let (file, _, bytes) = try makeTranslationFile(id: "kjv", dir: srcDir, text: "tampered")
        let stub = StubDownloader()
        stub.fileToReturn = file
        let mgr = try makeManager(dir: dir, downloader: stub)
        let remote = RemoteTranslation(id: "kjv", nameZH: "x", nameEN: "x", abbrev: "x",
            language: "en", url: file, bytes: bytes, sha256: "deadbeef")  // wrong hash

        await #expect(throws: TranslationInstallError.checksumMismatch) {
            try await mgr.install(remote)
        }
        #expect(!FileManager.default.fileExists(atPath: dir.appending(path: "kjv.sqlite").path))
        #expect(!mgr.installed.contains { $0.id == "kjv" })
    }

    @Test func deleteRemovesDownloadedFile() throws {
        let dir = try tempDir()
        _ = try makeTranslationFile(id: "kjv", dir: dir, text: "x")
        let mgr = try makeManager(dir: dir, downloader: StubDownloader())
        mgr.refreshInstalled()
        #expect(mgr.installed.contains { $0.id == "kjv" })

        try mgr.delete("kjv")

        #expect(!FileManager.default.fileExists(atPath: dir.appending(path: "kjv.sqlite").path))
        #expect(!mgr.installed.contains { $0.id == "kjv" })
    }

    @Test func deleteRefusesBuiltIn() throws {
        let dir = try tempDir()
        let mgr = try makeManager(dir: dir, downloader: StubDownloader())
        #expect(throws: TranslationInstallError.cannotDeleteBuiltIn) {
            try mgr.delete("cuv")
        }
        #expect(mgr.installed.contains { $0.id == "cuv" })
    }

    @Test func fetchCatalogListsNotYetInstalled() async throws {
        let dir = try tempDir()
        _ = try makeTranslationFile(id: "kjv", dir: dir, text: "x")  // kjv already installed
        let stub = StubDownloader()
        stub.manifestData = Data("""
        { "schemaVersion": 1, "translations": [
          { "id": "kjv", "nameZH": "英王钦定本", "nameEN": "KJV", "abbrev": "KJV",
            "language": "en", "url": "https://e.com/kjv.sqlite", "bytes": 1, "sha256": "a" },
          { "id": "web", "nameZH": "世界英文圣经", "nameEN": "WEB", "abbrev": "WEB",
            "language": "en", "url": "https://e.com/web.sqlite", "bytes": 1, "sha256": "b" } ] }
        """.utf8)
        let mgr = try makeManager(dir: dir, downloader: stub)
        mgr.refreshInstalled()

        await mgr.fetchCatalog()

        // kjv is installed → only web is offered for download.
        #expect(mgr.available.map(\.id) == ["web"])
        #expect(mgr.catalogError == nil)
    }

    @Test func fetchCatalogSurfacesError() async throws {
        let dir = try tempDir()
        let stub = StubDownloader()
        stub.thrownError = URLError(.notConnectedToInternet)
        let mgr = try makeManager(dir: dir, downloader: stub)

        await mgr.fetchCatalog()

        #expect(mgr.catalogError != nil)
        #expect(mgr.available.isEmpty)
    }

    @Test func fetchCatalogRejectsUnsupportedSchema() async throws {
        let dir = try tempDir()
        let stub = StubDownloader()
        stub.manifestData = Data(#"{ "schemaVersion": 99, "translations": [] }"#.utf8)
        let mgr = try makeManager(dir: dir, downloader: stub)

        await mgr.fetchCatalog()

        #expect(mgr.catalogError?.contains("需要更新 App") == true)
        #expect(mgr.available.isEmpty)
    }
}
