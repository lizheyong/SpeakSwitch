import Foundation
import Testing
import VoiceSwitchCore
@testable import VoiceSwitch

@Suite @MainActor struct UsageStoreTests {
    @Test func independentFilePersistsCompletedAndUnfinishedStarts() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("usage.json")
        let provider = Provider.catalog[0]
        let start = Date(timeIntervalSince1970: 1_792_051_200)
        let store = UsageStore(fileURL: file)
        store.recordPulse(provider: provider, mode: .dictation, at: start)
        store.recordPulse(provider: provider, mode: .dictation, at: start.addingTimeInterval(20))
        store.recordPulse(provider: provider, mode: .translation, at: start.addingTimeInterval(100))
        store.finishSaving()

        let reopened = UsageStore(fileURL: file)
        #expect(reopened.history.sessions.count == 2)
        #expect(reopened.history.sessions.first?.duration == 20)
        #expect(reopened.history.sessions.last?.endedAt == nil)
        #expect(reopened.history.activeSessionID == nil)
        reopened.recordPulse(provider: provider, mode: .dictation, at: start.addingTimeInterval(3_600))
        #expect(reopened.history.sessions.count == 3)
        reopened.finishSaving()
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path) == ["usage.json"])
    }

    @Test func failedSaveStillPairsInMemory() throws {
        let occupiedPath = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data("existing file".utf8).write(to: occupiedPath)
        defer { try? FileManager.default.removeItem(at: occupiedPath) }
        let store = UsageStore(fileURL: occupiedPath.appendingPathComponent("usage.json"))
        let start = Date()
        store.recordPulse(provider: Provider.catalog[0], mode: .dictation, at: start)
        store.recordPulse(provider: Provider.catalog[0], mode: .dictation, at: start.addingTimeInterval(12))
        store.finishSaving()

        #expect(store.history.sessions.count == 1)
        #expect(store.history.sessions.first?.duration == 12)
        #expect(try String(contentsOf: occupiedPath, encoding: .utf8) == "existing file")
    }
}
