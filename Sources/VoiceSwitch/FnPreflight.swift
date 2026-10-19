import AppKit
import VoiceSwitchCore

struct FnCheck: Identifiable, Equatable {
    let id: String
    let name: String
    let applicationURL: URL?
    let version: String
    let instructions: String
    let snapshot: ShortcutSnapshot?
    let manuallyReviewed: Bool

    var hasConflict: Bool { snapshot?.fnBindings.isEmpty == false }
    var needsReview: Bool { hasConflict || (snapshot == nil && !manuallyReviewed) }
    var status: String {
        if hasConflict { return "检测到 Fn 绑定" }
        if snapshot != nil { return "已读取，未发现 Fn 绑定" }
        return manuallyReviewed ? "已手动确认" : "待检查"
    }
    var reviewKey: String { "fnReview.\(id).\(applicationURL?.path ?? "system").\(version)" }
}

enum FnPreflight {
    static func scan(providers: [Provider], paths: [String: URL], defaults: UserDefaults = .standard,
                     home: URL = FileManager.default.homeDirectoryForCurrentUser) -> [FnCheck] {
        var checks: [FnCheck] = []
        func add(id: String, name: String, url: URL?, instructions: String, snapshot: ShortcutSnapshot? = nil) {
            let version = url.flatMap { Bundle(url: $0)?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String }
                ?? ProcessInfo.processInfo.operatingSystemVersionString
            let check = FnCheck(id: id, name: name, applicationURL: url, version: version,
                                instructions: instructions, snapshot: snapshot, manuallyReviewed: false)
            checks.append(FnCheck(id: id, name: name, applicationURL: url, version: version,
                                  instructions: instructions, snapshot: snapshot, manuallyReviewed: defaults.bool(forKey: check.reviewKey)))
        }
        add(id: "system", name: "macOS 键盘与听写", url: nil,
            instructions: "系统设置 → 键盘：将“按下 🌐 键时”设为“不执行任何操作”；在“听写”中将快捷键改为不含 Fn 的组合。")
        for provider in providers {
            guard let url = paths[provider.id] else { continue }
            var snapshot: ShortcutSnapshot?
            var instructions = "打开快捷键设置，检查语音输入、翻译、指令和附加快捷键，全部改为不含 Fn 的组合。"
            let support = home.appendingPathComponent("Library/Application Support")
            if provider.bundleIDs.contains("now.typeless.desktop") {
                snapshot = try? ShortcutSnapshot.typeless(Data(contentsOf: support.appendingPathComponent("Typeless/app-settings.json")))
                instructions = "设置 → Keyboard shortcuts：语音建议 ⌃⌥1，翻译 ⌃⌘1，随便问 ⌥⌘1。检查每个动作的全部快捷键。"
            } else if provider.bundleIDs.contains("com.bageshuo") {
                snapshot = try? ShortcutSnapshot.bageshuo(Data(contentsOf: support.appendingPathComponent("com.bageshuo/bageshuo-store.json")))
                instructions = "设置 → 快捷键：语音润色建议 ⌃⌥7，翻译 ⌃⌘7；随便问也需要移除 Fn + 空格，可改为 ⌥⌘7。"
            } else if provider.id == "chatterfly" {
                instructions = "设置 → 语音输入：语音建议 ⌃⌥⇧；指令模式的双击 Fn 改为 ⌥⇧⌘。请检查两个入口。"
            } else if provider.id == "wetype" {
                instructions = "设置 → 语音输入：将“启动语音输入”改为 ⌃⌥2，同时检查“按住说话”是否占用 Fn。"
            }
            add(id: provider.id, name: provider.name, url: url, instructions: instructions, snapshot: snapshot)
        }
        for (id, name) in [("com.electron.lark", "飞书"), ("com.larksuite.lark", "Lark")] {
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { continue }
            add(id: id, name: name, url: url,
                instructions: "打开应用后按 ⌘, → 设置 → 效率 → 语音输入 → 立即设置。将长按 Fn 改为不含 Fn 的组合，例如 ⌃⌥9，并避开其他应用的快捷键。返回设置页确认已保存。内置语音仍可用新快捷键启动。")
        }
        return checks
    }
}
