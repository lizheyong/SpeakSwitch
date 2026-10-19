import Foundation
import Testing
@testable import VoiceSwitchCore

@Suite struct ProviderCycleTests {
    private var providers: [Provider] {
        ["typeless", "chatterfly", "wetype", "bageshuo"].map { id in
            var provider = Provider.catalog.first { $0.id == id }!
            provider.isConfigured = true
            return provider
        }
    }

    @Test func stoppedProviderIsSkippedOnWraparound() {
        let running: Set<String> = ["typeless", "chatterfly", "wetype"]
        #expect(ProviderCycle.next(in: providers, currentID: "wetype", runningIDs: running, excludedIDs: [])?.id == "typeless")
    }

    @Test func excludedProviderIsSkippedEvenWhenRunning() {
        let running = Set(providers.map(\.id))
        #expect(ProviderCycle.next(in: providers, currentID: "wetype", runningIDs: running, excludedIDs: ["bageshuo"])?.id == "typeless")
    }

    @Test func stoppedOrExcludedCurrentProviderContinuesInCatalogOrder() {
        #expect(ProviderCycle.next(in: providers, currentID: "chatterfly", runningIDs: ["typeless", "wetype"], excludedIDs: [])?.id == "wetype")
        #expect(ProviderCycle.next(in: providers, currentID: "chatterfly", runningIDs: Set(providers.map(\.id)), excludedIDs: ["chatterfly"])?.id == "wetype")
    }

    @Test func noEligibleProviderDoesNotProduceLaunchTarget() {
        #expect(ProviderCycle.next(in: providers, currentID: "typeless", runningIDs: [], excludedIDs: []) == nil)
        #expect(ProviderCycle.next(in: providers, currentID: "typeless", runningIDs: ["typeless"], excludedIDs: ["typeless"]) == nil)
        var unconfigured = providers
        unconfigured[0].isConfigured = false
        #expect(ProviderCycle.next(in: unconfigured, currentID: nil, runningIDs: ["typeless"], excludedIDs: []) == nil)
    }

    @Test func singleRunningProviderRemainsSelectedAndNewlyStartedProviderJoins() {
        #expect(ProviderCycle.next(in: providers, currentID: "typeless", runningIDs: ["typeless"], excludedIDs: [])?.id == "typeless")
        #expect(ProviderCycle.next(in: providers, currentID: "typeless", runningIDs: ["typeless", "chatterfly"], excludedIDs: [])?.id == "chatterfly")
    }

}
