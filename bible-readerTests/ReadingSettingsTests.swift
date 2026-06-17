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
