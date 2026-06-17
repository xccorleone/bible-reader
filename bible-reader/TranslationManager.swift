import Foundation
import Observation

enum TranslationInstallError: Error, Equatable {
    case checksumMismatch
}

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
