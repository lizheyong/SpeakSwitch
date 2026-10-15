import Testing
import Foundation
@testable import VoiceSwitchCore

@Suite struct ProviderTests {
    @Test func defaultDictationBindingsDoNotOverlap() {
        for (index, provider) in Provider.catalog.enumerated() {
            for other in Provider.catalog.dropFirst(index + 1) {
                #expect(!provider.shortcut.conflicts(with: other.shortcut))
            }
            #expect(!provider.shortcut.conflicts(with: Shortcut(keyCode: 49, key: "Space")))
        }
    }

    @Test func modifierOnlyPrefixWouldTriggerTwoProviders() {
        let modifierOnly = Shortcut(keyCode: .max, key: "")
        let keyChord = Shortcut(keyCode: 18, key: "1")
        #expect(modifierOnly.conflicts(with: keyChord))
        #expect(keyChord.conflicts(with: modifierOnly))
    }

    @Test func keyIdentityDoesNotDependOnDisplayLabel() {
        #expect(Shortcut(keyCode: 49, key: "空格").conflicts(with: Shortcut(keyCode: 49, key: "Space")))
    }

    @Test func providerConfigurationRoundTripsTranslationAndNotes() throws {
        var provider = Provider.catalog[0]
        provider.translationShortcut = .init(keyCode: 18, key: "1", option: false, shift: true)
        provider.note = "本月余量在原应用查看"
        let decoded = try JSONDecoder().decode(Provider.self, from: JSONEncoder().encode(provider))
        #expect(decoded == provider)
    }
}
