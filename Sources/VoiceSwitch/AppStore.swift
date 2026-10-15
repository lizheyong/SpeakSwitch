import AppKit
import ApplicationServices
import ServiceManagement
import SwiftUI
import VoiceSwitchCore

@MainActor
final class AppStore: ObservableObject {
    @Published var providers: [Provider] = Provider.catalog
    @Published var selectedID: String?
    @Published var isEnabled = false
    @Published var isListening = false
    @Published var hasAccessibility = false
    @Published var hasInputMonitoring = false
    @Published var isPressing = false
    @Published var message: String?
    @Published var launchAtLogin = false
    @Published var hotkeyEnabled = true
    @Published private var installedPaths: [String: URL] = [:]
    @Published private var runningBundleIDs: Set<String> = []
    var onHotkeyChanged: ((Bool) -> Void)?
    private let router = FnRouter()
    private var refreshTimer: Timer?
    private let configurationURL: URL
    private var setupDepth = 0
    private var wantsEnabled = false

    struct Configuration: Codable {
        var providers: [Provider]
        var selectedID: String?
        var hotkeyEnabled: Bool
        var isEnabled: Bool?
    }

    var selectedProvider: Provider? { providers.first { $0.id == selectedID } }
    var configuredProviders: [Provider] { providers.filter { $0.isConfigured && isInstalled($0) } }

    init(configurationURL: URL? = nil) {
        self.configurationURL = configurationURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Voice Switch/configuration.json")
        load()
        router.onPressChanged = { [weak self] pressing in self?.isPressing = pressing }
        router.onFailure = { [weak self] error in
            self?.isEnabled = false
            self?.isListening = false
            self?.message = error
        }
        router.onUnavailableTranslation = { [weak self] in
            self?.message = "当前输入法尚未接入翻译。请在接入设置中指定它的翻译快捷键。"
        }
        refresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        // A saved configuration can resume only after the user has completed setup.
        if wantsEnabled && selectedProvider?.isConfigured == true && hasAccessibility && hasInputMonitoring {
            setEnabled(true)
        }
    }

    func isInstalled(_ provider: Provider) -> Bool { installedPaths[provider.id] != nil }
    func isRunning(_ provider: Provider) -> Bool {
        let identifiers = provider.bundleIDs + [installedPaths[provider.id].flatMap { Bundle(url: $0)?.bundleIdentifier }].compactMap { $0 }
        return identifiers.contains { runningBundleIDs.contains($0) }
    }

    func refresh() {
        let accessibility = AXIsProcessTrusted()
        let inputMonitoring = CGPreflightListenEventAccess()
        let loginEnabled = SMAppService.mainApp.status == .enabled
        let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        let paths = Dictionary(uniqueKeysWithValues: providers.compactMap { provider in
            applicationURL(for: provider).map { (provider.id, $0) }
        })
        if hasAccessibility != accessibility { hasAccessibility = accessibility }
        if hasInputMonitoring != inputMonitoring { hasInputMonitoring = inputMonitoring }
        if launchAtLogin != loginEnabled { launchAtLogin = loginEnabled }
        if runningBundleIDs != running { runningBundleIDs = running }
        if installedPaths != paths { installedPaths = paths }
        if isEnabled && (!hasAccessibility || !hasInputMonitoring) {
            setEnabled(false)
            message = "需要辅助功能与输入监控权限，才能把 Fn 交给当前输入法。授权后点击开启。"
        }
        if isEnabled, let selected = selectedProvider, !isInstalled(selected) {
            setEnabled(false)
            message = "找不到 \(selected.name)，请重新选择应用位置。"
        }
    }

    func select(_ provider: Provider) {
        guard let provider = providers.first(where: { $0.id == provider.id }) else { return }
        guard provider.isConfigured, isInstalled(provider) else {
            message = "先完成 \(provider.name) 的快捷键接入，再使用 One Fn。"
            return
        }
        selectedID = provider.id
        router.update(shortcut: provider.shortcut, translation: provider.translationShortcut)
        let saved = persist()
        launch(provider)
        if isEnabled { isListening = router.isRunning }
        if saved { message = "已选择 \(provider.name) · Fn → \(provider.shortcut.display)" }
    }

    func selectNext() {
        let choices = configuredProviders
        guard !choices.isEmpty else { message = "先接入一个语音输入法，就可以快捷切换。"; return }
        let next = choices.firstIndex { $0.id == selectedID }.map { ($0 + 1) % choices.count } ?? 0
        select(choices[next])
    }

    func setEnabled(_ enabled: Bool) {
        if !enabled {
            router.stop(); isEnabled = false; isListening = false; isPressing = false
            wantsEnabled = false; persist()
            return
        }
        guard let provider = selectedProvider, provider.isConfigured, isInstalled(provider) else {
            message = "先接入并选择一个输入法，然后开启 One Fn。"; return
        }
        guard hasAccessibility && hasInputMonitoring else {
            message = "请在设置中允许 Voice Switch 使用辅助功能与输入监控。"; return
        }
        if setupDepth > 0 {
            isEnabled = true; wantsEnabled = true; persist()
            return
        }
        do {
            try router.start(shortcut: provider.shortcut, translation: provider.translationShortcut)
            isEnabled = true; isListening = router.isRunning
            wantsEnabled = true
            let saved = persist()
            launch(provider)
            if saved { message = nil }
        } catch {
            message = error.localizedDescription; isEnabled = false; isListening = false
        }
    }

    @discardableResult
    func saveProvider(_ provider: Provider) -> Bool {
        let bindings = [provider.shortcut, provider.translationShortcut].compactMap { $0 }
        if provider.isConfigured {
            if let translation = provider.translationShortcut, provider.shortcut.conflicts(with: translation) {
                message = "语音与翻译的快捷键会同时触发。请选择互不包含的两个组合。"; return false
            }
            for other in providers where other.id != provider.id && other.isConfigured {
                let otherBindings = [other.shortcut, other.translationShortcut].compactMap { $0 }
                if bindings.contains(where: { candidate in otherBindings.contains { candidate.conflicts(with: $0) } }) {
                    message = "快捷键与 \(other.name) 重叠。纯修饰键也需要避开其他快捷键的组合，以免同时触发。"; return false
                }
            }
            let cycle = Shortcut(keyCode: 49, key: "Space")
            if hotkeyEnabled && bindings.contains(where: { $0.conflicts(with: cycle) }) {
                message = "此组合与切换输入法的 ⌃⌥⌘Space 重叠。请选择其他组合，或在设置中关闭快捷切换。"; return false
            }
        }
        guard let index = providers.firstIndex(where: { $0.id == provider.id }) else { return false }
        providers[index] = provider
        if selectedID == provider.id {
            if provider.isConfigured { router.update(shortcut: provider.shortcut, translation: provider.translationShortcut) }
            else { setEnabled(false) }
        }
        guard persist() else { refresh(); return false }
        refresh()
        if selectedID == nil && provider.isConfigured { select(provider) }
        message = provider.isConfigured ? "\(provider.name) 已接入。请在文字输入框中试一下 Fn。" : "已保存 \(provider.name) 的设置。"
        return true
    }

    func beginSetup() {
        if setupDepth == 0 {
            router.stop(); isListening = false
        }
        setupDepth += 1
    }

    func endSetup() {
        setupDepth = max(0, setupDepth - 1)
        if setupDepth == 0 && wantsEnabled {
            setEnabled(true)
        }
    }

    func removeProvider(_ provider: Provider) {
        guard provider.isCustom else { return }
        if selectedID == provider.id { setEnabled(false); selectedID = nil }
        providers.removeAll { $0.id == provider.id }; persist(); refresh()
    }

    func locate(_ provider: Provider) {
        let panel = applicationPanel()
        guard panel.runModal() == .OK, let url = panel.url, let bundle = Bundle(url: url), let identifier = bundle.bundleIdentifier else { return }
        var updated = provider
        updated.appPath = url.path
        updated.bundleIDs = [identifier]
        updated.isConfigured = false
        saveProvider(updated)
    }

    func addApplication() {
        let panel = applicationPanel()
        guard panel.runModal() == .OK, let url = panel.url, let bundle = Bundle(url: url), let identifier = bundle.bundleIdentifier else { return }
        if let existing = providers.first(where: { $0.bundleIDs.contains(identifier) || installedPaths[$0.id] == url }) {
            message = "\(existing.name) 已在列表中，可以直接配置。"; return
        }
        let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String ?? url.deletingPathExtension().lastPathComponent
        let provider = Provider(id: UUID().uuidString, name: name, subtitle: "自己的语音输入工具", symbol: "waveform", tint: "548879", website: "", bundleIDs: [identifier], appNames: [url.deletingPathExtension().lastPathComponent], appPath: url.path, shortcut: .init(keyCode: 26, key: "7"), isCustom: true)
        providers.append(provider); persist(); refresh()
        message = "已添加 \(name)。点击接入，设置它自己的触发快捷键。"
    }

    func openSettings(_ provider: Provider) {
        if let id = provider.settingsBundleID, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
            open(url, activates: true)
        } else if provider.id == "chatterfly", let root = installedPaths[provider.id] {
            open(root.appendingPathComponent("Contents/ChatterflyPreference.app"), activates: true)
        } else if let url = installedPaths[provider.id] { open(url, activates: true) }
        else { message = "请先安装或定位 \(provider.name)。" }
    }

    func openWebsite(_ provider: Provider) {
        if let url = URL(string: provider.website), !provider.website.isEmpty { NSWorkspace.shared.open(url) }
    }

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    func requestInputMonitoring() {
        _ = CGRequestListenEventAccess()
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!)
    }

    func openKeyboardSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension")!)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            launchAtLogin = SMAppService.mainApp.status == .enabled
            if enabled && !launchAtLogin { message = "请在系统设置 → 登录项中允许 Voice Switch 在登录时打开。" }
        } catch { message = "无法更新登录项：\(error.localizedDescription)" }
    }

    func setHotkeyEnabled(_ enabled: Bool) {
        let cycle = Shortcut(keyCode: 49, key: "Space")
        if enabled && configuredProviders.contains(where: { provider in
            [provider.shortcut, provider.translationShortcut].compactMap { $0 }.contains { $0.conflicts(with: cycle) }
        }) {
            message = "⌃⌥⌘Space 与已接入输入法的快捷键重叠，请先调整接入设置。"; return
        }
        hotkeyEnabled = enabled; onHotkeyChanged?(enabled); persist()
    }

    func testShortcut(_ provider: Provider) {
        guard hasAccessibility else { message = "请先允许辅助功能，再测试快捷键。"; return }
        message = "3 秒后发送 \(provider.shortcut.display)，请切到一个空白文字输入框。"
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            router.test(shortcut: provider.shortcut)
            message = "已发送快捷键。确认原应用是否响应；如开始了录音，请在原应用中结束。"
        }
    }

    func shutdown() { router.stop(); refreshTimer?.invalidate() }

    private func applicationPanel() -> NSOpenPanel {
        let panel = NSOpenPanel()
        panel.title = "选择语音输入应用"
        panel.prompt = "添加应用"
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        return panel
    }

    private func applicationURL(for provider: Provider) -> URL? {
        var candidates: [URL] = []
        if let path = provider.appPath { candidates.append(URL(fileURLWithPath: path)) }
        candidates += provider.bundleIDs.compactMap { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) }
        let roots = ["/Applications", NSHomeDirectory() + "/Applications", "/Library/Input Methods", NSHomeDirectory() + "/Library/Input Methods"]
        for root in roots {
            for name in provider.appNames { candidates.append(URL(fileURLWithPath: root).appendingPathComponent(name + ".app")) }
        }
        return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
    }

    private func launch(_ provider: Provider) {
        if !isRunning(provider), let url = installedPaths[provider.id] { open(url, activates: false) }
    }

    private func open(_ url: URL, activates: Bool) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = activates
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { [weak self] _, error in
            if let error { Task { @MainActor in self?.message = "应用未能打开：\(error.localizedDescription)" } }
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: configurationURL.path) else { return }
        do {
            let saved = try JSONDecoder().decode(Configuration.self, from: Data(contentsOf: configurationURL))
            providers = saved.providers + Provider.catalog.filter { candidate in !saved.providers.contains { $0.id == candidate.id } }
            selectedID = saved.selectedID; hotkeyEnabled = saved.hotkeyEnabled
            wantsEnabled = saved.isEnabled ?? false
        } catch { message = "配置读取失败：\(error.localizedDescription)" }
    }

    @discardableResult
    private func persist() -> Bool {
        do {
            try FileManager.default.createDirectory(at: configurationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(Configuration(providers: providers, selectedID: selectedID, hotkeyEnabled: hotkeyEnabled, isEnabled: wantsEnabled))
            try data.write(to: configurationURL, options: .atomic)
            return true
        } catch { message = "配置保存失败：\(error.localizedDescription)"; return false }
    }
}
