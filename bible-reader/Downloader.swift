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
