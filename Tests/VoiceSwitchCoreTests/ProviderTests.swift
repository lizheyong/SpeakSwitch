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

    @Test func typelessSuggestionsUseThreeKeysWithoutConflictingWithOtherBindings() throws {
        let typeless = try #require(Provider.catalog.first { $0.id == "typeless" })
        let dictation = typeless.shortcut
        let translation = typeless.suggestedTranslationShortcut
        #expect(dictation == Shortcut(keyCode: 18, key: "1", command: false))
        #expect(translation == Shortcut(keyCode: 18, key: "1", option: false))
        #expect(!dictation.conflicts(with: translation))

        for binding in [dictation, translation] {
            let modifiers = [binding.control, binding.option, binding.shift, binding.command].filter { $0 }.count
            #expect(modifiers + (binding.isModifierOnly ? 0 : 1) == 3)
            #expect(!binding.conflicts(with: Shortcut(keyCode: 49, key: "Space")))
            for other in Provider.catalog where other.id != typeless.id {
                #expect(!binding.conflicts(with: other.shortcut))
                #expect(!binding.conflicts(with: other.suggestedTranslationShortcut))
            }
        }
    }

    @Test func keyIdentityDoesNotDependOnDisplayLabel() {
        #expect(Shortcut(keyCode: 49, key: "空格").conflicts(with: Shortcut(keyCode: 49, key: "Space")))
    }

    @Test func providerConfigurationRoundTripsTranslationAndNotes() throws {
        var provider = Provider.catalog[0]
        provider.translationShortcut = .init(keyCode: 18, key: "1", option: false, shift: true)
        provider.note = "本月余量在原应用查看"
        provider.delivery = .session
        let decoded = try JSONDecoder().decode(Provider.self, from: JSONEncoder().encode(provider))
        #expect(decoded == provider)
    }

    @Test func existingConfigurationUsesProviderDeliveryWithoutChangingShortcuts() throws {
        let original = Provider.catalog[0]
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        json.removeValue(forKey: "delivery")
        let restored = try JSONDecoder().decode(Provider.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(restored.shortcut == original.shortcut)
        #expect(restored.shortcutDelivery == .session)
        #expect(Provider.catalog.first { $0.id == "chatterfly" }?.shortcutDelivery == .hid)

        var override = restored
        override.delivery = .hid
        #expect(override.shortcutDelivery == .hid)
    }
}
