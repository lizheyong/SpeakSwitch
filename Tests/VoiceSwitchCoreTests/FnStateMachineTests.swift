import Testing
@testable import VoiceSwitchCore

struct FnStateMachineTests {
    private let dictation = Shortcut(keyCode: 18, key: "1")
    private let translation = Shortcut(keyCode: 19, key: "2")

    @Test func fnDispatchesOneDictationPulseOnRelease() {
        var router = FnStateMachine(shortcut: dictation)
        #expect(router.handle(.fnDown(shift: false, hasOtherModifiers: false)) == .init(consume: true, effects: [.pressChanged(true)]))
        #expect(router.handle(.fnUp) == .init(consume: true, effects: [.pressChanged(false), .pulse(dictation)]))
        #expect(router.handle(.fnUp) == .init())
    }

    @Test func repeatedFnFlagsDoNotDuplicateOrDispatchEarly() {
        var router = FnStateMachine(shortcut: dictation)
        _ = router.handle(.fnDown(shift: false, hasOtherModifiers: false))
        #expect(router.handle(.fnDown(shift: false, hasOtherModifiers: false)) == .init(consume: true))
        #expect(router.handle(.fnUp) == .init(consume: true, effects: [.pressChanged(false), .pulse(dictation)]))
    }

    @Test func shiftHeldBeforeFnSelectsTranslation() {
        var router = FnStateMachine(shortcut: dictation, translation: translation)
        #expect(router.handle(.shiftChanged(isDown: true)) == .init())
        _ = router.handle(.fnDown(shift: true, hasOtherModifiers: false))
        #expect(router.handle(.fnUp) == .init(consume: true, effects: [.pressChanged(false), .pulse(translation)]))
        #expect(router.handle(.shiftChanged(isDown: false)) == .init())
    }

    @Test func shiftPressedDuringFnSelectsTranslationEvenIfReleasedFirst() {
        var router = FnStateMachine(shortcut: dictation, translation: translation)
        _ = router.handle(.fnDown(shift: false, hasOtherModifiers: false))
        #expect(router.handle(.shiftChanged(isDown: true)) == .init())
        #expect(router.handle(.shiftChanged(isDown: false)) == .init())
        #expect(router.handle(.fnUp) == .init(consume: true, effects: [.pressChanged(false), .pulse(translation)]))
    }

    @Test func unconfiguredTranslationNeverFallsBackToDictation() {
        var router = FnStateMachine(shortcut: dictation)
        _ = router.handle(.fnDown(shift: true, hasOtherModifiers: false))
        #expect(router.handle(.fnUp) == .init(consume: true, effects: [.pressChanged(false), .translationUnavailable]))
    }

    @Test func fnDeleteRestoresFnAndDoesNotDispatch() {
        var router = FnStateMachine(shortcut: dictation)
        _ = router.handle(.fnDown(shift: false, hasOtherModifiers: false))
        #expect(router.handle(.chord) == .init(effects: [.pressChanged(false), .restoreFnDown]))
        #expect(router.handle(.chord) == .init())
        #expect(router.handle(.fnUp) == .init())
    }

    @Test func fnShiftArrowRemainsAnOrdinaryKeyboardCombination() {
        var router = FnStateMachine(shortcut: dictation, translation: translation)
        _ = router.handle(.fnDown(shift: false, hasOtherModifiers: false))
        _ = router.handle(.shiftChanged(isDown: true))
        #expect(router.handle(.chord) == .init(effects: [.pressChanged(false), .restoreFnDown]))
        #expect(router.handle(.fnUp) == .init())
    }

    @Test func preexistingCommandControlOrOptionPreservesFnCombination() {
        var router = FnStateMachine(shortcut: dictation)
        #expect(router.handle(.fnDown(shift: false, hasOtherModifiers: true)) == .init())
        #expect(router.handle(.chord) == .init())
        #expect(router.handle(.fnUp) == .init())
    }

    @Test func changingProviderCancelsCurrentGestureAndNextPressUsesNewBinding() {
        var router = FnStateMachine(shortcut: dictation)
        _ = router.handle(.fnDown(shift: false, hasOtherModifiers: false))
        #expect(router.update(shortcut: translation) == [.pressChanged(false)])
        #expect(router.handle(.fnUp) == .init(consume: true))
        _ = router.handle(.fnDown(shift: false, hasOtherModifiers: false))
        #expect(router.handle(.fnUp) == .init(consume: true, effects: [.pressChanged(false), .pulse(translation)]))
    }

    @Test func stoppingDuringFnRestoresPhysicalFnWithoutDispatch() {
        var router = FnStateMachine(shortcut: dictation)
        _ = router.handle(.fnDown(shift: false, hasOtherModifiers: false))
        #expect(router.stop() == [.pressChanged(false), .restoreFnDown])
        #expect(router.stop() == [])
    }

    @Test func tapInterruptionCancelsHeldGestureUntilPhysicalRelease() {
        var router = FnStateMachine(shortcut: dictation)
        _ = router.handle(.fnDown(shift: false, hasOtherModifiers: false))
        #expect(router.interrupt(fnIsDown: true) == [.pressChanged(false)])
        #expect(router.handle(.fnDown(shift: false, hasOtherModifiers: false)) == .init(consume: true))
        #expect(router.handle(.fnUp) == .init(consume: true))
        #expect(router.handle(.fnDown(shift: false, hasOtherModifiers: false)) == .init(consume: true, effects: [.pressChanged(true)]))
    }

    @Test func lostReleaseDuringInterruptionAllowsNextGesture() {
        var router = FnStateMachine(shortcut: dictation)
        _ = router.handle(.fnDown(shift: false, hasOtherModifiers: false))
        #expect(router.interrupt(fnIsDown: false) == [.pressChanged(false)])
        #expect(router.handle(.fnDown(shift: false, hasOtherModifiers: false)) == .init(consume: true, effects: [.pressChanged(true)]))
    }

    @Test func interruptedPassthroughStillGetsItsPhysicalRelease() {
        var router = FnStateMachine(shortcut: dictation)
        _ = router.handle(.fnDown(shift: false, hasOtherModifiers: true))
        #expect(router.interrupt(fnIsDown: true) == [])
        #expect(router.handle(.fnUp) == .init())
    }

    @Test func modifierOnlyProviderBindingIsDispatchedAsOnePulse() {
        let binding = Shortcut(keyCode: UInt16.max, key: "", shift: true, command: false)
        var router = FnStateMachine(shortcut: binding)
        _ = router.handle(.fnDown(shift: false, hasOtherModifiers: false))
        #expect(router.handle(.fnUp) == .init(consume: true, effects: [.pressChanged(false), .pulse(binding)]))
    }
}
