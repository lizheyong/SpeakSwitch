import AppKit
import ApplicationServices
import VoiceSwitchCore

/// One Fn owns the physical Fn gesture; providers receive their configured
/// shortcut. Providers must release their native Fn binding during setup.
@MainActor
final class FnRouter {
    var onPressChanged: ((Bool) -> Void)?
    var onFailure: ((String) -> Void)?
    var onUnavailableTranslation: (() -> Void)?
    private(set) var isRunning = false

    private let eventTag: Int64 = 0x4F4E45464E
    private let fnKeyCode: CGKeyCode = 63
    // NSEvent.systemDefined includes media keys; Quartz uses the same raw type.
    private let systemDefinedType: UInt32 = 14
    private let modifierMask: CGEventFlags = [.maskControl, .maskAlternate, .maskShift, .maskCommand]
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var permissionTimer: Timer?
    private var machine: FnStateMachine?
    private var fnDownEvent: CGEvent?
    private var pressedKeys: Set<CGKeyCode> = []
    private var delivery: ShortcutDelivery = .hid
    private var diagnostics: ShortcutDiagnostics?
    private let eventSource = CGEventSource(stateID: .privateState)
    private var physicalFlags: CGEventFlags = []
    private lazy var pulses = ShortcutPulseQueue(
        press: { [weak self] in self?.sendShortcut($0, down: true) },
        release: { [weak self] in self?.sendShortcut($0, down: false) }
    )

    enum RouterError: LocalizedError {
        case accessibility
        case eventTap

        var errorDescription: String? {
            switch self {
            case .accessibility:
                return "请在系统设置 → 隐私与安全性 → 辅助功能中允许 Voice Switch 控制快捷键。"
            case .eventTap:
                return "无法监听 Fn。请检查 Voice Switch 的辅助功能和输入监控权限，然后重新启动 Voice Switch。"
            }
        }
    }

    func start(shortcut: Shortcut, translation: Shortcut? = nil, delivery: ShortcutDelivery = .hid) throws {
        if isRunning {
            update(shortcut: shortcut, translation: translation, delivery: delivery)
            return
        }
        guard AXIsProcessTrusted() else { throw RouterError.accessibility }
        pulses.cancel()
        diagnostics?.finish(reason: "routing started")
        self.delivery = delivery
        let mask = CGEventMask(1 << CGEventType.flagsChanged.rawValue)
            | CGEventMask(1 << CGEventType.keyDown.rawValue)
            | CGEventMask(1 << CGEventType.keyUp.rawValue)
            | CGEventMask(1 << systemDefinedType)
        let callback: CGEventTapCallBack = { proxy, type, event, context in
            guard let context else { return Unmanaged.passUnretained(event) }
            // This tap's source is installed exclusively on the main run loop.
            return MainActor.assumeIsolated {
                Unmanaged<FnRouter>.fromOpaque(context).takeUnretainedValue()
                    .receive(proxy: proxy, type: type, event: event)
            }
        }
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { throw RouterError.eventTap }

        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        machine = FnStateMachine(shortcut: shortcut, translation: translation)
        physicalFlags = CGEventSource.flagsState(.hidSystemState)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        isRunning = true
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, !AXIsProcessTrusted() else { return }
                self.stop()
                self.onFailure?("辅助功能权限已关闭，Voice Switch 已停止接管 Fn。重新授权后可再次启用。")
            }
        }
    }

    func update(shortcut: Shortcut, translation: Shortcut? = nil, delivery: ShortcutDelivery = .hid) {
        pulses.cancel()
        diagnostics?.finish(reason: "binding updated")
        self.delivery = delivery
        guard var machine else { return }
        let effects = machine.update(shortcut: shortcut, translation: translation)
        self.machine = machine
        perform(effects)
    }

    func stop() {
        pulses.cancel()
        diagnostics?.finish(reason: "routing stopped")
        permissionTimer?.invalidate()
        permissionTimer = nil
        if var machine {
            let effects = machine.stop()
            self.machine = nil
            physicalFlags = CGEventSource.flagsState(.hidSystemState)
            perform(effects)
        }
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
        if let tap { CFMachPortInvalidate(tap) }
        runLoopSource = nil
        tap = nil
        fnDownEvent = nil
        pressedKeys.removeAll()
        isRunning = false
        onPressChanged?(false)
    }

    /// Sends a balanced test gesture. It does not activate or configure an app.
    @discardableResult
    func test(shortcut: Shortcut, delivery: ShortcutDelivery = .hid) -> Bool {
        pulses.cancel()
        diagnostics?.finish(reason: "next test")
        self.delivery = delivery
        let diagnostics = ShortcutDiagnostics(eventTag: eventTag, delivery: delivery)
        self.diagnostics = diagnostics
        guard AXIsProcessTrusted(), CGPreflightPostEventAccess() else {
            onFailure?(RouterError.accessibility.localizedDescription)
            diagnostics.finish(reason: "posting permission unavailable")
            return false
        }
        pulses.enqueue(shortcut)
        return true
    }

    private func receive(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            physicalFlags = CGEventSource.flagsState(.hidSystemState)
            if var machine {
                let effects = machine.interrupt(fnIsDown: physicalFlags.contains(.maskSecondaryFn))
                self.machine = machine
                perform(effects)
            }
            if AXIsProcessTrusted(), let tap {
                CGEvent.tapEnable(tap: tap, enable: true)
            } else {
                stop()
                onFailure?("键盘权限已中断，Voice Switch 已停止接管 Fn。请检查系统权限。")
            }
            return Unmanaged.passUnretained(event)
        }
        if event.getIntegerValueField(.eventSourceUserData) == eventTag {
            return Unmanaged.passUnretained(event)
        }

        physicalFlags = type.rawValue == systemDefinedType
            ? CGEventSource.flagsState(.hidSystemState)
            : event.flags
        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let input: FnStateMachine.Input
        if type.rawValue == systemDefinedType {
            input = .chord
        } else if type == .flagsChanged, keyCode == fnKeyCode {
            if event.flags.contains(.maskSecondaryFn) {
                // A later key can turn this gesture into an ordinary Fn combination.
                if fnDownEvent == nil { fnDownEvent = event.copy() }
                input = .fnDown(
                    shift: event.flags.contains(.maskShift),
                    hasOtherModifiers: !event.flags.intersection(modifierMask.subtracting(.maskShift)).isEmpty || !pressedKeys.isEmpty
                )
            } else {
                input = .fnUp
            }
        } else if type == .flagsChanged, keyCode == 56 || keyCode == 60 {
            input = .shiftChanged(isDown: event.flags.contains(.maskShift))
        } else {
            if type == .keyDown { pressedKeys.insert(keyCode) }
            if type == .keyUp { pressedKeys.remove(keyCode) }
            input = .chord
        }

        guard var machine else { return Unmanaged.passUnretained(event) }
        let transition = machine.handle(input)
        self.machine = machine
        perform(transition.effects, proxy: proxy)
        if input == .fnUp { fnDownEvent = nil }
        return transition.consume ? nil : Unmanaged.passUnretained(event)
    }

    private func perform(_ effects: [FnStateMachine.Effect], proxy: CGEventTapProxy? = nil) {
        for effect in effects {
            switch effect {
            case .pressChanged(let pressed):
                onPressChanged?(pressed)
            case .pulse(let shortcut):
                pulses.enqueue(shortcut)
            case .translationUnavailable:
                onUnavailableTranslation?()
            case .restoreFnDown:
                guard physicalFlags.contains(.maskSecondaryFn), let restored = fnDownEvent?.copy() else { continue }
                restored.flags = physicalFlags
                restored.setIntegerValueField(.eventSourceUserData, value: eventTag)
                if let proxy {
                    restored.tapPostEvent(proxy)
                } else {
                    restored.post(tap: .cgSessionEventTap)
                }
            }
        }
    }

    private static let modifierKeys: [(left: CGKeyCode, right: CGKeyCode, flag: CGEventFlags)] = [
        (59, 62, .maskControl), (58, 61, .maskAlternate),
        (56, 60, .maskShift), (55, 54, .maskCommand)
    ]

    private func sendShortcut(_ shortcut: Shortcut, down: Bool) {
        // The user may change modifiers during the hold. Read hardware again
        // for release so an earlier Shift press is never restored after it ends.
        let hardwareFlags = CGEventSource.flagsState(.hidSystemState)
        let physicalKeys: [(CGKeyCode, CGEventFlags)] = Self.modifierKeys.flatMap { modifier -> [(CGKeyCode, CGEventFlags)] in
            guard hardwareFlags.contains(modifier.flag) else { return [] }
            let held = [modifier.left, modifier.right].filter { CGEventSource.keyState(.hidSystemState, key: $0) }
            return (held.isEmpty ? [modifier.left] : held).map { ($0, modifier.flag) }
        }
        let events = Self.makeShortcutEvents(
            shortcut: shortcut,
            down: down,
            physicalModifiers: physicalKeys,
            capsLock: hardwareFlags.contains(.maskAlphaShift),
            source: eventSource
        )
        for event in events {
            event.timestamp = DispatchTime.now().uptimeNanoseconds
            event.setIntegerValueField(.eventSourceUserData, value: eventTag)
            diagnostics?.record(phase: down ? "post-down" : "post-up", event: event)
            event.post(tap: delivery == .hid ? .cghidEventTap : .cgSessionEventTap)
        }
    }

    /// Builds one phase using the physical modifiers at that phase's execution.
    /// Building events alone does not post keyboard input.
    static func makeShortcutEvents(
        shortcut: Shortcut,
        down: Bool,
        physicalModifiers: [(CGKeyCode, CGEventFlags)],
        capsLock: Bool = false,
        source: CGEventSource? = nil
    ) -> [CGEvent] {
        var events: [CGEvent] = []
        func append(key: CGKeyCode, down: Bool, flags: CGEventFlags, modifier: Bool = false) {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: down) else { return }
            if modifier { event.type = .flagsChanged }
            event.flags = flags
            events.append(event)
        }
        let baseFlags: CGEventFlags = capsLock ? .maskAlphaShift : []
        func press(_ keys: [(CGKeyCode, CGEventFlags)]) -> CGEventFlags {
            var flags = baseFlags
            for (key, flag) in keys {
                flags.insert(flag)
                append(key: key, down: true, flags: flags, modifier: true)
            }
            return flags
        }
        func release(_ keys: [(CGKeyCode, CGEventFlags)]) {
            for (index, modifier) in keys.enumerated() {
                let remaining = keys.dropFirst(index + 1).reduce(baseFlags) { $0.union($1.1) }
                append(key: modifier.0, down: false, flags: remaining, modifier: true)
            }
        }
        let selected = [shortcut.control, shortcut.option, shortcut.shift, shortcut.command]
        let targetKeys = modifierKeys.enumerated().compactMap { index, modifier in
            selected[index] ? (modifier.left, modifier.flag) : nil
        }

        // Fn+Shift must produce the exact configured shortcut even while the
        // user's Shift is still held. Restore the physical modifiers afterward.
        if down {
            release(physicalModifiers)
            let targetFlags = press(targetKeys)
            if !shortcut.isModifierOnly {
                append(key: shortcut.keyCode, down: true, flags: targetFlags)
            }
        } else {
            let targetFlags = targetKeys.reduce(baseFlags) { $0.union($1.1) }
            if !shortcut.isModifierOnly {
                append(key: shortcut.keyCode, down: false, flags: targetFlags)
            }
            release(Array(targetKeys.reversed()))
            _ = press(physicalModifiers)
        }
        return events
    }
}
