import AppKit
import SwiftUI
import UniformTypeIdentifiers
import VoiceSwitchCore

@MainActor
final class VocabularyStore: ObservableObject {
    @Published private(set) var entries: [VocabularyEntry] = []
    @Published var message: String?
    private let fileURL: URL
    private var unreadableFileBackup: URL?
    var count: Int { entries.count }

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Voice Switch/vocabulary.json")
        if FileManager.default.fileExists(atPath: self.fileURL.path) {
            do { entries = try JSONDecoder().decode([VocabularyEntry].self, from: Data(contentsOf: self.fileURL)) }
            catch {
                unreadableFileBackup = self.fileURL.deletingLastPathComponent()
                    .appendingPathComponent("vocabulary-recovery-\(UUID().uuidString).json")
                message = "词库读取失败：\(error.localizedDescription)。下次保存时会先保留原文件副本。"
            }
        }
    }

    @discardableResult
    func add(term: String, note: String) -> Bool {
        let term = term.trimmingCharacters(in: .whitespacesAndNewlines).precomposedStringWithCanonicalMapping
        guard !term.isEmpty else { message = "输入一个要让语音应用记住的词。"; return false }
        guard !entries.contains(where: { $0.term == term }) else { message = "这个词已经在共享词库中。"; return false }
        return save(entries + [.init(term: term, note: note.trimmingCharacters(in: .whitespacesAndNewlines))], message: "已添加「\(term)」。准备导入后，可在语音应用中更新词库。")
    }

    @discardableResult
    func update(_ entry: VocabularyEntry) -> Bool {
        var updated = entry
        updated.term = updated.term.trimmingCharacters(in: .whitespacesAndNewlines).precomposedStringWithCanonicalMapping
        guard !updated.term.isEmpty else { message = "词条不能为空。"; return false }
        guard !entries.contains(where: { $0.id != entry.id && $0.term == updated.term }) else { message = "这个词已经存在，请保留一份。"; return false }
        return save(entries.map { $0.id == entry.id ? updated : $0 }, message: "已更新「\(updated.term)」。")
    }

    @discardableResult
    func remove(_ entry: VocabularyEntry) -> Bool {
        save(entries.filter { $0.id != entry.id }, message: "已从共享词库移除「\(entry.term)」。原应用中的词库不会自动删除。")
    }

    @discardableResult
    func restore(_ entry: VocabularyEntry) -> Bool {
        save(VocabularyCodec.merge([entry], into: entries), message: "已恢复「\(entry.term)」。")
    }

    func importFile() {
        let panel = NSOpenPanel()
        panel.title = "导入共享词库"
        panel.prompt = "合并词条"
        panel.allowedContentTypes = [.plainText, .commaSeparatedText, .json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url)
            let imported: [VocabularyEntry]
            switch url.pathExtension.lowercased() {
            case "json": imported = try JSONDecoder().decode([VocabularyEntry].self, from: data)
            case "csv": imported = try VocabularyCodec.importCSV(String(contentsOf: url, encoding: .utf8))
            default: imported = VocabularyCodec.importText(try String(contentsOf: url, encoding: .utf8))
            }
            let merged = VocabularyCodec.merge(imported, into: entries)
            let added = merged.count - entries.count
            _ = save(merged, message: "已合并 \(added) 个新词；重复词保留本机已有内容。现有 \(merged.count) 个词条。")
        } catch { message = "未导入词表：\(error.localizedDescription)" }
    }

    func exportPlainText() {
        export(data: Data(VocabularyCodec.exportText(entries).utf8), name: "SpeakSwitch-词表.txt", type: .plainText)
    }

    func exportCSV() {
        export(data: Data(VocabularyCodec.exportCSV(entries).utf8), name: "SpeakSwitch-词表.csv", type: .commaSeparatedText)
    }

    func exportBackup() {
        do { export(data: try encoded(entries), name: "SpeakSwitch-词库备份.json", type: .json) }
        catch { message = "无法备份词库：\(error.localizedDescription)" }
    }

    func revealFile() {
        if !FileManager.default.fileExists(atPath: fileURL.path) { _ = save(entries, message: "词库保存在本机。") }
        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
    }

    func prepareImport(for provider: Provider) {
        let exportURL = fileURL.deletingLastPathComponent().appendingPathComponent("Exports/\(provider.id)-dictionary.csv")
        do {
            try FileManager.default.createDirectory(at: exportURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(VocabularyCodec.exportCSV(entries).utf8).write(to: exportURL, options: .atomic)
            NSWorkspace.shared.activateFileViewerSelecting([exportURL])
            let settingsID = provider.settingsBundleID ?? provider.bundleIDs.first
            if let settingsID, let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: settingsID) {
                NSWorkspace.shared.openApplication(at: app, configuration: .init()) { _, _ in }
            }
            message = "已准备 \(entries.count) 个词：\(exportURL.lastPathComponent)。在 \(provider.name) 的词库中选择「导入 CSV」并确认预览。备注仅保存在声选。"
        } catch { message = "无法准备词表：\(error.localizedDescription)" }
    }

    private func export(data: Data, name: String, type: UTType) {
        let panel = NSSavePanel()
        panel.title = "导出共享词库"
        panel.nameFieldStringValue = name
        panel.allowedContentTypes = [type]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try data.write(to: url, options: .atomic)
            message = "已导出 \(entries.count) 个词条到 \(url.lastPathComponent)。"
        } catch { message = "导出失败：\(error.localizedDescription)" }
    }

    @discardableResult
    private func save(_ updated: [VocabularyEntry], message: String) -> Bool {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            if let backup = unreadableFileBackup {
                try FileManager.default.copyItem(at: fileURL, to: backup)
                unreadableFileBackup = nil
            }
            try encoded(updated).write(to: fileURL, options: .atomic)
            entries = updated
            self.message = message
            return true
        } catch { self.message = "词库保存失败：\(error.localizedDescription)"; return false }
    }

    private func encoded(_ entries: [VocabularyEntry]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(entries)
    }
}
