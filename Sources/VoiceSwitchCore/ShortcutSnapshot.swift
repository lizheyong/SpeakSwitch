import Foundation

/// Only shortcut fields are decoded; account, history and transcript fields are ignored.
public struct ShortcutSnapshot: Equatable, Sendable {
    public struct Binding: Equatable, Sendable {
        public var action: String
        public var keys: [String]
        public init(_ action: String, _ keys: [String]) {
            self.action = action; self.keys = keys
        }
    }
    public var bindings: [Binding]
    public var dictation: Shortcut?
    public var translation: Shortcut?

    public var fnBindings: [Binding] {
        bindings.filter { binding in
            binding.keys.contains { key in
                key.split(separator: "+").contains { ["fn", "globe"].contains($0.lowercased()) }
            }
        }
    }

    public static func typeless(_ data: Data) throws -> Self {
        struct Settings: Decodable { let featureShortcutBindings: [String: [String]] }
        let values = try JSONDecoder().decode(Settings.self, from: data).featureShortcutBindings
        guard values["dictationMode"] != nil else { throw CocoaError(.fileReadCorruptFile) }
        let names = ["dictationMode": "语音输入", "translationMode": "翻译", "askAnythingMode": "随便问", "pasteLastTranscript": "粘贴上次转写"]
        return Self(
            bindings: values.keys.sorted().map { Binding(names[$0] ?? $0, values[$0]!) },
            dictation: values["dictationMode"]?.compactMap(parse).first,
            translation: values["translationMode"]?.compactMap(parse).first
        )
    }

    public static func bageshuo(_ data: Data) throws -> Self {
        struct Store: Decodable { let settings: Settings }
        struct Settings: Decodable {
            let polishHotkey: String?
            let translateHotkey: String?
            let askHotkey: String?
            let polishHotkeys: [String]?
            let translateHotkeys: [String]?
            let askHotkeys: [String]?
        }
        let settings = try JSONDecoder().decode(Store.self, from: data).settings
        func keys(_ plural: [String]?, _ singular: String?) -> [String] {
            plural ?? singular.map { [$0] } ?? []
        }
        let dictation = keys(settings.polishHotkeys, settings.polishHotkey)
        let translation = keys(settings.translateHotkeys, settings.translateHotkey)
        let ask = keys(settings.askHotkeys, settings.askHotkey)
        // An unrecognized schema is not evidence that Fn has been released.
        guard settings.polishHotkeys != nil || settings.polishHotkey != nil else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return Self(bindings: [Binding("语音润色", dictation), Binding("翻译", translation), Binding("随便问", ask)],
                    dictation: dictation.compactMap(parse).first, translation: translation.compactMap(parse).first)
    }

    /// Import combinations whose physical keys can be represented by our sender.
    public static func parse(_ value: String) -> Shortcut? {
        let codes: [String: UInt16] = ["a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5,
            "z": 6, "x": 7, "c": 8, "v": 9, "b": 11, "q": 12, "w": 13, "e": 14,
            "r": 15, "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22,
            "5": 23, "9": 25, "7": 26, "8": 28, "0": 29, "o": 31, "u": 32,
            "i": 34, "p": 35, "l": 37, "j": 38, "k": 40, "n": 45, "m": 46, "space": 49]
        var shortcut = Shortcut(keyCode: .max, key: "", control: false, option: false, command: false)
        let tokens = value.lowercased().split(separator: "+").map(String.init)
        for token in tokens {
            switch token {
            case "ctrl", "control", "leftctrl", "leftcontrol": shortcut.control = true
            case "option", "alt", "leftoption", "leftalt": shortcut.option = true
            case "command", "cmd", "leftcmd", "leftcommand": shortcut.command = true
            case "shift", "leftshift": shortcut.shift = true
            default:
                guard shortcut.isModifierOnly, let code = codes[token] else { return nil }
                shortcut.keyCode = code
                shortcut.key = token == "space" ? "Space" : token.uppercased()
            }
        }
        guard shortcut.control || shortcut.option || shortcut.command || shortcut.shift else { return nil }
        return shortcut
    }
}
