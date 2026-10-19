import Foundation
import Testing
@testable import VoiceSwitch

@Suite @MainActor struct CycleConfigurationTests {
    @Test func exclusionsSurviveSavingAndOlderConfigurationsStayReadable() throws {
        let json = Data(#"{"providers":[],"hotkeyEnabled":true,"isEnabled":true,"selectedID":"typeless"}"#.utf8)
        var configuration = try JSONDecoder().decode(AppStore.Configuration.self, from: json)
        #expect(configuration.excludedFromCycle == nil)
        configuration.excludedFromCycle = ["bageshuo"]
        let reopened = try JSONDecoder().decode(AppStore.Configuration.self, from: JSONEncoder().encode(configuration))
        #expect(reopened.excludedFromCycle == ["bageshuo"])
        #expect(reopened.selectedID == "typeless")
        #expect(reopened.isEnabled == true)
    }
}
