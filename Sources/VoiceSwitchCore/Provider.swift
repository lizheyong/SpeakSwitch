import Foundation

public struct Shortcut: Codable, Equatable, Sendable {
    public var keyCode: UInt16
    public var key: String
    public var control: Bool
    public var option: Bool
    public var shift: Bool
    public var command: Bool

    public init(keyCode: UInt16, key: String, control: Bool = true, option: Bool = true, shift: Bool = false, command: Bool = true) {
        self.keyCode = keyCode; self.key = key; self.control = control
        self.option = option; self.shift = shift; self.command = command
    }

    public var display: String {
        (control ? "⌃" : "") + (option ? "⌥" : "") + (shift ? "⇧" : "") + (command ? "⌘" : "") + key
    }

    public var isModifierOnly: Bool { keyCode == UInt16.max }

    /// A modifier-only gesture also fires while a larger chord is being pressed.
    public func conflicts(with other: Shortcut) -> Bool {
        let lhs = [control, option, shift, command]
        let rhs = [other.control, other.option, other.shift, other.command]
        if keyCode == other.keyCode && lhs == rhs { return true }
        func isSubset(_ small: [Bool], _ large: [Bool]) -> Bool {
            zip(small, large).allSatisfy { !$0 || $1 }
        }
        return (isModifierOnly && isSubset(lhs, rhs)) || (other.isModifierOnly && isSubset(rhs, lhs))
    }
}

public struct Provider: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var subtitle: String
    public var symbol: String
    public var tint: String
    public var website: String
    public var bundleIDs: [String]
    public var appNames: [String]
    public var appPath: String?
    public var settingsBundleID: String?
    public var shortcut: Shortcut
    public var translationShortcut: Shortcut?
    public var isConfigured: Bool
    public var isCustom: Bool
    public var note: String

    public init(id: String, name: String, subtitle: String, symbol: String, tint: String, website: String, bundleIDs: [String], appNames: [String], appPath: String? = nil, settingsBundleID: String? = nil, shortcut: Shortcut, translationShortcut: Shortcut? = nil, isConfigured: Bool = false, isCustom: Bool = false, note: String = "") {
        self.id = id; self.name = name; self.subtitle = subtitle; self.symbol = symbol
        self.tint = tint; self.website = website; self.bundleIDs = bundleIDs
        self.appNames = appNames; self.appPath = appPath; self.settingsBundleID = settingsBundleID
        self.shortcut = shortcut; self.translationShortcut = translationShortcut
        self.isConfigured = isConfigured; self.isCustom = isCustom; self.note = note
    }

    public static let catalog: [Provider] = [
        .init(id: "typeless", name: "Typeless", subtitle: "自然表达，流畅成文", symbol: "waveform", tint: "6657D9", website: "https://www.typeless.com/", bundleIDs: ["now.typeless.desktop"], appNames: ["Typeless"], shortcut: .init(keyCode: 18, key: "1")),
        .init(id: "chatterfly", name: "Chatterfly", subtitle: "不必想好，开口就好", symbol: "sparkles", tint: "D57850", website: "https://chatterfly.tencent.com/", bundleIDs: ["com.tencent.inputmethod.chatterfly"], appNames: ["Chatterfly"], settingsBundleID: "com.tencent.ChatterflyPreference", shortcut: .init(keyCode: UInt16.max, key: "", shift: true, command: false)),
        .init(id: "doubao", name: "豆包输入法", subtitle: "轻声说，也能听得清", symbol: "bubble.left.and.text.bubble.right", tint: "477BD1", website: "https://shurufa.doubao.com/pc", bundleIDs: [], appNames: ["DoubaoIme", "豆包输入法"], shortcut: .init(keyCode: 20, key: "3")),
        .init(id: "wetype", name: "微信输入法", subtitle: "让表达更自然", symbol: "textformat.abc", tint: "429B6D", website: "https://z.weixin.qq.com/", bundleIDs: [], appNames: ["WeType", "微信输入法"], shortcut: .init(keyCode: 21, key: "4")),
        .init(id: "spokenly", name: "Spokenly", subtitle: "云端模型与本地听写", symbol: "mic", tint: "AD64C1", website: "https://spokenly.app/", bundleIDs: ["app.spokenly"], appNames: ["Spokenly"], shortcut: .init(keyCode: 23, key: "5")),
        .init(id: "shandian", name: "闪电说", subtitle: "随口说，帮你整理好", symbol: "bolt", tint: "B48C36", website: "https://shandianshuo.cn/", bundleIDs: [], appNames: ["闪电说", "Shandianshuo", "ShanDianShuo"], shortcut: .init(keyCode: 22, key: "6"))
    ]
}
