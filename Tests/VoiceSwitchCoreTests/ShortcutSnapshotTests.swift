import Foundation
import Testing
@testable import VoiceSwitchCore

@Suite struct ShortcutSnapshotTests {
    @Test func findsFnInSecondaryBindingsAndOtherActions() throws {
        let data = Data(#"{"featureShortcutBindings":{"dictationMode":["LeftCtrl+LeftOption+1","Fn"],"translationMode":["LeftCmd+LeftCtrl+1"],"askAnythingMode":["Fn+Space"],"futureAction":["Shift+Fn"]},"unrelated":"ignored"}"#.utf8)
        let result = try ShortcutSnapshot.typeless(data)
        #expect(result.fnBindings.count == 3)
        #expect(result.dictation == Shortcut(keyCode: 18, key: "1", command: false))
        #expect(result.translation == Shortcut(keyCode: 18, key: "1", option: false))
    }

    @Test func bagePluralBindingsOverrideLegacyFields() throws {
        let data = Data(#"{"settings":{"polishHotkey":"Fn","polishHotkeys":["Control+Option+7"],"translateHotkey":"Command+Control+7","askHotkey":"Fn+Space","askHotkeys":[]},"history":[{"text":"private"}]}"#.utf8)
        let result = try ShortcutSnapshot.bageshuo(data)
        #expect(result.fnBindings.isEmpty)
        #expect(result.dictation == Shortcut(keyCode: 26, key: "7", command: false))
        #expect(result.translation == Shortcut(keyCode: 26, key: "7", option: false))
        #expect(result.bindings.last?.keys == [])
    }

    @Test func bageAskStillConflictsAfterDictationWasConfigured() throws {
        let data = Data(#"{"settings":{"polishHotkeys":["Control+Option+7"],"translateHotkeys":["Command+Control+7"],"askHotkeys":["Fn+Space"]}}"#.utf8)
        let result = try ShortcutSnapshot.bageshuo(data)
        #expect(result.fnBindings == [.init("随便问", ["Fn+Space"])])
    }

    @Test func unknownFileFormatsRemainUnknown() {
        #expect(throws: (any Error).self) { try ShortcutSnapshot.typeless(Data(#"{"featureShortcutBindings":{"newFormat":[]}}"#.utf8)) }
        #expect(throws: (any Error).self) { try ShortcutSnapshot.bageshuo(Data(#"{"settings":{}}"#.utf8)) }
        #expect(throws: (any Error).self) { try ShortcutSnapshot.typeless(Data("not json".utf8)) }
    }

    @Test func unsupportedPhysicalCombinationsAreNotImported() {
        for value in ["Fn", "Fn+Space", "RightCtrl+Option+1", "Control+Mouse1", "Control+1+2", "", "1"] {
            #expect(ShortcutSnapshot.parse(value) == nil)
        }
        #expect(ShortcutSnapshot.parse("Control+Option+Shift") == Shortcut(keyCode: .max, key: "", shift: true, command: false))
    }
}
