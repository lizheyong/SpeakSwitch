import CoreGraphics
import Testing
@testable import VoiceSwitch

@Suite @MainActor struct ShortcutDiagnosticsTests {
    private let tag: Int64 = 0x4F4E45464E

    @Test func unrelatedKeyboardEventsAreExcluded() {
        let event = CGEvent(keyboardEventSource: nil, virtualKey: 18, keyDown: true)!
        event.setIntegerValueField(.eventSourceUserData, value: 42)
        #expect(ShortcutDiagnostics.eventLine(phase: "session-head", event: event, eventTag: tag, elapsedMilliseconds: 0) == nil)
    }

    @Test func taggedEventRecordsDeliveryMetadataWithoutText() {
        let event = CGEvent(keyboardEventSource: CGEventSource(stateID: .privateState), virtualKey: 18, keyDown: true)!
        event.flags = [.maskControl, .maskAlternate]
        event.timestamp = 123456
        event.setIntegerValueField(.eventSourceUserData, value: tag)
        event.setIntegerValueField(.eventSourceUnixProcessID, value: 321)
        let text: [UniChar] = Array("private dictation text".utf16)
        event.keyboardSetUnicodeString(stringLength: text.count, unicodeString: text)

        let line = ShortcutDiagnostics.eventLine(phase: "session-head", event: event, eventTag: tag, elapsedMilliseconds: 12.5)
        #expect(line?.contains("12.500ms phase=session-head type=10 keyCode=18 flags=0xc0000 sourcePID=321") == true)
        #expect(line?.contains("sourceStateID=") == true)
        #expect(line?.hasSuffix("timestamp=123456") == true)
        #expect(line?.contains("private dictation text") == false)
    }
}
