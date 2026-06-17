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
}
