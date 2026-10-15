import ApplicationServices
import Foundation
import VoiceSwitchCore

/// A one-second trace of this app's synthetic test shortcut only.
@MainActor
final class ShortcutDiagnostics {
    static var logURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Voice Switch/shortcut-test.log")
    }

    private let eventTag: Int64
    private let started = DispatchTime.now().uptimeNanoseconds
    private var observations: [Observation] = []
    private var lines: [String] = []
    private var finished = false

    init(eventTag: Int64, delivery: ShortcutDelivery) {
        self.eventTag = eventTag
        lines.append("Voice Switch shortcut test \(ISO8601DateFormatter().string(from: Date())) delivery=\(delivery.rawValue)")
        lines.append("permissions accessibility=\(AXIsProcessTrusted()) listen=\(CGPreflightListenEventAccess()) post=\(CGPreflightPostEventAccess())")
        observe("hid-head", location: .cghidEventTap, placement: .headInsertEventTap)
        observe("session-head", location: .cgSessionEventTap, placement: .headInsertEventTap)
        observe("session-tail", location: .cgSessionEventTap, placement: .tailAppendEventTap)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.finish(reason: "one-second observation complete")
        }
    }

    func record(phase: String, event: CGEvent) {
        guard !finished else { return }
        let elapsed = Double(DispatchTime.now().uptimeNanoseconds - started) / 1_000_000
        if let line = Self.eventLine(phase: phase, event: event, eventTag: eventTag, elapsedMilliseconds: elapsed) {
            lines.append(line)
        }
    }

    /// Filtering precedes reading keyboard fields, including for the tap callbacks.
    static func eventLine(phase: String, event: CGEvent, eventTag: Int64, elapsedMilliseconds: Double) -> String? {
        guard event.getIntegerValueField(.eventSourceUserData) == eventTag else { return nil }
        return String(format: "%.3fms", elapsedMilliseconds)
            + " phase=\(phase) type=\(event.type.rawValue) keyCode=\(event.getIntegerValueField(.keyboardEventKeycode))"
            + " flags=0x\(String(event.flags.rawValue, radix: 16))"
            + " sourcePID=\(event.getIntegerValueField(.eventSourceUnixProcessID))"
            + " sourceStateID=\(event.getIntegerValueField(.eventSourceStateID))"
            + " timestamp=\(event.timestamp)"
    }

    func finish(reason: String) {
        guard !finished else { return }
        finished = true
        for observation in observations {
            if let tap = observation.tap { CGEvent.tapEnable(tap: tap, enable: false) }
            if let source = observation.source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
            if let tap = observation.tap { CFMachPortInvalidate(tap) }
        }
        observations.removeAll()
        lines.append("finished reason=\(reason)")
        do {
            try FileManager.default.createDirectory(at: Self.logURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try (lines.joined(separator: "\n") + "\n").write(to: Self.logURL, atomically: true, encoding: .utf8)
        } catch {
            NSLog("Voice Switch could not save shortcut test: %@", error.localizedDescription)
        }
    }

    private func observe(_ phase: String, location: CGEventTapLocation, placement: CGEventTapPlacement) {
        let observation = Observation(owner: self, phase: phase)
        let callback: CGEventTapCallBack = { _, _, event, context in
            guard let context else { return Unmanaged.passUnretained(event) }
            MainActor.assumeIsolated {
                let observation = Unmanaged<Observation>.fromOpaque(context).takeUnretainedValue()
                observation.owner?.record(phase: observation.phase, event: event)
            }
            return Unmanaged.passUnretained(event)
        }
        let mask = CGEventMask(1 << CGEventType.flagsChanged.rawValue)
            | CGEventMask(1 << CGEventType.keyDown.rawValue)
            | CGEventMask(1 << CGEventType.keyUp.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: location, place: placement, options: .listenOnly,
            eventsOfInterest: mask, callback: callback,
            userInfo: Unmanaged.passUnretained(observation).toOpaque()
        ) else {
            lines.append("observer=\(phase) created=false")
            return
        }
        observation.tap = tap
        observation.source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        observations.append(observation)
        CFRunLoopAddSource(CFRunLoopGetMain(), observation.source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        lines.append("observer=\(phase) created=true")
    }

    @MainActor
    private final class Observation {
        weak var owner: ShortcutDiagnostics?
        let phase: String
        var tap: CFMachPort?
        var source: CFRunLoopSource?

        init(owner: ShortcutDiagnostics, phase: String) {
            self.owner = owner
            self.phase = phase
        }
    }
}
