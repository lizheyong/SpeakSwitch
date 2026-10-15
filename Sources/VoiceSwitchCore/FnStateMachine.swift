import Foundation

/// A complete Fn gesture dispatches one shortcut pulse on release.
/// Shift selects translation; another key leaves the gesture to macOS.
public struct FnStateMachine {
    public enum Input: Equatable {
        case fnDown(shift: Bool, hasOtherModifiers: Bool)
        case fnUp
        case shiftChanged(isDown: Bool)
        case chord
    }

    public enum Effect: Equatable {
        case pressChanged(Bool)
        case pulse(Shortcut)
        case translationUnavailable
        case restoreFnDown
    }

    public struct Transition: Equatable {
        public var consume: Bool
        public var effects: [Effect]

        public init(consume: Bool = false, effects: [Effect] = []) {
            self.consume = consume
            self.effects = effects
        }
    }

    private enum State {
        case idle
        case pending(translation: Bool)
        case passthrough
        case cancelled
    }

    private var state: State = .idle
    public private(set) var shortcut: Shortcut
    public private(set) var translation: Shortcut?

    public init(shortcut: Shortcut, translation: Shortcut? = nil) {
        self.shortcut = shortcut
        self.translation = translation
    }

    public mutating func handle(_ input: Input) -> Transition {
        switch (state, input) {
        case (.idle, .fnDown(let shift, let hasOtherModifiers)):
            if hasOtherModifiers {
                state = .passthrough
                return .init()
            }
            state = .pending(translation: shift)
            return .init(consume: true, effects: [.pressChanged(true)])

        case (.pending, .fnDown), (.cancelled, .fnDown):
            return .init(consume: true)

        case (.pending, .shiftChanged(isDown: true)):
            state = .pending(translation: true)
            return .init()

        case (.pending(let useTranslation), .fnUp):
            state = .idle
            let dispatch: Effect = useTranslation
                ? translation.map(Effect.pulse) ?? .translationUnavailable
                : .pulse(shortcut)
            return .init(consume: true, effects: [.pressChanged(false), dispatch])

        case (.pending, .chord):
            state = .passthrough
            return .init(effects: [.pressChanged(false), .restoreFnDown])

        case (.cancelled, .chord):
            state = .passthrough
            return .init(effects: [.restoreFnDown])

        case (.cancelled, .fnUp):
            state = .idle
            return .init(consume: true)

        case (.passthrough, .fnUp):
            state = .idle
            return .init()

        default:
            return .init()
        }
    }

    /// A provider change cancels the in-progress gesture. The next fresh Fn
    /// press uses the newly selected provider.
    public mutating func update(shortcut: Shortcut, translation: Shortcut? = nil) -> [Effect] {
        self.shortcut = shortcut
        self.translation = translation
        if case .pending = state {
            state = .cancelled
            return [.pressChanged(false)]
        }
        return []
    }

    /// Return a suppressed physical Fn to macOS when routing stops.
    public mutating func stop() -> [Effect] {
        let effects: [Effect]
        switch state {
        case .pending: effects = [.pressChanged(false), .restoreFnDown]
        case .cancelled: effects = [.restoreFnDown]
        case .idle, .passthrough: effects = []
        }
        state = .idle
        return effects
    }

    /// A tap interruption cancels the current gesture. A passed-through Fn
    /// combination continues receiving its physical release.
    public mutating func interrupt(fnIsDown: Bool) -> [Effect] {
        switch state {
        case .pending:
            state = fnIsDown ? .cancelled : .idle
            return [.pressChanged(false)]
        case .cancelled:
            state = fnIsDown ? .cancelled : .idle
        case .idle, .passthrough:
            state = fnIsDown ? .passthrough : .idle
        }
        return []
    }
}
