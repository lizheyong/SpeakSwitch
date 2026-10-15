import Foundation
import SwiftUI
import VoiceSwitchCore

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var history = UsageHistory()
    @Published private(set) var message: String?
    private let fileURL: URL
    private let saveQueue = DispatchQueue(label: "VoiceSwitch.usage-save")
    private var canSave = true

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Voice Switch/usage.json")
        guard FileManager.default.fileExists(atPath: self.fileURL.path) else { return }
        do {
            let sessions = try JSONDecoder().decode([UsageSession].self, from: Data(contentsOf: self.fileURL))
            history = UsageHistory(sessions: sessions)
        } catch {
            canSave = false
            message = "使用统计读取失败：\(error.localizedDescription)。本次统计暂不保存，原文件保留。"
        }
    }

    func recordPulse(provider: Provider, mode: UsageMode, at date: Date = Date()) {
        history.pulse(provider: UsageProvider(provider), mode: mode, at: date)
        persist()
    }

    func interrupt() {
        // The open record is already saved without an end time. Only the
        // in-memory pairing is cleared; it remains an unfinished start.
        history.interrupt()
    }

    func finishSaving() {
        saveQueue.sync {}
    }

    private func persist() {
        guard canSave else { return }
        let sessions = history.sessions
        let fileURL = fileURL
        saveQueue.async { [weak self] in
            let errorMessage: String?
            do {
                try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                try encoder.encode(sessions).write(to: fileURL, options: .atomic)
                errorMessage = nil
            } catch {
                errorMessage = "使用统计保存失败：\(error.localizedDescription)。输入法仍可正常使用，本次记录暂保留在内存中。"
            }
            DispatchQueue.main.async { self?.message = errorMessage }
        }
    }
}
