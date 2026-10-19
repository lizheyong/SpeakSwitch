import Foundation
import Testing
import VoiceSwitchCore
@testable import VoiceSwitch

@Suite struct FnPreflightTests {
    @Test func installedOrReviewedDoesNotOverrideObservedConflict() throws {
        let snapshot = try ShortcutSnapshot.typeless(Data(#"{"featureShortcutBindings":{"dictationMode":["Fn"]}}"#.utf8))
        let check = FnCheck(id: "typeless", name: "Typeless", applicationURL: nil, version: "1", instructions: "", snapshot: snapshot, manuallyReviewed: true)
        #expect(check.hasConflict)
        #expect(check.needsReview)
        #expect(check.status == "检测到 Fn 绑定")
    }

    @Test func manualReviewAndReadEvidenceHaveDifferentLabels() {
        let pending = FnCheck(id: "lark", name: "飞书", applicationURL: nil, version: "1", instructions: "", snapshot: nil, manuallyReviewed: false)
        let reviewed = FnCheck(id: "lark", name: "飞书", applicationURL: nil, version: "1", instructions: "", snapshot: nil, manuallyReviewed: true)
        #expect(pending.needsReview)
        #expect(!reviewed.needsReview)
        #expect(reviewed.status == "已手动确认")
        let updated = FnCheck(id: "lark", name: "飞书", applicationURL: nil, version: "2", instructions: "", snapshot: nil, manuallyReviewed: false)
        #expect(updated.reviewKey != reviewed.reviewKey)
    }
}
