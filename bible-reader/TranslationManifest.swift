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
