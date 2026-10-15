import AppKit
import Combine
import SwiftUI

@main
struct VoiceSwitchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    var body: some Scene { Settings { EmptyView() } }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var store: AppStore!
    private var window: NSWindow!
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private let hotkey = GlobalHotkey()
    private var subscriptions: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        store = AppStore()
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1000, height: 740), styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        window.title = "Voice Switch — One Fn"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.minSize = NSSize(width: 900, height: 650)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentView = NSHostingView(rootView: MainContentView(store: store))
        window.center()
        window.setFrameAutosaveName("VoiceSwitchMain")

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Voice Switch")
            button.imagePosition = .imageLeading
            button.target = self
            button.action = #selector(togglePopover)
            button.toolTip = "Voice Switch · One Fn"
        }
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 340, height: 430)
        popover.contentViewController = NSHostingController(rootView: MenuContentView(store: store, onOpen: { [weak self] in self?.showWindow() }, onQuit: { NSApp.terminate(nil) }))
        store.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.updateStatus() }
        }.store(in: &subscriptions)
        hotkey.action = { [weak self] in self?.store.selectNext() }
        store.onHotkeyChanged = { [weak self] enabled in
            guard let self else { return }
            if !self.hotkey.setEnabled(enabled) { self.store.message = "切换快捷键 ⌃⌥⌘Space 已被占用，仍可从菜单栏切换。" }
        }
        store.onHotkeyChanged?(store.hotkeyEnabled)
        updateStatus()
        if !CommandLine.arguments.contains("--background") { showWindow() }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showWindow(); return true }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationWillTerminate(_ notification: Notification) { store.shutdown() }
    func windowWillClose(_ notification: Notification) { NSApp.setActivationPolicy(.accessory) }

    func showWindow() {
        popover.performClose(nil)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    @objc private func togglePopover() {
        if popover.isShown { popover.performClose(nil) }
        else if let button = statusItem.button { popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY) }
    }

    private func updateStatus() {
        statusItem.button?.title = " " + (store.selectedProvider?.name ?? "One Fn")
        statusItem.button?.appearsDisabled = !store.isListening
    }
}
