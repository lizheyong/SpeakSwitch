import CoreGraphics
import Foundation
import Testing
import VoiceSwitchCore
@testable import VoiceSwitch

@Suite @MainActor struct ShortcutPulseQueueTests {
    private let first = Shortcut(keyCode: 18, key: "1", command: false)
    private let second = Shortcut(keyCode: 18, key: "1", option: false)

    @Test func sameTurnEnqueuesWaitForTheCallbackToReturnAndStaySerial() {
        let clock = PulseClock()
        var edges: [(Shortcut, Bool, TimeInterval)] = []
        let queue = ShortcutPulseQueue(
            press: { edges.append(($0, true, clock.now)) },
            release: { edges.append(($0, false, clock.now)) },
            schedule: clock.schedule
        )

        queue.enqueue(first)
        queue.enqueue(second)
        #expect(edges.isEmpty)

        clock.advance(to: 0)
        #expect(edges.map(\.0) == [first])
        clock.advance(to: 0.16)
        #expect(edges.map(\.0) == [first, first, second, second])
        #expect(edges.map(\.1) == [true, false, true, false])
        #expect(edges.map { Int(($0.2 * 1_000).rounded()) } == [0, 50, 75, 125])
    }

    @Test func cancellationBeforeStartEmitsNothingAndOldCallbackCannotStartNewProvider() {
        var scheduled: [@MainActor () -> Void] = []
        var pressed: [Shortcut] = []
        var released: [Shortcut] = []
        let queue = ShortcutPulseQueue(
            press: { pressed.append($0) },
            release: { released.append($0) },
            schedule: { _, action in scheduled.append(action) }
        )

        queue.enqueue(first)
        queue.cancel()
        queue.enqueue(second)
        scheduled.removeFirst()() // The cancelled provider's pending start.
        #expect(pressed.isEmpty)
        #expect(released.isEmpty)

        scheduled.removeFirst()()
        #expect(pressed == [second])
        queue.cancel()
        scheduled.removeFirst()() // The cancelled hold must not release again.
        #expect(pressed == [second])
        #expect(released == [second])
    }

    @Test func sixteenMillisecondReceiverSeesTheCompleteChordAndRelease() {
        let immediateClock = PulseClock()
        let immediateReceiver = SampledKeyboard(clock: immediateClock)
        immediateReceiver.consume(FnRouter.makeShortcutEvents(shortcut: first, down: true, physicalModifiers: []))
        immediateReceiver.consume(FnRouter.makeShortcutEvents(shortcut: first, down: false, physicalModifiers: []))
        immediateClock.advance(to: 0.1)
        #expect(!immediateReceiver.samples.contains { $0.keys == [18] && $0.flags == [.maskControl, .maskAlternate] })

        let clock = PulseClock()
        let receiver = SampledKeyboard(clock: clock)
        let queue = ShortcutPulseQueue(
            press: { receiver.consume(FnRouter.makeShortcutEvents(shortcut: $0, down: true, physicalModifiers: [])) },
            release: { receiver.consume(FnRouter.makeShortcutEvents(shortcut: $0, down: false, physicalModifiers: [])) },
            schedule: clock.schedule
        )

        queue.enqueue(first)
        clock.advance(to: 0.016)
        #expect(receiver.samples.last?.keys == [18])
        #expect(receiver.samples.last?.flags == [.maskControl, .maskAlternate])
        clock.advance(to: 0.066)
        #expect(receiver.samples.last?.keys == [])
        #expect(receiver.samples.last?.flags == [])
    }

    @Test func quickDoubleTapProducesTwoDistinctSampledPresses() {
        let clock = PulseClock()
        let receiver = SampledKeyboard(clock: clock)
        var edges: [(Bool, TimeInterval)] = []
        let queue = ShortcutPulseQueue(
            press: { edges.append((true, clock.now)); receiver.consume(FnRouter.makeShortcutEvents(shortcut: $0, down: true, physicalModifiers: [])) },
            release: { edges.append((false, clock.now)); receiver.consume(FnRouter.makeShortcutEvents(shortcut: $0, down: false, physicalModifiers: [])) },
            schedule: clock.schedule
        )

        queue.enqueue(first)
        clock.advance(to: 0.005)
        queue.enqueue(first)
        clock.advance(to: 0.16)

        #expect(edges.map(\.0) == [true, false, true, false])
        #expect(edges.map { Int(($0.1 * 1_000).rounded()) } == [0, 50, 75, 125])
        let presses = receiver.samples.indices.filter { receiver.samples[$0].keys == [18] }
        #expect(presses.count == 2)
        if presses.count == 2 {
            #expect(receiver.samples[(presses[0] + 1)..<presses[1]].contains { $0.keys.isEmpty && $0.flags.isEmpty })
        }
    }

    @Test func cancellationReleasesOriginalAndDiscardsQueuedShortcut() {
        let clock = PulseClock()
        var pressed: [Shortcut] = []
        var released: [Shortcut] = []
        let queue = ShortcutPulseQueue(press: { pressed.append($0) }, release: { released.append($0) }, schedule: clock.schedule)

        queue.enqueue(first)
        queue.enqueue(second)
        clock.advance(to: 0.01)
        queue.cancel()
        queue.cancel()
        clock.advance(to: 1)

        #expect(pressed == [first])
        #expect(released == [first])
    }

    @Test func oldReleaseCannotEndTheNewProviderPulse() {
        let clock = PulseClock()
        var releases: [(Shortcut, TimeInterval)] = []
        let queue = ShortcutPulseQueue(press: { _ in }, release: { releases.append(($0, clock.now)) }, schedule: clock.schedule)

        queue.enqueue(first)
        clock.advance(to: 0.01)
        queue.cancel()
        queue.enqueue(second)
        clock.advance(to: 0.05)
        #expect(releases.map(\.0) == [first])
        clock.advance(to: 0.061)
        #expect(releases.map(\.0) == [first, second])
        #expect(Int((releases[1].1 * 1_000).rounded()) == 60)
    }

    @Test func cancelledGapCannotStartAnOldQueuedPulse() {
        let clock = PulseClock()
        var presses: [Shortcut] = []
        let queue = ShortcutPulseQueue(press: { presses.append($0) }, release: { _ in }, schedule: clock.schedule)
        queue.enqueue(first)
        queue.enqueue(first)
        clock.advance(to: 0.055)
        queue.cancel()
        queue.enqueue(second)
        clock.advance(to: 0.09)
        #expect(presses == [first, second])
    }

    @Test func shiftReleasedDuringHoldIsNotRestored() {
        let clock = PulseClock()
        var hardware: [(CGKeyCode, CGEventFlags)] = [(56, .maskShift)]
        var releases: [CGEvent] = []
        let queue = ShortcutPulseQueue(
            press: { _ = FnRouter.makeShortcutEvents(shortcut: $0, down: true, physicalModifiers: hardware) },
            release: { releases = FnRouter.makeShortcutEvents(shortcut: $0, down: false, physicalModifiers: hardware) },
            schedule: clock.schedule
        )
        queue.enqueue(first)
        clock.advance(to: 0.02)
        hardware = []
        clock.advance(to: 0.05)
        #expect(releases.last?.flags == [])
        #expect(!releases.contains { $0.getIntegerValueField(.keyboardEventKeycode) == 56 })
    }

    @Test func rightShiftPressedDuringHoldIsRestoredOnRelease() {
        let clock = PulseClock()
        var hardware: [(CGKeyCode, CGEventFlags)] = []
        var releases: [CGEvent] = []
        let queue = ShortcutPulseQueue(
            press: { _ = FnRouter.makeShortcutEvents(shortcut: $0, down: true, physicalModifiers: hardware) },
            release: { releases = FnRouter.makeShortcutEvents(shortcut: $0, down: false, physicalModifiers: hardware) },
            schedule: clock.schedule
        )
        queue.enqueue(first)
        clock.advance(to: 0.02)
        hardware = [(60, .maskShift)]
        clock.advance(to: 0.05)
        #expect(releases.last?.getIntegerValueField(.keyboardEventKeycode) == 60)
        #expect(releases.last?.flags.rawValue == 0x20004)
        #expect(releases.first?.type == .keyUp)
        #expect(releases.first?.flags.intersection(deviceIndependentFlags) == [.maskControl, .maskAlternate])
    }

    @Test func modifierOnlyBindingHasBalancedFlagsAcrossTheHold() {
        let shortcut = Shortcut(keyCode: .max, key: "", shift: true, command: false)
        let press = FnRouter.makeShortcutEvents(shortcut: shortcut, down: true, physicalModifiers: [])
        let release = FnRouter.makeShortcutEvents(shortcut: shortcut, down: false, physicalModifiers: [])
        #expect(press.map { $0.getIntegerValueField(.keyboardEventKeycode) } == [59, 58, 56])
        #expect(release.map { $0.getIntegerValueField(.keyboardEventKeycode) } == [56, 58, 59])
        #expect((press + release).allSatisfy { $0.type == .flagsChanged })
        #expect(press.last?.flags.intersection(deviceIndependentFlags) == [.maskControl, .maskAlternate, .maskShift])
        #expect(release.last?.flags == [])
    }

    @Test func wetypeLeftControlOptionTwoCarriesSideFlagsThroughRelease() {
        let shortcut = Shortcut(keyCode: 19, key: "2", command: false)
        let events = FnRouter.makeShortcutEvents(shortcut: shortcut, down: true, physicalModifiers: [])
            + FnRouter.makeShortcutEvents(shortcut: shortcut, down: false, physicalModifiers: [])

        #expect(events.map(\.type) == [.flagsChanged, .flagsChanged, .keyDown, .keyUp, .flagsChanged, .flagsChanged])
        #expect(events.map { $0.getIntegerValueField(.keyboardEventKeycode) } == [59, 58, 19, 19, 58, 59])
        #expect(events.map { $0.flags.rawValue } == [0x40001, 0xc0021, 0xc0021, 0xc0021, 0x40001, 0])
    }

    @Test func postedWetypeModifiersAreNotRestoredAsPhysicalKeys() {
        let tag: Int64 = 0x4F4E45464E
        let shortcut = Shortcut(keyCode: 19, key: "2", command: false)
        var physical = PhysicalModifierState()
        let down = FnRouter.makeShortcutEvents(shortcut: shortcut, down: true, physicalModifiers: physical.keys)
        for event in down {
            event.setIntegerValueField(.eventSourceUserData, value: tag)
            physical.observe(event, ignoring: tag)
        }
        // The active HID tap exposes these posted Ctrl/Option flags through
        // CGEventSource state too. They are not new physical presses.
        #expect(down.last?.flags.rawValue == 0xc0021)
        #expect(physical.keys.isEmpty)
        let up = FnRouter.makeShortcutEvents(shortcut: shortcut, down: false, physicalModifiers: physical.keys)
        #expect(up.map { $0.getIntegerValueField(.keyboardEventKeycode) } == [19, 58, 59])
        #expect(up.last?.flags == [])
    }

    @Test func physicalShiftReleaseDuringSyntheticChordDoesNotAdoptItsModifiers() {
        let tag: Int64 = 0x4F4E45464E
        var physical = PhysicalModifierState(flags: CGEventFlags(rawValue: 0x20002))
        let shiftUp = CGEvent(keyboardEventSource: nil, virtualKey: 56, keyDown: false)!
        shiftUp.type = .flagsChanged
        shiftUp.flags = CGEventFlags(rawValue: 0xc0021)
        physical.observe(shiftUp, ignoring: tag)
        #expect(physical.keys.isEmpty)

        let rightShiftDown = CGEvent(keyboardEventSource: nil, virtualKey: 60, keyDown: true)!
        rightShiftDown.type = .flagsChanged
        rightShiftDown.flags = CGEventFlags(rawValue: 0xe0025)
        physical.observe(rightShiftDown, ignoring: tag)
        #expect(physical.keys.map(\.0) == [60])
        let up = FnRouter.makeShortcutEvents(shortcut: first, down: false, physicalModifiers: physical.keys)
        #expect(up.last?.getIntegerValueField(.keyboardEventKeycode) == 60)
        #expect(up.last?.flags.rawValue == 0x20004)
    }

    @Test func releasingLeftShiftKeepsPhysicalRightShiftHeld() {
        let tag: Int64 = 0x4F4E45464E
        var physical = PhysicalModifierState(flags: CGEventFlags(rawValue: 0x20006))
        let leftUp = CGEvent(keyboardEventSource: nil, virtualKey: 56, keyDown: false)!
        leftUp.type = .flagsChanged
        leftUp.flags = CGEventFlags(rawValue: 0x20004)
        physical.observe(leftUp, ignoring: tag)
        #expect(physical.keys.map(\.0) == [60])
    }
}

private let deviceIndependentFlags = CGEventFlags(rawValue: 0xffff0000)

@MainActor private final class PulseClock {
    private(set) var now: TimeInterval = 0
    private var pending: [(deadline: TimeInterval, action: @MainActor () -> Void)] = []

    func schedule(_ delay: TimeInterval, _ action: @escaping @MainActor () -> Void) {
        pending.append((now + delay, action))
    }

    func advance(to time: TimeInterval) {
        while let index = pending.indices.min(by: { pending[$0].deadline < pending[$1].deadline }), pending[index].deadline <= time {
            let next = pending.remove(at: index)
            now = next.deadline
            next.action()
        }
        now = time
    }
}

/// Models a receiver that broadcasts its latest state at most once per 16 ms.
@MainActor private final class SampledKeyboard {
    struct Snapshot {
        var keys: Set<CGKeyCode> = []
        var flags: CGEventFlags = []
    }

    private let clock: PulseClock
    private var current = Snapshot()
    private var lastBroadcast: TimeInterval = -1
    private var scheduled = false
    private(set) var samples: [Snapshot] = []

    init(clock: PulseClock) { self.clock = clock }

    func consume(_ events: [CGEvent]) {
        for event in events {
            let key = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
            if event.type == .keyDown { current.keys.insert(key) }
            if event.type == .keyUp { current.keys.remove(key) }
            current.flags = event.flags.intersection(deviceIndependentFlags)
            let elapsed = clock.now - lastBroadcast
            if elapsed >= 0.016 {
                broadcast()
            } else if !scheduled {
                scheduled = true
                clock.schedule(0.016 - elapsed) { [weak self] in self?.broadcast() }
            }
        }
    }

    private func broadcast() {
        scheduled = false
        lastBroadcast = clock.now
        samples.append(current)
    }
}
