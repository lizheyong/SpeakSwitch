import Foundation
import Testing
@testable import VoiceSwitchCore

@Suite struct VocabularyTests {
    @Test func textImportAcceptsChineseAndPhrasesAcrossLineEndings() {
        let entries = VocabularyCodec.importText("\u{FEFF} 灵镜 \r\n\nVoice Switch\rOne Fn\n灵镜\n ")
        #expect(entries.map(\.term) == ["灵镜", "Voice Switch", "One Fn"])
    }

    @Test func csvAcceptsBOMCRLFAndQuotedPunctuation() throws {
        let csv = "\u{FEFF}灵镜\r\n\"ACME, Inc.\"\r\n\"say \"\"hello\"\"\"\r\n\r\n"
        let entries = try VocabularyCodec.importCSV(csv)
        #expect(entries.map(\.term) == ["灵镜", "ACME, Inc.", "say \"hello\""])
    }

    @Test func csvHasNoHeaderAndKeepsLiteralHeaderLikeTerms() throws {
        let entries = [VocabularyEntry(term: "word"), VocabularyEntry(term: "热词")]
        #expect(VocabularyCodec.exportCSV(entries) == "word\n热词")
        #expect(try VocabularyCodec.importCSV("word\n热词").map(\.term) == ["word", "热词"])
    }

    @Test func csvQuotedMultilineTermRoundTrips() throws {
        let terms = ["第一行\r\n第二行", "名字, \"代号\"", "C++ / C#"]
        let csv = VocabularyCodec.exportCSV(terms.map { VocabularyEntry(term: $0) })
        #expect(try VocabularyCodec.importCSV(csv).map(\.term) == terms)
    }

    @Test func csvTrimsOuterWhitespaceAndSkipsBlankRows() throws {
        let csv = " \n\t\" 灵镜 \" \t\r\n\"\"\r\n  Voice Switch  \r\n"
        #expect(try VocabularyCodec.importCSV(csv).map(\.term) == ["灵镜", "Voice Switch"])
    }

    @Test func csvRejectsExtraColumnsIncludingAnEmptySecondColumn() {
        #expect(throws: VocabularyCodec.CSVError.multipleColumns(line: 2)) {
            try VocabularyCodec.importCSV("灵镜\nword,note")
        }
        #expect(throws: VocabularyCodec.CSVError.multipleColumns(line: 1)) {
            try VocabularyCodec.importCSV("\"ACME, Inc.\",")
        }
    }

    @Test func csvRejectsIncompleteOrMisplacedQuotes() {
        for csv in ["\"unfinished", "bad\"quote", "\"word\" trailing"] {
            #expect(throws: VocabularyCodec.CSVError.malformedQuotes(line: 1)) {
                try VocabularyCodec.importCSV(csv)
            }
        }
    }

    @Test func mergeNormalizesUnicodeAndPreservesExistingIdsNotesAndOrder() {
        let first = VocabularyEntry(term: " Café ", note: "保留原来的备注")
        let second = VocabularyEntry(term: "灵镜", note: "产品名")
        let new = VocabularyEntry(term: "  Voice Switch  ", note: "新备注")
        let imported = [
            VocabularyEntry(term: "Cafe\u{301}", note: "不能覆盖原备注"),
            VocabularyEntry(term: "灵镜"), new,
            VocabularyEntry(term: "Voice Switch", note: "重复项"),
            VocabularyEntry(term: "\n \t")
        ]
        let merged = VocabularyCodec.merge(imported, into: [first, second])
        #expect(Array(merged.prefix(2)) == [first, second])
        #expect(merged.count == 3)
        #expect(merged[2] == VocabularyEntry(id: new.id, term: "Voice Switch", note: "新备注"))
    }

    @Test func canonicalDeduplicationRemainsCaseSensitive() {
        let entries = VocabularyCodec.importText("Cafe\u{301}\nCafé\ncafé\nCAFE")
        #expect(entries.map(\.term) == ["Café", "café", "CAFE"])
        #expect(Array(entries[0].term.unicodeScalars).last?.value == 0xE9)
    }

    @Test func restoringBackupAfterRenamingKeepsDistinctEntryIdentities() throws {
        let original = VocabularyEntry(term: "灵镜", note: "备份时的备注")
        let backup = try JSONEncoder().encode([original])
        var renamed = original
        renamed.term = "灵镜 AI"
        renamed.note = "本机更新后的备注"

        let restored = try JSONDecoder().decode([VocabularyEntry].self, from: backup)
        let merged = VocabularyCodec.merge(restored, into: [renamed])

        #expect(merged.count == 2)
        #expect(merged[0] == renamed)
        #expect(merged[1].term == original.term)
        #expect(merged[1].note == original.note)
        #expect(merged[1].id != renamed.id)
        #expect(merged.filter { $0.id != merged[1].id } == [renamed])
        #expect(VocabularyCodec.merge(restored, into: merged) == merged)
    }

    @Test func emptyImportKeepsEveryExistingEntryUnchanged() {
        let existing = [VocabularyEntry(term: "灵镜", note: "第一条"), VocabularyEntry(term: "灵镜", note: "第二条")]
        #expect(VocabularyCodec.merge([], into: existing) == existing)
        #expect(VocabularyCodec.merge(VocabularyCodec.importText(" \n"), into: existing) == existing)
    }

    @Test func plainTextExportContainsTermsWithoutNotes() {
        let entries = [VocabularyEntry(term: "灵镜", note: "产品名"), VocabularyEntry(term: "Voice Switch")]
        #expect(VocabularyCodec.exportText(entries) == "灵镜\nVoice Switch")
    }
}
