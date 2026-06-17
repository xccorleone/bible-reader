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
