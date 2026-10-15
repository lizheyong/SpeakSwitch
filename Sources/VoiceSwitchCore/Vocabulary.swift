import Foundation

public struct VocabularyEntry: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var term: String
    public var note: String

    public init(id: UUID = UUID(), term: String, note: String = "") {
        self.id = id
        self.term = term
        self.note = note
    }
}

public enum VocabularyCodec {
    public enum CSVError: LocalizedError, Equatable {
        case multipleColumns(line: Int)
        case malformedQuotes(line: Int)

        public var errorDescription: String? {
            switch self {
            case .multipleColumns(let line):
                return "CSV 第 \(line) 行包含多列。请使用每行一个词条的单列 CSV，含逗号的词条用双引号包住。"
            case .malformedQuotes(let line):
                return "CSV 第 \(line) 行的双引号格式不完整。词条内的双引号请写成两个连续双引号。"
            }
        }
    }

    public static func importText(_ text: String) -> [VocabularyEntry] {
        let entries = withoutBOM(text).components(separatedBy: .newlines)
            .map { VocabularyEntry(term: $0) }
        return merge(entries, into: [])
    }

    /// Typeless and Chatterfly accept one term per CSV row, without a header.
    public static func importCSV(_ text: String) throws -> [VocabularyEntry] {
        enum FieldState { case unquoted, quoted, afterQuote }
        let scalars = Array(withoutBOM(text).unicodeScalars)
        var state = FieldState.unquoted
        var field = ""
        var entries: [VocabularyEntry] = []
        var index = 0
        var line = 1
        var fieldLine = 1

        while index < scalars.count {
            let character = scalars[index]
            if state == .quoted {
                if character == "\"" {
                    if index + 1 < scalars.count, scalars[index + 1] == "\"" {
                        field.append("\"")
                        index += 1
                    } else {
                        state = .afterQuote
                    }
                } else {
                    field.unicodeScalars.append(character)
                }
            } else if character == "," {
                throw CSVError.multipleColumns(line: line)
            } else if character == "\r" || character == "\n" {
                entries.append(VocabularyEntry(term: field))
                field = ""
                state = .unquoted
                if character == "\r", index + 1 < scalars.count, scalars[index + 1] == "\n" {
                    index += 1
                }
                line += 1
                fieldLine = line
            } else if state == .afterQuote {
                if !CharacterSet.whitespaces.contains(character) {
                    throw CSVError.malformedQuotes(line: line)
                }
            } else if character == "\"" {
                guard field.trimmingCharacters(in: .whitespaces).isEmpty else {
                    throw CSVError.malformedQuotes(line: line)
                }
                field = ""
                fieldLine = line
                state = .quoted
            } else {
                field.unicodeScalars.append(character)
            }
            if state == .quoted, character == "\n" || (character == "\r" && (index + 1 == scalars.count || scalars[index + 1] != "\n")) {
                line += 1
            }
            index += 1
        }

        if state == .quoted { throw CSVError.malformedQuotes(line: fieldLine) }
        entries.append(VocabularyEntry(term: field))
        return merge(entries, into: [])
    }

    public static func exportCSV(_ entries: [VocabularyEntry]) -> String {
        merge(entries, into: []).map { entry in
            let term = entry.term
            if term.rangeOfCharacter(from: CharacterSet(charactersIn: ",\"\r\n")) != nil {
                return "\"" + term.replacingOccurrences(of: "\"", with: "\"\"") + "\""
            }
            return term
        }.joined(separator: "\n")
    }

    public static func exportText(_ entries: [VocabularyEntry]) -> String {
        merge(entries, into: []).map(\.term).joined(separator: "\n")
    }

    /// Existing entries retain their identity, text, and notes. New terms use
    /// canonical Unicode spelling and preserve their first appearance order.
    public static func merge(_ imported: [VocabularyEntry], into existing: [VocabularyEntry]) -> [VocabularyEntry] {
        var result = existing
        var seen = Set(existing.map { normalized($0.term) })
        var identities = Set(existing.map(\.id))
        for var entry in imported {
            entry.term = normalized(entry.term)
            if !entry.term.isEmpty, seen.insert(entry.term).inserted {
                if identities.contains(entry.id) { entry.id = UUID() }
                identities.insert(entry.id)
                result.append(entry)
            }
        }
        return result
    }

    private static func normalized(_ term: String) -> String {
        term.trimmingCharacters(in: .whitespacesAndNewlines).precomposedStringWithCanonicalMapping
    }

    private static func withoutBOM(_ text: String) -> String {
        text.hasPrefix("\u{FEFF}") ? String(text.dropFirst()) : text
    }
}
