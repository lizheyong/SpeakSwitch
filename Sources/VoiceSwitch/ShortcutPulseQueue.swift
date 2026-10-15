import Foundation
import VoiceSwitchCore

/// Keeps a complete shortcut visible across receivers' event sampling windows.
@MainActor
final class ShortcutPulseQueue {
    private enum Phase {
        case idle
        case holding(Shortcut)
        case gap
    }

    private let press: (Shortcut) -> Void
    private let release: (Shortcut) -> Void
    private let schedule: (TimeInterval, @escaping @MainActor () -> Void) -> Void
    private var phase: Phase = .idle
    private var queued: [Shortcut] = []
    private var generation = 0

    init(
        press: @escaping (Shortcut) -> Void,
        release: @escaping (Shortcut) -> Void,
        schedule: @escaping (TimeInterval, @escaping @MainActor () -> Void) -> Void = { delay, action in
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { action() }
        }
    ) {
        self.press = press
        self.release = release
        self.schedule = schedule
    }

    func enqueue(_ shortcut: Shortcut) {
        queued.append(shortcut)
        if case .idle = phase { startNext() }
    }

    /// Ends the original shortcut once and discards gestures that have not begun.
    func cancel() {
        generation += 1
        queued.removeAll()
        let previous = phase
        phase = .idle
        if case .holding(let shortcut) = previous { release(shortcut) }
    }

    private func startNext() {
        guard !queued.isEmpty else { phase = .idle; return }
        let shortcut = queued.removeFirst()
        phase = .holding(shortcut)
        let current = generation
        press(shortcut)
        schedule(0.05) { [weak self] in
            guard let self, self.generation == current else { return }
            self.phase = .gap
            self.release(shortcut)
            self.schedule(0.025) { [weak self] in
                guard let self, self.generation == current else { return }
                self.phase = .idle
                self.startNext()
            }
        }
    }
}
