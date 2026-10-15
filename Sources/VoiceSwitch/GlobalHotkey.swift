import Carbon

@MainActor
final class GlobalHotkey {
    private var reference: EventHotKeyRef?
    private var handler: EventHandlerRef?
    var action: (() -> Void)?

    func setEnabled(_ enabled: Bool) -> Bool {
        if let reference { UnregisterEventHotKey(reference); self.reference = nil }
        if !enabled { return true }
        if handler == nil {
            var specification = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(GetApplicationEventTarget(), { _, _, context in
                guard let context else { return OSStatus(eventNotHandledErr) }
                let owner = Unmanaged<GlobalHotkey>.fromOpaque(context).takeUnretainedValue()
                MainActor.assumeIsolated { owner.action?() }
                return noErr
            }, 1, &specification, Unmanaged.passUnretained(self).toOpaque(), &handler)
        }
        let identifier = EventHotKeyID(signature: 0x564F4943, id: 1)
        return RegisterEventHotKey(UInt32(kVK_Space), UInt32(controlKey | optionKey | cmdKey), identifier, GetApplicationEventTarget(), 0, &reference) == noErr
    }
}
