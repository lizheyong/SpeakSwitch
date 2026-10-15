import Carbon
import Foundation

/// WeType handles its voice shortcut only while its input mode is current.
enum WeTypeInputSource {
    enum SelectionError: LocalizedError {
        case unavailable
        case failed(OSStatus)

        var errorDescription: String? {
            switch self {
            case .unavailable:
                return "微信输入法尚未在系统输入源中启用。请在系统设置 → 键盘 → 文本输入中添加微信输入法，再选用它。"
            case .failed(let status):
                return "无法切换到微信输入法（系统错误 \(status)）。请在菜单栏输入法菜单中选择微信输入法后重试。"
            }
        }
    }

    static func select() throws {
        let filter = [
            kTISPropertyBundleID as String: "com.tencent.inputmethod.wetype",
            kTISPropertyInputSourceCategory as String: kTISCategoryKeyboardInputSource as String,
            kTISPropertyInputSourceIsSelectCapable as String: true
        ] as [String: Any]
        let sources = TISCreateInputSourceList(filter as CFDictionary, false).takeRetainedValue() as! [TISInputSource]
        guard let source = sources.first else { throw SelectionError.unavailable }
        let status = TISSelectInputSource(source)
        guard status == noErr else { throw SelectionError.failed(status) }
    }
}
