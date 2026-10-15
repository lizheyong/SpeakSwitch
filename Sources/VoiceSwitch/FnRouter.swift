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
    var onPulse: ((Shortcut) -> Void)?
    var onInterrupted: (() -> Void)?
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
    private let captureLocation: CGEventTapLocation = .cgSessionEventTap
    private var delivery: ShortcutDelivery = .hid
    private var diagnostics: ShortcutDiagnostics?
    private let eventSource = CGEventSource(stateID: .privateState)
    private var physicalFlags: CGEventFlags = []
    private var physicalModifiers = PhysicalModifierState()
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
                return "请在系统设置 → 隐私与安全性 → 辅助功能中允许声选控制快捷键。"
            case .eventTap:
                return "无法监听 Fn。请检查声选的辅助功能和输入监控权限，然后重新启动声选。"
            }
        }
    }

    func start(shortcut: Shortcut, translation: Shortcut? = nil, delivery: ShortcutDelivery = .hid) throws {
        if isRunning {
            update(shortcut: shortcut, translation: translation, delivery: delivery)
            return
        }
        guard AXIsProcessTrusted() else { throw RouterError.accessibility }
        let continuePhysicalTracking = diagnostics?.tracksPhysicalModifiers == true
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
            tap: captureLocation,
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
        if !continuePhysicalTracking {
            physicalModifiers = PhysicalModifierState(flags: physicalFlags)
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        isRunning = true
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, !AXIsProcessTrusted() else { return }
                self.stop()
                self.onFailure?("辅助功能权限已关闭，声选已停止接管 Fn。重新授权后可再次启用。")
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
        let continuePhysicalTracking = isRunning || diagnostics?.tracksPhysicalModifiers == true
        pulses.cancel()
        diagnostics?.finish(reason: "next test")
        self.delivery = delivery
        let diagnostics = ShortcutDiagnostics(eventTag: eventTag, delivery: delivery, onModifierEvent: { [weak self] event in
            guard let self, !self.isRunning else { return }
            self.physicalModifiers.observe(event, ignoring: self.eventTag)
        })
        self.diagnostics = diagnostics
        guard AXIsProcessTrusted(), CGPreflightPostEventAccess() else {
            onFailure?(RouterError.accessibility.localizedDescription)
            diagnostics.finish(reason: "posting permission unavailable")
            return false
        }
        if !continuePhysicalTracking {
            physicalModifiers = PhysicalModifierState(flags: CGEventSource.flagsState(.hidSystemState))
        }
        pulses.enqueue(shortcut)
        return true
    }

    private func receive(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            pulses.cancel()
            onInterrupted?()
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
                onFailure?("键盘权限已中断，声选已停止接管 Fn。请检查系统权限。")
            }
            return Unmanaged.passUnretained(event)
        }
        physicalModifiers.observe(event, ignoring: eventTag)
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
                if UserDefaults.standard.bool(forKey: "TraceFnShortcuts") {
                    diagnostics?.finish(reason: "next real Fn")
                    let trace = ShortcutDiagnostics(eventTag: eventTag, delivery: delivery, observeStream: false)
                    trace.recordNote("trigger=realFn capture=\(captureLocation == .cghidEventTap ? "HID" : "Session")")
                    diagnostics = trace
                }
                pulses.enqueue(shortcut)
                onPulse?(shortcut)
            case .translationUnavailable:
                onUnavailableTranslation?()
            case .restoreFnDown:
                guard physicalFlags.contains(.maskSecondaryFn), let restored = fnDownEvent?.copy() else { continue }
                restored.flags = physicalFlags
                restored.setIntegerValueField(.eventSourceUserData, value: eventTag)
                if let proxy {
                    restored.tapPostEvent(proxy)
                } else {
                    restored.post(tap: captureLocation)
                }
            }
        }
    }

    fileprivate static let modifierKeys: [(left: CGKeyCode, right: CGKeyCode, flag: CGEventFlags)] = [
        (59, 62, .maskControl), (58, 61, .maskAlternate),
        (56, 60, .maskShift), (55, 54, .maskCommand)
    ]

    // IOLLEvent.h NX_DEVICE*KEYMASK values. Side-aware receivers use these
    // alongside the generic flags to track each modifier's press and release.
    fileprivate static let modifierSideFlags: [CGKeyCode: UInt64] = [
        59: 0x0001, 62: 0x2000, 58: 0x0020, 61: 0x0040,
        56: 0x0002, 60: 0x0004, 55: 0x0008, 54: 0x0010
    ]

    private func sendShortcut(_ shortcut: Shortcut, down: Bool) {
        // HID state also includes our posted shortcuts. Restore only modifiers
        // tracked from incoming events; our tagged events never change them.
        let hardwareFlags = CGEventSource.flagsState(.hidSystemState)
        let keyStates = Dictionary(uniqueKeysWithValues: Self.modifierKeys.flatMap { [$0.left, $0.right] }.map {
            ($0, CGEventSource.keyState(.hidSystemState, key: $0))
        })
        diagnostics?.recordHardwareState(phase: down ? "press" : "release", flags: hardwareFlags, modifierKeyStates: keyStates)
        let physicalKeys = physicalModifiers.keys
        diagnostics?.recordNote("physical-modifiers phase=\(down ? "press" : "release") keys=\(physicalKeys.map { String($0.0) }.joined(separator: ","))")
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
        func flags(for modifier: (CGKeyCode, CGEventFlags)) -> CGEventFlags {
            modifier.1.union(CGEventFlags(rawValue: modifierSideFlags[modifier.0] ?? 0))
        }
        func press(_ keys: [(CGKeyCode, CGEventFlags)]) -> CGEventFlags {
            var pressedFlags = baseFlags
            for modifier in keys {
                pressedFlags.formUnion(flags(for: modifier))
                append(key: modifier.0, down: true, flags: pressedFlags, modifier: true)
            }
            return pressedFlags
        }
        func release(_ keys: [(CGKeyCode, CGEventFlags)]) {
            for (index, modifier) in keys.enumerated() {
                let remaining = keys.dropFirst(index + 1).reduce(baseFlags) { $0.union(flags(for: $1)) }
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
            let targetFlags = targetKeys.reduce(baseFlags) { $0.union(flags(for: $1)) }
            if !shortcut.isModifierOnly {
                append(key: shortcut.keyCode, down: false, flags: targetFlags)
            }
            release(Array(targetKeys.reversed()))
            _ = press(physicalModifiers)
        }
        return events
    }
}

/// Tracks each physical modifier edge separately: aggregate HID flags can
/// include the shortcut currently being synthesized by this process.
@MainActor struct PhysicalModifierState {
    private var held: Set<CGKeyCode>

    init(flags: CGEventFlags = []) {
        held = Set(FnRouter.modifierSideFlags.compactMap { key, mask in
            flags.rawValue & mask != 0 ? key : nil
        })
    }

    var keys: [(CGKeyCode, CGEventFlags)] {
        FnRouter.modifierKeys.flatMap { modifier in
            [modifier.left, modifier.right].filter { held.contains($0) }.map { ($0, modifier.flag) }
        }
    }

    mutating func observe(_ event: CGEvent, ignoring tag: Int64) {
        guard event.type == .flagsChanged,
              event.getIntegerValueField(.eventSourceUserData) != tag else { return }
        let key = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        guard let mask = FnRouter.modifierSideFlags[key] else { return }
        if event.flags.rawValue & mask != 0 { held.insert(key) }
        else { held.remove(key) }
    }
}
