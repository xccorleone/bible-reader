# 圣经阅读器 — 阶段 4(多译本)Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a translation switcher, CN/EN per-verse parallel reading, and a full network-download subsystem (manifest + sha256-verified install) on top of the bundled `cuv` Bible.

**Architecture:** Each translation is an independent read-only SQLite opened into its own `BibleStore` (built-in `cuv` from the bundle; downloaded ones from `AppSupport/Translations/<id>.sqlite`). A `@MainActor @Observable TranslationManager` is the registry: it scans installed files, fetches a hosted `manifest.json`, and installs/deletes translations through an injectable `Downloader` seam (so tests never touch the network). Reading and search point at the user-selected **primary** translation; an optional **secondary** is joined verse-by-verse for parallel display.

**Tech Stack:** Swift / SwiftUI, GRDB (SQLite), CryptoKit (SHA-256), Swift Testing (`@Test`/`#expect`), SwiftData (existing annotations), Python (build tooling).

---

## File Structure

**New Swift files (`bible-reader/`):**
- `TranslationManifest.swift` — `TranslationManifest` + `RemoteTranslation` Codable models.
- `Downloader.swift` — `Downloader` protocol + `URLSessionDownloader` + `sha256(ofFileAt:)`.
- `TranslationManager.swift` — `@MainActor @Observable` registry (installed scan, catalog fetch, install, delete, store lookup).
- `ParallelVerses.swift` — pure join of primary+secondary verse arrays into rows.
- `TranslationsView.swift` — 译本管理 download-manager screen.

**New test files (`bible-readerTests/`):**
- `TranslationManifestTests.swift`, `DownloaderTests.swift`, `TranslationManagerTests.swift`, `ParallelVersesTests.swift`, `ReadingSettingsTests.swift`.

**Modified Swift files:**
- `BibleStore.swift` — add `file(at:translationID:)` read-only opener.
- `ReadingSettings.swift` — add `primaryTranslationID` + `secondaryTranslationID`, inject `UserDefaults`.
- `VerseRow.swift` — render optional secondary line.
- `ReadingView.swift` — accept optional secondary store, build parallel rows.
- `ContentView.swift` — own `TranslationManager`, build primary/secondary stores, translation menu.
- `SettingsView.swift` — link to `TranslationsView`.
- `bible_readerApp.swift` — ensure App Support dir, construct manager.

**New tooling (`tools/`):**
- `build_manifest.py` + `test_build_manifest.py`, README provenance for KJV/WEB.

---

## Task 1: Manifest models

**Files:**
- Create: `bible-reader/TranslationManifest.swift`
- Test: `bible-readerTests/TranslationManifestTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project bible-reader.xcodeproj -scheme bible-reader -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:bible-readerTests/TranslationManifestTests 2>&1 | tail -20`
Expected: FAIL — `cannot find 'TranslationManifest' in scope`.

- [ ] **Step 3: Write minimal implementation**

```swift
import Foundation

/// One downloadable translation as described by the hosted manifest.
struct RemoteTranslation: Codable, Identifiable, Hashable {
    let id: String
    let nameZH: String
    let nameEN: String
    let abbrev: String
    let language: String
    let url: URL
    let bytes: Int
    let sha256: String
}

enum TranslationManifestError: Error, Equatable {
    case unsupportedSchema
}

/// The catalog of downloadable translations, decoded from `manifest.json`.
struct TranslationManifest: Codable {
    static let supportedSchemaVersion = 1

    let schemaVersion: Int
    let translations: [RemoteTranslation]

    static func decode(_ data: Data) throws -> TranslationManifest {
        let manifest = try JSONDecoder().decode(TranslationManifest.self, from: data)
        guard manifest.schemaVersion == supportedSchemaVersion else {
            throw TranslationManifestError.unsupportedSchema
        }
        return manifest
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -project bible-reader.xcodeproj -scheme bible-reader -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:bible-readerTests/TranslationManifestTests 2>&1 | tail -20`
Expected: PASS (`Test Suite 'TranslationManifestTests' passed`).

- [ ] **Step 5: Commit**

```bash
git add bible-reader/TranslationManifest.swift bible-readerTests/TranslationManifestTests.swift
git commit -m "Add translation manifest models with schema-version guard"
```

---

## Task 2: Downloader seam + file SHA-256

**Files:**
- Create: `bible-reader/Downloader.swift`
- Test: `bible-readerTests/DownloaderTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import Testing
import Foundation
import CryptoKit
@testable import bible_reader

struct DownloaderTests {
    @Test func sha256MatchesCryptoKit() throws {
        let bytes = Data("hello bible".utf8)
        let dir = URL.temporaryDirectory.appending(path: "sha-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appending(path: "f.bin")
        try bytes.write(to: file)

        let expected = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        #expect(try sha256(ofFileAt: file) == expected)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project bible-reader.xcodeproj -scheme bible-reader -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:bible-readerTests/DownloaderTests 2>&1 | tail -20`
Expected: FAIL — `cannot find 'sha256' in scope`.

- [ ] **Step 3: Write minimal implementation**

```swift
import Foundation
import CryptoKit

/// Network seam so tests can inject canned responses instead of hitting the net.
protocol Downloader {
    /// Fetches raw bytes (used for the manifest JSON).
    func data(from url: URL) async throws -> Data
    /// Downloads a file to a temporary location, reporting 0…1 progress.
    func downloadToFile(from url: URL, progress: @escaping @Sendable (Double) -> Void) async throws -> URL
}

/// Lowercase hex SHA-256 of a file's contents, hashed in a streaming fashion
/// so multi-megabyte translation files don't all sit in memory at once.
func sha256(ofFileAt url: URL) throws -> String {
    let handle = try FileHandle(forReadingFrom: url)
    defer { try? handle.close() }
    var hasher = SHA256()
    while case let chunk = try handle.read(upToCount: 1 << 20) ?? Data(), !chunk.isEmpty {
        hasher.update(data: chunk)
    }
    return hasher.finalize().map { String(format: "%02x", $0) }.joined()
}

/// Production `Downloader` backed by `URLSession`.
struct URLSessionDownloader: Downloader {
    let session: URLSession = .shared

    func data(from url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        try Self.check(response)
        return data
    }

    func downloadToFile(from url: URL, progress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        let (bytes, response) = try await session.bytes(from: url)
        try Self.check(response)
        let total = max(response.expectedContentLength, 1)
        let dest = URL.temporaryDirectory.appending(path: "dl-\(UUID().uuidString).sqlite")
        FileManager.default.createFile(atPath: dest.path, contents: nil)
        let handle = try FileHandle(forWritingTo: dest)
        defer { try? handle.close() }
        var buffer = Data()
        var received: Int64 = 0
        for try await byte in bytes {
            buffer.append(byte)
            received += 1
            if buffer.count >= (1 << 20) {
                try handle.write(contentsOf: buffer)
                buffer.removeAll(keepingCapacity: true)
                progress(Double(received) / Double(total))
            }
        }
        if !buffer.isEmpty { try handle.write(contentsOf: buffer) }
        progress(1.0)
        return dest
    }

    private static func check(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -project bible-reader.xcodeproj -scheme bible-reader -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:bible-readerTests/DownloaderTests 2>&1 | tail -20`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add bible-reader/Downloader.swift bible-readerTests/DownloaderTests.swift
git commit -m "Add Downloader protocol, URLSession impl, and streaming file SHA-256"
```

---

## Task 3: BibleStore — open a translation from a file path

**Files:**
- Modify: `bible-reader/BibleStore.swift`
- Test: `bible-readerTests/BibleStoreTests.swift` (append)

- [ ] **Step 1: Write the failing test**

Append to `BibleStoreTests.swift`:

```swift
@Test func opensTranslationFromFilePath() throws {
    // Build a real on-disk DB with a second translation, then reopen read-only.
    let dir = URL.temporaryDirectory.appending(path: "store-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let path = dir.appending(path: "kjv.sqlite").path

    let seed = try BibleStore.inMemory(seedSQL: """
        CREATE TABLE verses (translation_id TEXT, book INTEGER, chapter INTEGER,
            verse INTEGER, text TEXT,
            PRIMARY KEY(translation_id, book, chapter, verse));
        INSERT INTO verses VALUES ('kjv',1,1,1,'In the beginning God created the heaven and the earth.');
        """, translationID: "kjv")
    try seed.dbQueue.writeWithoutTransaction { db in
        try db.execute(sql: "VACUUM INTO ?", arguments: [path])
    }

    let store = try BibleStore.file(at: path, translationID: "kjv")
    let verses = try store.verses(book: 1, chapter: 1)
    #expect(verses == [Verse(number: 1, text: "In the beginning God created the heaven and the earth.")])
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project bible-reader.xcodeproj -scheme bible-reader -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:bible-readerTests/BibleStoreTests/opensTranslationFromFilePath 2>&1 | tail -20`
Expected: FAIL — `type 'BibleStore' has no member 'file'`.

- [ ] **Step 3: Write minimal implementation**

Add to `BibleStore` (after `bundled`):

```swift
    /// Opens a downloaded translation database read-only from an absolute path.
    static func file(at path: String, translationID: String) throws -> BibleStore {
        var config = Configuration()
        config.readonly = true
        let queue = try DatabaseQueue(path: path, configuration: config)
        return BibleStore(dbQueue: queue, translationID: translationID)
    }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -project bible-reader.xcodeproj -scheme bible-reader -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:bible-readerTests/BibleStoreTests/opensTranslationFromFilePath 2>&1 | tail -20`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add bible-reader/BibleStore.swift bible-readerTests/BibleStoreTests.swift
git commit -m "Add BibleStore.file(at:) read-only opener for downloaded translations"
```

---

## Task 4: TranslationManager — installed registry

**Files:**
- Create: `bible-reader/TranslationManager.swift`
- Test: `bible-readerTests/TranslationManagerTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
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
        try seed.dbQueue.writeWithoutTransaction { db in
            try db.execute(sql: "VACUUM INTO ?", arguments: [path])
        }
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project bible-reader.xcodeproj -scheme bible-reader -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:bible-readerTests/TranslationManagerTests 2>&1 | tail -20`
Expected: FAIL — `cannot find 'TranslationManager' in scope`.

- [ ] **Step 3: Write minimal implementation**

```swift
import Foundation
import Observation

/// Registry of available Bible translations: the built-in `cuv` plus any the
/// user has downloaded into `directory`. Network access goes through the
/// injected `Downloader` so it can be exercised without the network.
@MainActor
@Observable
final class TranslationManager {
    struct Installed: Identifiable {
        let id: String
        let displayName: String
        let isBuiltIn: Bool
        let store: BibleStore
    }

    static let builtInID = "cuv"
    static let builtInName = "简体和合本"

    private(set) var installed: [Installed] = []
    private(set) var available: [RemoteTranslation] = []
    var downloadProgress: [String: Double] = [:]
    var catalogError: String?

    private let bundledStore: BibleStore
    private let downloader: Downloader
    private let directory: URL
    private let manifestURL: URL

    init(bundledStore: BibleStore, downloader: Downloader, directory: URL, manifestURL: URL) {
        self.bundledStore = bundledStore
        self.downloader = downloader
        self.directory = directory
        self.manifestURL = manifestURL
        refreshInstalled()
    }

    func store(for id: String) -> BibleStore? {
        installed.first { $0.id == id }?.store
    }

    /// Rebuilds `installed` from the built-in store plus every `<id>.sqlite`
    /// found in `directory` that opens cleanly.
    func refreshInstalled() {
        var result: [Installed] = [
            Installed(id: Self.builtInID, displayName: Self.builtInName, isBuiltIn: true, store: bundledStore)
        ]
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil)) ?? []
        for file in files where file.pathExtension == "sqlite" {
            let id = file.deletingPathExtension().lastPathComponent
            guard id != Self.builtInID,
                  let store = try? BibleStore.file(at: file.path, translationID: id) else { continue }
            result.append(Installed(id: id, displayName: id.uppercased(), isBuiltIn: false, store: store))
        }
        installed = result
    }
}
```

> Note: downloaded translations display as their uppercased id until `available`
> is fetched (Task 7), which carries the friendly `nameZH`. `TranslationsView`
> (Task 12) prefers the manifest name when present.

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -project bible-reader.xcodeproj -scheme bible-reader -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:bible-readerTests/TranslationManagerTests 2>&1 | tail -20`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add bible-reader/TranslationManager.swift bible-readerTests/TranslationManagerTests.swift
git commit -m "Add TranslationManager with built-in + installed-file registry"
```

---

## Task 5: TranslationManager.install — verify + atomic move

**Files:**
- Modify: `bible-reader/TranslationManager.swift`
- Test: `bible-readerTests/TranslationManagerTests.swift` (append)

- [ ] **Step 1: Write the failing test**

```swift
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project bible-reader.xcodeproj -scheme bible-reader -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:bible-readerTests/TranslationManagerTests 2>&1 | tail -20`
Expected: FAIL — `value of type 'TranslationManager' has no member 'install'`.

- [ ] **Step 3: Write minimal implementation**

Add the error type and method to `TranslationManager.swift`:

```swift
enum TranslationInstallError: Error, Equatable {
    case checksumMismatch
}
```

Inside the class:

```swift
    /// Downloads, verifies the SHA-256 against the manifest, then atomically
    /// moves the file into `directory`. Leaves no partial file on failure.
    func install(_ remote: RemoteTranslation) async throws {
        downloadProgress[remote.id] = 0
        defer { downloadProgress[remote.id] = nil }

        let tempFile = try await downloader.downloadToFile(from: remote.url) { [weak self] fraction in
            Task { @MainActor in self?.downloadProgress[remote.id] = fraction }
        }
        let actual = try sha256(ofFileAt: tempFile)
        guard actual == remote.sha256 else {
            try? FileManager.default.removeItem(at: tempFile)
            throw TranslationInstallError.checksumMismatch
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let dest = directory.appending(path: "\(remote.id).sqlite")
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.moveItem(at: tempFile, to: dest)
        refreshInstalled()
    }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -project bible-reader.xcodeproj -scheme bible-reader -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:bible-readerTests/TranslationManagerTests 2>&1 | tail -20`
Expected: PASS (4 tests total).

- [ ] **Step 5: Commit**

```bash
git add bible-reader/TranslationManager.swift bible-readerTests/TranslationManagerTests.swift
git commit -m "Add checksum-verified atomic translation install"
```

---

## Task 6: TranslationManager.delete (built-in protected)

**Files:**
- Modify: `bible-reader/TranslationManager.swift`
- Test: `bible-readerTests/TranslationManagerTests.swift` (append)

- [ ] **Step 1: Write the failing test**

```swift
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project bible-reader.xcodeproj -scheme bible-reader -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:bible-readerTests/TranslationManagerTests 2>&1 | tail -20`
Expected: FAIL — `has no member 'delete'` and `cannotDeleteBuiltIn`.

- [ ] **Step 3: Write minimal implementation**

Add the case to `TranslationInstallError`:

```swift
enum TranslationInstallError: Error, Equatable {
    case checksumMismatch
    case cannotDeleteBuiltIn
}
```

Add the method:

```swift
    /// Removes a downloaded translation. The built-in `cuv` cannot be deleted.
    func delete(_ id: String) throws {
        guard id != Self.builtInID else { throw TranslationInstallError.cannotDeleteBuiltIn }
        let file = directory.appending(path: "\(id).sqlite")
        if FileManager.default.fileExists(atPath: file.path) {
            try FileManager.default.removeItem(at: file)
        }
        refreshInstalled()
    }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -project bible-reader.xcodeproj -scheme bible-reader -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:bible-readerTests/TranslationManagerTests 2>&1 | tail -20`
Expected: PASS (6 tests total).

- [ ] **Step 5: Commit**

```bash
git add bible-reader/TranslationManager.swift bible-readerTests/TranslationManagerTests.swift
git commit -m "Add translation delete with built-in protection"
```

---

## Task 7: TranslationManager.fetchCatalog — manifest diff

**Files:**
- Modify: `bible-reader/TranslationManager.swift`
- Test: `bible-readerTests/TranslationManagerTests.swift` (append)

- [ ] **Step 1: Write the failing test**

```swift
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project bible-reader.xcodeproj -scheme bible-reader -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:bible-readerTests/TranslationManagerTests 2>&1 | tail -20`
Expected: FAIL — `has no member 'fetchCatalog'`.

- [ ] **Step 3: Write minimal implementation**

```swift
    /// Fetches the hosted manifest and computes `available` = manifest minus
    /// already-installed translations. Errors land in `catalogError`; reading
    /// is never affected because the built-in translation is always present.
    func fetchCatalog() async {
        catalogError = nil
        do {
            let data = try await downloader.data(from: manifestURL)
            let manifest = try TranslationManifest.decode(data)
            let installedIDs = Set(installed.map(\.id))
            available = manifest.translations.filter { !installedIDs.contains($0.id) }
        } catch TranslationManifestError.unsupportedSchema {
            catalogError = "译本目录需要更新 App 版本。"
            available = []
        } catch {
            catalogError = "无法获取译本目录:\(error.localizedDescription)"
            available = []
        }
    }
```

> The manifest's friendly names are also useful for already-installed entries.
> Add this helper so `TranslationsView` can show `nameZH` instead of the
> uppercased id once a catalog has been fetched:

```swift
    /// Manifest display name for `id`, if a catalog fetch has provided it.
    private var manifestNames: [String: String] = [:]

    func displayName(for id: String) -> String {
        if id == Self.builtInID { return Self.builtInName }
        return manifestNames[id] ?? id.uppercased()
    }
```

And in `fetchCatalog()`, after decoding `manifest`, record the names:

```swift
            for t in manifest.translations { manifestNames[t.id] = t.nameZH }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -project bible-reader.xcodeproj -scheme bible-reader -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:bible-readerTests/TranslationManagerTests 2>&1 | tail -20`
Expected: PASS (8 tests total).

- [ ] **Step 5: Commit**

```bash
git add bible-reader/TranslationManager.swift bible-readerTests/TranslationManagerTests.swift
git commit -m "Add manifest fetch + installed/available diff"
```

---

## Task 8: ReadingSettings — translation selections

**Files:**
- Modify: `bible-reader/ReadingSettings.swift`
- Test: `bible-readerTests/ReadingSettingsTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import Testing
import Foundation
@testable import bible_reader

struct ReadingSettingsTests {
    private func freshDefaults() -> UserDefaults {
        let suite = "test-\(UUID().uuidString)"
        return UserDefaults(suiteName: suite)!
    }

    @Test func defaultsToBuiltInPrimaryAndNoSecondary() {
        let settings = ReadingSettings(defaults: freshDefaults())
        #expect(settings.primaryTranslationID == "cuv")
        #expect(settings.secondaryTranslationID == nil)
    }

    @Test func persistsSelections() {
        let defaults = freshDefaults()
        let settings = ReadingSettings(defaults: defaults)
        settings.primaryTranslationID = "kjv"
        settings.secondaryTranslationID = "web"
        let reloaded = ReadingSettings(defaults: defaults)
        #expect(reloaded.primaryTranslationID == "kjv")
        #expect(reloaded.secondaryTranslationID == "web")
    }

    @Test func clearingSecondaryPersistsNil() {
        let defaults = freshDefaults()
        let settings = ReadingSettings(defaults: defaults)
        settings.secondaryTranslationID = "web"
        settings.secondaryTranslationID = nil
        let reloaded = ReadingSettings(defaults: defaults)
        #expect(reloaded.secondaryTranslationID == nil)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project bible-reader.xcodeproj -scheme bible-reader -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:bible-readerTests/ReadingSettingsTests 2>&1 | tail -20`
Expected: FAIL — `ReadingSettings` has no `init(defaults:)` / no `primaryTranslationID`.

- [ ] **Step 3: Write minimal implementation**

Replace the body of `ReadingSettings` with an injectable `defaults` store and the new properties:

```swift
/// Observable reading preferences, persisted via UserDefaults.
@Observable
final class ReadingSettings {
    @ObservationIgnored private let defaults: UserDefaults

    var fontSize: Double {
        didSet { defaults.set(fontSize, forKey: "fontSize") }
    }
    var colorScheme: AppColorScheme {
        didSet { defaults.set(colorScheme.rawValue, forKey: "colorScheme") }
    }
    var primaryTranslationID: String {
        didSet { defaults.set(primaryTranslationID, forKey: "primaryTranslationID") }
    }
    var secondaryTranslationID: String? {
        didSet { defaults.set(secondaryTranslationID, forKey: "secondaryTranslationID") }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.double(forKey: "fontSize")
        self.fontSize = stored == 0 ? 18 : stored
        let raw = defaults.string(forKey: "colorScheme") ?? AppColorScheme.system.rawValue
        self.colorScheme = AppColorScheme(rawValue: raw) ?? .system
        self.primaryTranslationID = defaults.string(forKey: "primaryTranslationID") ?? "cuv"
        self.secondaryTranslationID = defaults.string(forKey: "secondaryTranslationID")
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -project bible-reader.xcodeproj -scheme bible-reader -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:bible-readerTests/ReadingSettingsTests 2>&1 | tail -20`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add bible-reader/ReadingSettings.swift bible-readerTests/ReadingSettingsTests.swift
git commit -m "Add persisted primary/secondary translation selections"
```

---

## Task 9: ParallelVerses — join logic

**Files:**
- Create: `bible-reader/ParallelVerses.swift`
- Test: `bible-readerTests/ParallelVersesTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
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
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project bible-reader.xcodeproj -scheme bible-reader -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:bible-readerTests/ParallelVersesTests 2>&1 | tail -20`
Expected: FAIL — `cannot find 'ParallelVerses' / 'ParallelRow' in scope`.

- [ ] **Step 3: Write minimal implementation**

```swift
import Foundation

/// One display row in parallel reading: a verse number, the primary text, and
/// the aligned secondary text (nil when the secondary translation lacks that
/// verse, e.g. versification differences).
struct ParallelRow: Identifiable, Equatable {
    let number: Int
    let primary: String
    let secondary: String?
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
                        secondary: secondary == nil ? nil : secondaryByNumber[verse.number])
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -project bible-reader.xcodeproj -scheme bible-reader -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:bible-readerTests/ParallelVersesTests 2>&1 | tail -20`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add bible-reader/ParallelVerses.swift bible-readerTests/ParallelVersesTests.swift
git commit -m "Add ParallelVerses join logic for CN/EN alignment"
```

---

## Task 10: VerseRow — render secondary line

**Files:**
- Modify: `bible-reader/VerseRow.swift`

- [ ] **Step 1: Add the secondary parameter and rendering**

Add two stored properties after `let hasNote: Bool`:

```swift
    /// Secondary (parallel) translation text for this verse. `nil` while
    /// single-translation; `.some(nil)` is represented by passing `isParallel`
    /// true with `secondaryText == nil` → renders a faint placeholder.
    let secondaryText: String?
    let isParallel: Bool
```

Give them defaults so existing call sites stay valid — add this convenience by declaring them with defaults via a memberwise-friendly initializer is not possible for structs with closures, so instead update **all** call sites (Task 11). For now, place the new fields right after `hasNote` in the property list.

Replace the verse-number/text `Text(...)` expression's enclosing `HStack` content so the secondary line appears beneath. Change the middle of `body` from the single combined `Text` to a vertical stack:

```swift
            VStack(alignment: .leading, spacing: 2) {
                (Text("\(verse.number) ")
                    .font(.system(size: fontSize * 0.7))
                    .foregroundStyle(highlightHex != nil ? Color.black.opacity(0.5) : Color.secondary)
                 + Text(verse.text)
                    .font(.system(size: fontSize))
                    .foregroundStyle(highlightHex != nil ? Color.black : Color.primary))

                if isParallel {
                    Text(secondaryText ?? "—")
                        .font(.system(size: fontSize * 0.92))
                        .italic()
                        .foregroundStyle(highlightHex != nil ? Color.black.opacity(0.75)
                                                              : Color.secondary)
                }
            }
```

(The `if hasNote { Button … }` block stays after this `VStack`, still inside the outer `HStack`.)

- [ ] **Step 2: Verify it builds**

Run: `xcodebuild -project bible-reader.xcodeproj -scheme bible-reader -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -5`
Expected: BUILD will FAIL because `ReadingView` call site lacks the new args — fixed in Task 11. (Do not commit yet; this task and Task 11 land together.)

> Because `VerseRow` and its sole call site (`ReadingView`) change together,
> commit them as one unit at the end of Task 11.

---

## Task 11: ReadingView — load + render parallel

**Files:**
- Modify: `bible-reader/ReadingView.swift`

- [ ] **Step 1: Accept the secondary store**

Add after `let store: BibleStore`:

```swift
    /// Optional parallel translation. When set, each verse shows this
    /// translation's text beneath the primary line.
    var secondaryStore: BibleStore?
```

- [ ] **Step 2: Hold parallel rows + secondary load**

Replace `@State private var verses: [Verse] = []` with:

```swift
    @State private var verses: [Verse] = []
    @State private var rows: [ParallelRow] = []
```

- [ ] **Step 3: Render rows instead of raw verses**

Replace the `ForEach(verses) { verse in VerseRow(...) }` block with:

```swift
                ForEach(rows) { row in
                    VerseRow(
                        verse: Verse(number: row.number, text: row.primary),
                        fontSize: settings.fontSize,
                        highlightHex: highlightHexByVerse[row.number],
                        isBookmarked: bookmarkedVerses.contains(row.number),
                        hasNote: notesByVerse[row.number] != nil,
                        secondaryText: row.secondary,
                        isParallel: secondaryStore != nil,
                        isSelected: selectedVerses.contains(row.number),
                        onTap: { toggleSelection(row.number) },
                        onTapNote: { editingNote = EditingNote(verse: row.number) }
                    )
                }
```

> Note the argument order matches `VerseRow`'s property declaration order:
> `verse, fontSize, highlightHex, isBookmarked, hasNote, secondaryText,
> isParallel, isSelected, onTap, onTapNote`. Keep `VerseRow`'s property list in
> that exact order.

- [ ] **Step 4: Build parallel rows in `load()`**

In `load()`, after `verses = try store.verses(book: book.id, chapter: chapter)`, add:

```swift
            let secondaryVerses = try secondaryStore?.verses(book: book.id, chapter: chapter)
            rows = ParallelVerses.join(primary: verses, secondary: secondaryVerses)
```

- [ ] **Step 5: Verify build + run full test suite**

Run: `xcodebuild test -project bible-reader.xcodeproj -scheme bible-reader -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -15`
Expected: BUILD SUCCEEDED and all tests pass.

- [ ] **Step 6: Commit (VerseRow + ReadingView together)**

```bash
git add bible-reader/VerseRow.swift bible-reader/ReadingView.swift
git commit -m "Render per-verse parallel secondary translation"
```

---

## Task 12: TranslationsView — download manager UI

**Files:**
- Create: `bible-reader/TranslationsView.swift`

- [ ] **Step 1: Write the screen**

```swift
import SwiftUI

/// 译本管理:已安装译本(内置 cuv 不可删)+ 可下载译本(带进度、校验、删除)。
struct TranslationsView: View {
    let manager: TranslationManager

    @State private var installError: String?

    var body: some View {
        List {
            Section("已安装") {
                ForEach(manager.installed) { item in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(manager.displayName(for: item.id))
                            Text(item.id.uppercased())
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if item.isBuiltIn {
                            Text("内置").font(.caption).foregroundStyle(.secondary)
                        } else {
                            Button(role: .destructive) {
                                delete(item.id)
                            } label: { Image(systemName: "trash") }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }

            Section("可下载") {
                if let error = manager.catalogError {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(error).foregroundStyle(.secondary)
                        Button("重试") { Task { await manager.fetchCatalog() } }
                    }
                } else if manager.available.isEmpty {
                    Text("没有更多可下载的译本。").foregroundStyle(.secondary)
                } else {
                    ForEach(manager.available) { remote in
                        downloadRow(remote)
                    }
                }
            }

            if let installError {
                Section { Text(installError).foregroundStyle(.red) }
            }
        }
        .navigationTitle("译本管理")
        .task { await manager.fetchCatalog() }
    }

    @ViewBuilder
    private func downloadRow(_ remote: RemoteTranslation) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(remote.nameZH)
                Text("\(remote.nameEN) · \(byteText(remote.bytes))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if let progress = manager.downloadProgress[remote.id] {
                ProgressView(value: progress).frame(width: 80)
            } else {
                Button("下载") { download(remote) }
                    .buttonStyle(.borderless)
            }
        }
    }

    private func download(_ remote: RemoteTranslation) {
        installError = nil
        Task {
            do {
                try await manager.install(remote)
                await manager.fetchCatalog()
            } catch TranslationInstallError.checksumMismatch {
                installError = "\(remote.nameZH) 下载校验失败,请重试。"
            } catch {
                installError = "下载失败:\(error.localizedDescription)"
            }
        }
    }

    private func delete(_ id: String) {
        do {
            try manager.delete(id)
            Task { await manager.fetchCatalog() }
        } catch {
            installError = "删除失败:\(error.localizedDescription)"
        }
    }

    private func byteText(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}
```

- [ ] **Step 2: Verify it builds**

Run: `xcodebuild -project bible-reader.xcodeproj -scheme bible-reader -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add bible-reader/TranslationsView.swift
git commit -m "Add 译本管理 download-manager screen"
```

---

## Task 13: SettingsView — link to TranslationsView

**Files:**
- Modify: `bible-reader/SettingsView.swift`

- [ ] **Step 1: Add a manager parameter + navigation link**

Replace `SettingsView`:

```swift
import SwiftUI

struct SettingsView: View {
    @Environment(ReadingSettings.self) private var settings
    let translationManager: TranslationManager

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section("字体大小") {
                Slider(value: $settings.fontSize, in: 12...32, step: 1)
                Text("示例经文 \(Int(settings.fontSize))pt")
                    .font(.system(size: settings.fontSize))
            }
            Section("外观") {
                Picker("主题", selection: $settings.colorScheme) {
                    ForEach(AppColorScheme.allCases) { scheme in
                        Text(scheme.label).tag(scheme)
                    }
                }
            }
            Section("译本") {
                NavigationLink("译本管理") {
                    TranslationsView(manager: translationManager)
                }
            }
        }
        .navigationTitle("设置")
    }
}
```

- [ ] **Step 2: Verify build (will fail at ContentView call site — fixed in Task 14)**

Run: `xcodebuild -project bible-reader.xcodeproj -scheme bible-reader -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -5`
Expected: FAIL at `ContentView` (SettingsView now needs `translationManager`). Fixed in Task 14; commit together.

---

## Task 14: ContentView + App wiring

**Files:**
- Modify: `bible-reader/ContentView.swift`
- Modify: `bible-reader/bible_readerApp.swift`

- [ ] **Step 1: App constructs the manager and App Support dir**

In `bible_readerApp.swift`, add a helper and inject the manager. Replace the struct body:

```swift
@main
struct bible_readerApp: App {
    @State private var settings = ReadingSettings()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([LastReadPosition.self, Bookmark.self, Highlight.self, Note.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(settings)
                .preferredColorScheme(settings.colorScheme.colorScheme)
        }
        .modelContainer(sharedModelContainer)
    }
}
```

(No change needed here beyond confirming it matches; the manager is built in `ContentView` where the bundled store already lives.)

- [ ] **Step 2: ContentView owns the manager and derives stores**

Edit `ContentView.swift`. Add state:

```swift
    @State private var translationManager: TranslationManager?
```

Add a constant for the manifest URL near the top of the file (outside the struct):

```swift
/// Hosted catalog of downloadable translations. Points at the committed
/// manifest; the referenced .sqlite assets live on the GitHub Release.
/// TODO(deploy): replace <owner>/<repo> once the repo has a remote + release.
let translationManifestURL = URL(string:
    "https://raw.githubusercontent.com/OWNER/REPO/main/translations/manifest.json")!
```

In `openStore()`, after `store = opened`, build the manager:

```swift
            let support = try FileManager.default.url(
                for: .applicationSupportDirectory, in: .userDomainMask,
                appropriateFor: nil, create: true)
            let dir = support.appending(path: "Translations")
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            translationManager = TranslationManager(
                bundledStore: opened, downloader: URLSessionDownloader(),
                directory: dir, manifestURL: translationManifestURL)
```

- [ ] **Step 3: Derive primary/secondary stores + validate selections**

Add computed helpers inside `ContentView`:

```swift
    /// The active primary store, falling back to the bundled one if the
    /// selected translation was deleted.
    private func primaryStore(_ manager: TranslationManager) -> BibleStore {
        manager.store(for: settings.primaryTranslationID) ?? manager.store(for: "cuv")!
    }

    /// The active secondary store (nil if none selected or it was deleted).
    private func secondaryStore(_ manager: TranslationManager) -> BibleStore? {
        guard let id = settings.secondaryTranslationID, id != settings.primaryTranslationID else { return nil }
        return manager.store(for: id)
    }
```

where `settings` comes from the environment — add at the top of `ContentView`:

```swift
    @Environment(ReadingSettings.self) private var settings
```

- [ ] **Step 4: Pass stores through the reading tab + search + settings**

Change `body` so the tab content uses the manager. Replace the `if let store {` branch contents:

```swift
            if let store, let manager = translationManager {
                let primary = primaryStore(manager)
                TabView(selection: $selectedTab) {
                    readingTab(store: primary, secondary: secondaryStore(manager), manager: manager)
                        .tabItem { Label("阅读", systemImage: "book") }
                        .tag(0)
                    NavigationStack {
                        SearchView(service: SearchService(store: primary), books: books, onOpen: openReference)
                    }
                    .tabItem { Label("搜索", systemImage: "magnifyingglass") }
                    .tag(1)
                    NavigationStack {
                        AnnotationsView(books: books, onOpen: openReference)
                    }
                    .tabItem { Label("我的标注", systemImage: "bookmark") }
                    .tag(2)
                }
            }
```

Update `readingTab` signature and pass-through:

```swift
    @ViewBuilder
    private func readingTab(store: BibleStore, secondary: BibleStore?, manager: TranslationManager) -> some View {
        NavigationStack(path: $path) {
            BookListView(books: books)
                .navigationDestination(for: NavRoute.self) { route in
                    switch route {
                    case let .chapters(book):
                        ChapterListView(store: store, book: book)
                    case let .reading(book, chapter):
                        ReadingView(store: store, secondaryStore: secondary, book: book, chapter: chapter)
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            translationMenu(manager: manager)
                        } label: { Image(systemName: "character.book.closed") }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        NavigationLink { SettingsView(translationManager: manager) } label: {
                            Image(systemName: "textformat.size")
                        }
                    }
                    if let last = positions.first,
                       let book = books.first(where: { $0.id == last.book }) {
                        ToolbarItem(placement: .navigation) {
                            Button("续读") {
                                path.append(NavRoute.reading(book: book, chapter: last.chapter))
                            }
                        }
                    }
                }
        }
    }

    /// Picks the primary translation and toggles an optional parallel secondary.
    @ViewBuilder
    private func translationMenu(manager: TranslationManager) -> some View {
        @Bindable var settings = settings
        Picker("主译本", selection: $settings.primaryTranslationID) {
            ForEach(manager.installed) { item in
                Text(manager.displayName(for: item.id)).tag(item.id)
            }
        }
        Divider()
        Picker("对照译本", selection: Binding(
            get: { settings.secondaryTranslationID ?? "" },
            set: { settings.secondaryTranslationID = $0.isEmpty ? nil : $0 })) {
            Text("无").tag("")
            ForEach(manager.installed.filter { $0.id != settings.primaryTranslationID }) { item in
                Text(manager.displayName(for: item.id)).tag(item.id)
            }
        }
    }
```

- [ ] **Step 5: Build + full test suite**

Run: `xcodebuild test -project bible-reader.xcodeproj -scheme bible-reader -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -15`
Expected: BUILD SUCCEEDED, all tests pass.

- [ ] **Step 6: Commit (ContentView + SettingsView + App)**

```bash
git add bible-reader/ContentView.swift bible-reader/SettingsView.swift bible-reader/bible_readerApp.swift
git commit -m "Wire TranslationManager: switcher, parallel store, 译本管理 link"
```

---

## Task 15: Build tooling — manifest generator + provenance

**Files:**
- Create: `tools/build_manifest.py`
- Create: `tools/test_build_manifest.py`
- Modify: `tools/README.md`

- [ ] **Step 1: Write the failing test**

`tools/test_build_manifest.py`:

```python
import hashlib
import json
import os
import tempfile
import unittest

import build_manifest


class BuildManifestTests(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.mkdtemp()
        self.kjv = os.path.join(self.dir, "kjv.sqlite")
        with open(self.kjv, "wb") as f:
            f.write(b"fake sqlite bytes")

    def test_entry_has_sha256_and_size(self):
        entry = build_manifest.entry_for(
            self.kjv, id="kjv", name_zh="英王钦定本", name_en="King James Version",
            abbrev="KJV", language="en", base_url="https://e.com/dl")
        expected = hashlib.sha256(b"fake sqlite bytes").hexdigest()
        self.assertEqual(entry["sha256"], expected)
        self.assertEqual(entry["bytes"], len(b"fake sqlite bytes"))
        self.assertEqual(entry["url"], "https://e.com/dl/kjv.sqlite")
        self.assertEqual(entry["id"], "kjv")

    def test_manifest_has_schema_version(self):
        manifest = build_manifest.build([
            (self.kjv, "kjv", "英王钦定本", "King James Version", "KJV", "en"),
        ], base_url="https://e.com/dl")
        self.assertEqual(manifest["schemaVersion"], 1)
        self.assertEqual(len(manifest["translations"]), 1)
        # round-trips as JSON
        json.dumps(manifest)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd tools && python3 -m unittest test_build_manifest -v 2>&1 | tail -15`
Expected: FAIL — `ModuleNotFoundError: No module named 'build_manifest'`.

- [ ] **Step 3: Write minimal implementation**

`tools/build_manifest.py`:

```python
"""Generate manifest.json for downloadable Bible translations.

Each translation is a self-contained .sqlite (built by build_bible_db.py).
This computes sha256 + byte size per file and emits the manifest the app
fetches. Files are hosted as GitHub Release assets; base_url is that release's
download prefix.
"""
import hashlib
import json
import os
import sys

SCHEMA_VERSION = 1


def entry_for(path, *, id, name_zh, name_en, abbrev, language, base_url):
    data = open(path, "rb").read()
    return {
        "id": id,
        "nameZH": name_zh,
        "nameEN": name_en,
        "abbrev": abbrev,
        "language": language,
        "url": f"{base_url.rstrip('/')}/{os.path.basename(path)}",
        "bytes": len(data),
        "sha256": hashlib.sha256(data).hexdigest(),
    }


def build(specs, *, base_url):
    """specs: list of (path, id, name_zh, name_en, abbrev, language)."""
    return {
        "schemaVersion": SCHEMA_VERSION,
        "translations": [
            entry_for(path, id=i, name_zh=zh, name_en=en, abbrev=ab,
                      language=lang, base_url=base_url)
            for (path, i, zh, en, ab, lang) in specs
        ],
    }


# Catalog for Phase 4: KJV + WEB. Paths are relative to this tools/ dir.
CATALOG = [
    ("kjv.sqlite", "kjv", "英王钦定本", "King James Version", "KJV", "en"),
    ("web.sqlite", "web", "世界英文圣经", "World English Bible", "WEB", "en"),
]


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python3 build_manifest.py <base_url> <out_manifest.json>")
        sys.exit(1)
    base_url, out = sys.argv[1], sys.argv[2]
    manifest = build(CATALOG, base_url=base_url)
    with open(out, "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)
    print(f"Wrote {out} ({len(manifest['translations'])} translations)")
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd tools && python3 -m unittest test_build_manifest -v 2>&1 | tail -15`
Expected: PASS (2 tests).

- [ ] **Step 5: Document provenance + build commands in README**

Append to `tools/README.md`:

```markdown
## Downloadable translations (Phase 4)

Build standalone per-translation databases with the same tool, then generate
the manifest:

    # Sources from getbible.net v2 (public domain): kjv, web
    curl -sL -o raw_kjv.json https://api.getbible.net/v2/kjv.json
    python3 convert_source.py raw_kjv.json source_kjv.json   # if conversion needed
    python3 build_bible_db.py source_kjv.json kjv.sqlite kjv
    python3 build_bible_db.py source_web.json web.sqlite web

    # base_url = the GitHub Release asset download prefix
    python3 build_manifest.py \
      https://github.com/OWNER/REPO/releases/download/translations-v1\
      ../translations/manifest.json

### Provenance & license
- **KJV** — King James Version (1611). Public domain. Source: getbible.net v2 `kjv`.
- **WEB** — World English Bible. Public domain (explicitly released). Source: getbible.net v2 `web`.

### Deploy
1. Create a GitHub Release tagged `translations-v1`; upload `kjv.sqlite`, `web.sqlite` as assets.
2. Commit `translations/manifest.json` (served via raw.githubusercontent.com).
3. Set `translationManifestURL` in `ContentView.swift` to that raw URL.
```

- [ ] **Step 6: Commit**

```bash
git add tools/build_manifest.py tools/test_build_manifest.py tools/README.md
git commit -m "Add manifest generator + KJV/WEB provenance docs"
```

---

## Task 16: Final verification + Phase 4 merge

**Files:** none (verification only)

- [ ] **Step 1: Full test suite green**

Run: `xcodebuild test -project bible-reader.xcodeproj -scheme bible-reader -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -20`
Expected: `** TEST SUCCEEDED **`, all suites pass.

- [ ] **Step 2: Python tooling green**

Run: `cd tools && python3 -m unittest discover -v 2>&1 | tail -10`
Expected: all tests OK.

- [ ] **Step 3: Manual smoke (simulator)**

Launch the app; confirm: translation menu shows 简体和合本; 设置 → 译本管理 lists 可下载 (KJV/WEB) — with no real release yet, expect the catalog error + 重试 (acceptable; reading still works). Single-translation reading unchanged.

- [ ] **Step 4: Merge to main (matches established `--no-ff` pattern)**

```bash
git checkout main
git merge --no-ff phase-4-multi-translation -m "Merge Phase 4: 多译本 (translation switcher, CN/EN parallel, download subsystem)"
```

---

## Self-Review notes

- **Spec coverage:** switcher (Task 14 menu), CN/EN parallel (Tasks 9–11), download subsystem (Tasks 1–7, 12), hosting/manifest tooling (Task 15), versification `—` (Task 9/10), deleted-selection fallback (Task 14 Step 3), built-in undeletable (Task 6), offline degradation (Task 7/12), search follows primary (Task 14 Step 4). All covered.
- **Deferred deployment:** real GitHub release + manifest URL are Task 15 docs + the `OWNER/REPO` TODO in Task 14; subsystem is fully testable via the stub `Downloader` without them (per spec §9).
- **Type consistency:** `BibleStore.file(at:translationID:)`, `TranslationManager.{installed,available,store(for:),refreshInstalled,install,delete,fetchCatalog,displayName(for:),downloadProgress,catalogError}`, `RemoteTranslation` fields, `ParallelRow{number,primary,secondary}`, and `VerseRow` arg order are used identically across tasks.
- **Worktree:** create a `phase-4-multi-translation` branch (or worktree) before Task 1; Task 16 merges it.
