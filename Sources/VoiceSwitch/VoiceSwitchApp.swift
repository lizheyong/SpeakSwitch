import AppKit
import Combine
import SwiftUI
import UniformTypeIdentifiers
import VoiceSwitchCore

@main
struct VoiceSwitchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    var body: some Scene { Settings { EmptyView() } }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate {
    private var store: AppStore!
    private var window: NSWindow!
    private var statusItem: NSStatusItem!
    private let statusMenu = NSMenu()
    private let hotkey = GlobalHotkey()
    private let switchFeedback = SwitchFeedback()
    private var subscriptions: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        store = AppStore()
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 940, height: 700), styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        window.title = "声选 · SpeakSwitch"
        window.toolbarStyle = .unified
        window.backgroundColor = .windowBackgroundColor
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentViewController = NSHostingController(rootView: MainContentView(store: store))
        window.minSize = NSSize(width: 760, height: 560)
        window.center()
        window.setFrameAutosaveName("VoiceSwitchMain")

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            // 自有标识的单色版本，随菜单栏明暗自动着色。
            button.image = BrandStatusIcon.image
            button.image?.accessibilityDescription = "声选"
            button.imagePosition = .imageLeading
            button.toolTip = "声选 · 语音输入切换器"
        }
        statusMenu.autoenablesItems = false
        statusMenu.delegate = self
        menuNeedsUpdate(statusMenu)
        statusItem.menu = statusMenu
        store.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.updateStatus() }
        }.store(in: &subscriptions)
        hotkey.action = { [weak self] in self?.store.selectNext() }
        store.onProviderSelected = { [weak self] provider in self?.switchFeedback.show(provider) }
        store.onHotkeyChanged = { [weak self] enabled in
            guard let self else { return }
            if !self.hotkey.setEnabled(enabled) { self.store.message = "切换快捷键 ⌃⌥⌘Space 已被占用，仍可从菜单栏切换。" }
        }
        store.onHotkeyChanged?(store.hotkeyEnabled)
        updateStatus()
        if store.showsSetupAssistant || !CommandLine.arguments.contains("--background") { showWindow() }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showWindow(); return true }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationWillTerminate(_ notification: Notification) {
        switchFeedback.close()
        store.shutdown()
    }
    func windowWillClose(_ notification: Notification) { NSApp.setActivationPolicy(.accessory) }

    func showWindow() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let status = NSMenuItem(title: store.isListening ? "语音输入已就绪 · Fn" : store.isEnabled ? "正在设置语音输入" : "语音快捷键已暂停", action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        menu.addItem(.separator())

        if store.configuredProviders.isEmpty {
            let empty = NSMenuItem(title: "尚未接入输入法", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            for provider in store.configuredProviders {
                let item = NSMenuItem(title: provider.name, action: #selector(selectProvider(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = provider.id
                item.image = menuIcon(for: provider)
                item.state = store.selectedID == provider.id ? .on : .off
                menu.addItem(item)
            }
        }
        menu.addItem(.separator())

        let toggle = NSMenuItem(title: store.isEnabled ? "暂停 Fn" : "启用 Fn", action: #selector(toggleFn(_:)), keyEquivalent: "")
        toggle.target = self
        toggle.isEnabled = store.isEnabled || store.selectedProvider?.isConfigured == true
        menu.addItem(toggle)
        menu.addItem(.separator())

        let open = NSMenuItem(title: "打开 声选…", action: #selector(openMainWindow(_:)), keyEquivalent: ",")
        open.target = self
        menu.addItem(open)
        let assistant = NSMenuItem(title: "接入助手…", action: #selector(openSetupAssistant(_:)), keyEquivalent: "")
        assistant.target = self
        menu.addItem(assistant)
        let quit = NSMenuItem(title: "退出 声选", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        menu.addItem(quit)
    }

    @objc private func selectProvider(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let provider = store.providers.first(where: { $0.id == id }) else { return }
        store.select(provider)
    }

    @objc private func toggleFn(_ sender: NSMenuItem) {
        store.setEnabled(!store.isEnabled)
    }

    @objc private func openMainWindow(_ sender: NSMenuItem) {
        showWindow()
    }

    @objc private func openSetupAssistant(_ sender: NSMenuItem) {
        store.showsSetupAssistant = true
        showWindow()
    }

    private func menuIcon(for provider: Provider) -> NSImage {
        var candidates: [URL] = []
        if let path = provider.appPath { candidates.append(URL(fileURLWithPath: path)) }
        candidates += provider.bundleIDs.compactMap { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) }
        for root in ["/Applications", NSHomeDirectory() + "/Applications", "/Library/Input Methods", NSHomeDirectory() + "/Library/Input Methods"] {
            for name in provider.appNames {
                candidates.append(URL(fileURLWithPath: root).appendingPathComponent(name + ".app"))
            }
        }
        let appURL = candidates.first { FileManager.default.fileExists(atPath: $0.path) }
        let source = appURL.map { NSWorkspace.shared.icon(forFile: $0.path) }
            ?? NSWorkspace.shared.icon(for: .applicationBundle)
        let icon = source.copy() as! NSImage
        icon.size = NSSize(width: 16, height: 16)
        return icon
    }

    private func updateStatus() {
        guard let button = statusItem.button else { return }
        button.title = store.showsProviderNameInMenuBar ? " " + (store.selectedProvider?.name ?? "声选") : ""
        button.imagePosition = store.showsProviderNameInMenuBar ? .imageLeading : .imageOnly
        let provider = store.selectedProvider?.name ?? "尚未接入输入法"
        let status = store.isListening ? "Fn 已就绪" : "Fn 已暂停"
        button.toolTip = "声选 · \(provider)\n\(status) · 点击切换输入法"
        button.setAccessibilityLabel("语音输入切换器，\(provider)，\(status)")
    }
}
