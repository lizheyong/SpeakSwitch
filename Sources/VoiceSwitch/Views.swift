import AppKit
import SwiftUI
import VoiceSwitchCore

private typealias ViewState<Value> = SwiftUI.State<Value>

enum Palette {
    static let paper = Color(hex: "FAF9F5")
    static let shell = Color(hex: "F0EEE6")
    static let surface = Color(hex: "FFFFFF")
    static let ink = Color(hex: "292824")
    static let secondary = Color(hex: "6F6C63")
    static let dark = Color(hex: "33312D")
    static let line = Color(hex: "E3E0D7")
    static let clay = Color(hex: "D97757")
    static let accentText = Color(hex: "A5482C")
    static let hover = Color(hex: "E9E6DD")
    static let mint = shell

    static func headingFont(_ size: CGFloat) -> Font {
        .custom("Songti SC", size: size)
    }
}

private enum Destination: String, CaseIterable {
    case providers = "我的输入法"
    case vocabulary = "共享词库"
    case guide = "接入指南"
    case settings = "设置"

    var symbol: String {
        switch self {
        case .providers: return "waveform"
        case .vocabulary: return "text.book.closed"
        case .guide: return "book.closed"
        case .settings: return "slider.horizontal.3"
        }
    }
}

struct MainContentView: View {
    @ObservedObject var store: AppStore
    @ViewState private var destination: Destination = .providers
    @ViewState private var editingProvider: Provider?

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    switch destination {
                    case .providers: providersPage
                    case .vocabulary: VocabularyView(store: store.vocabulary)
                    case .guide: guidePage
                    case .settings: settingsPage
                    }
                }
                .padding(.horizontal, 32)
                .padding(.top, 28)
                .padding(.bottom, 28)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .id(destination)
            .background(Palette.paper)
        }
        .font(.system(size: 14))
        .foregroundStyle(Palette.ink)
        .frame(minWidth: 900, minHeight: 650)
        .preferredColorScheme(.light)
        .sheet(item: $editingProvider) { provider in
            ProviderSetupView(store: store, provider: provider)
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "waveform")
                    .font(.system(size: 23, weight: .medium))
                    .foregroundStyle(Palette.clay)
                    .frame(width: 32, height: 36)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Voice Switch").font(.system(size: 16, weight: .semibold))
                    Text("One Fn. Any voice.")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 34)

            VStack(spacing: 5) {
                ForEach(Destination.allCases, id: \.self) { item in
                    SidebarItem(destination: item, selected: destination == item) {
                        destination = item
                    }
                }
            }

            Spacer(minLength: 36)

            VStack(alignment: .leading, spacing: 8) {
                Text("换个声音，\n习惯不变。")
                    .font(Palette.headingFont(23))
                    .lineSpacing(4)
                Text("一个 Fn，连接你喜欢的语音工具。")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.secondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 11)
            .padding(.bottom, 24)

            Rectangle().fill(Palette.line).frame(height: 1)
                .padding(.horizontal, 10)

            HStack(spacing: 9) {
                Circle()
                    .fill(store.isListening ? Palette.clay : Palette.secondary.opacity(0.45))
                    .frame(width: 6, height: 6)
                VStack(alignment: .leading, spacing: 4) {
                    Text(fnStatus).font(.system(size: 13, weight: .medium))
                    Text(store.isListening ? "点按开始，再按结束" : "统一 Fn 按键")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.secondary)
                }
                Spacer(minLength: 4)
                Toggle("启用 Fn", isOn: Binding(get: { store.isEnabled }, set: { store.setEnabled($0) }))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(Palette.dark)
                    .controlSize(.small)
                    .help("开启或暂停统一 Fn 按键")
            }
            .padding(.horizontal, 10)
            .padding(.top, 18)
        }
        .padding(.horizontal, 14)
        .padding(.top, 30)
        .padding(.bottom, 22)
        .frame(width: 220)
        .background(Palette.shell)
    }

    private var fnStatus: String {
        if store.isListening { return "Fn 已就绪" }
        return store.isEnabled ? "等待完成接入" : "Fn 已暂停"
    }

    @ViewBuilder
    private var providersPage: some View {
        HStack(alignment: .center, spacing: 16) {
            pageHeading("我的输入法", subtitle: "选一个声音，继续用熟悉的 Fn。")
            Spacer(minLength: 4)
            Button(action: store.addApplication) {
                Label("添加应用", systemImage: "plus")
            }
            .buttonStyle(OutlineButtonStyle())
        }

        currentProvider

        if !store.hasAccessibility || !store.hasInputMonitoring {
            permissionNotice
        } else if let message = store.message, !message.isEmpty {
            HStack(alignment: .top, spacing: 9) {
                Image(systemName: "info.circle").padding(.top, 2)
                Text(message).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
            }
            .font(.system(size: 12))
            .foregroundStyle(Palette.secondary)
        }

        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                sectionHeading("已接入", count: store.configuredProviders.count)
                Spacer()
                Button(action: store.refresh) {
                    Label("重新检测", systemImage: "arrow.clockwise")
                }
                .buttonStyle(TextActionStyle())
            }
            if store.configuredProviders.isEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    Text("从下方选一个应用开始。")
                        .font(.system(size: 14, weight: .medium))
                    Text("完成一次快捷键设置，就能随时切换。")
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.secondary)
                }
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .bottom) { Rectangle().fill(Palette.line).frame(height: 1) }
            } else {
                providerList(store.configuredProviders)
            }
        }

        if !moreProviders.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                sectionHeading("更多工具", count: moreProviders.count)
                providerList(moreProviders)
            }
        }

        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle").padding(.top, 1)
            Text("结束当前录音后再切换。应用保持常驻，声音和文本由原应用处理。")
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(3)
        }
        .font(.system(size: 12))
        .foregroundStyle(Palette.secondary)
    }

    private var moreProviders: [Provider] {
        let configuredIDs = Set(store.configuredProviders.map(\.id))
        let remaining = store.providers.filter { !configuredIDs.contains($0.id) }
        return remaining.filter { store.isInstalled($0) } + remaining.filter { !store.isInstalled($0) }
    }

    private func providerList(_ providers: [Provider]) -> some View {
        VStack(spacing: 0) {
            ForEach(providers) { provider in
                ProviderRow(store: store, provider: provider) { editingProvider = provider }
                Rectangle().fill(Palette.line).frame(height: 1).padding(.leading, 54)
            }
        }
    }

    private func sectionHeading(_ title: String, count: Int) -> some View {
        HStack(spacing: 7) {
            Text(title).font(.system(size: 13, weight: .semibold))
            Text("\(count)")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Palette.secondary)
        }
    }

    private var currentProvider: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 7) {
                    Text("当前输入法")
                    Circle().fill(store.isListening ? Palette.clay : Palette.secondary.opacity(0.5))
                        .frame(width: 5, height: 5)
                    Text(fnStatus)
                }
                .font(.system(size: 12))
                .foregroundStyle(Palette.secondary)

                HStack(spacing: 10) {
                    if let provider = store.selectedProvider {
                        ProviderIcon(provider: provider, size: 30)
                        Text(provider.name).font(.system(size: 25, weight: .medium))
                    } else {
                        Text("给 Fn 选一个声音")
                            .font(Palette.headingFont(26))
                    }
                    Spacer(minLength: 0)
                }

                HStack(spacing: 7) {
                    KeyLabel(text: "Fn")
                    Text("开始 / 结束")
                    Text("·").padding(.horizontal, 2)
                    KeyLabel(text: "⇧ Fn")
                    Text(store.selectedProvider?.translationShortcut == nil ? "翻译待接入" : "翻译")
                }
                .font(.system(size: 12))
                .foregroundStyle(Palette.secondary)
            }
            Spacer(minLength: 0)
            FnKeyView(pressed: store.isPressing)
                .accessibilityLabel(store.isPressing ? "Fn 按下" : "Fn 按键")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Palette.shell.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var permissionNotice: some View {
        HStack(spacing: 12) {
            Image(systemName: "hand.raised").font(.system(size: 18))
                .foregroundStyle(Palette.accentText)
            VStack(alignment: .leading, spacing: 5) {
                Text("完成授权，启用 Fn").font(.system(size: 13, weight: .medium))
                Text("需要辅助功能与输入监控权限。")
                    .font(.system(size: 12)).foregroundStyle(Palette.secondary)
            }
            Spacer(minLength: 8)
            Button("去设置") { destination = .settings }
                .buttonStyle(OutlineButtonStyle(compact: true))
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var guidePage: some View {
        pageHeading("一个 Fn，怎么接入？", subtitle: "一次设置，把熟悉的按键交给喜欢的声音。")

        HStack(spacing: 16) {
            FnKeyView(pressed: false, small: true)
            Image(systemName: "arrow.right").foregroundStyle(Palette.secondary)
            VStack(alignment: .leading, spacing: 6) {
                Text("Voice Switch").font(.system(size: 16, weight: .medium))
                Text("将 Fn 传递为当前应用的专属快捷键。")
                    .font(.system(size: 13)).foregroundStyle(Palette.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 8)

        VStack(alignment: .leading, spacing: 25) {
            GuideStep(number: "01", title: "把 Fn 腾出来", text: "在每个语音应用中，移除语音输入、翻译、指令等功能对 Fn 的占用。系统键盘设置中，将“按下 🌐 键时”设为“不执行操作”。") {
                Button("打开键盘设置", action: store.openKeyboardSettings)
                    .buttonStyle(TextActionStyle())
            }
            Rectangle().fill(Palette.line).frame(height: 1).padding(.leading, 40)
            GuideStep(number: "02", title: "给应用一个专属快捷键", text: "在“我的输入法”中点击接入，将显示的组合键设为原应用的语音快捷键。也可以录制自己的组合键，两边保持一致。") {
                Button("前往我的输入法") { destination = .providers }
                    .buttonStyle(TextActionStyle())
            }
            Rectangle().fill(Palette.line).frame(height: 1).padding(.leading, 40)
            GuideStep(number: "03", title: "Fn 说话，Shift + Fn 翻译", text: "在原应用中选择点按模式。按一下 Fn 开始，再按一下结束。支持语音翻译的应用，可以另设一个翻译快捷键，用 Shift + Fn 唤起。") {
                Text("结束当前录音后再切换。Fn + 方向键等系统组合键仍可使用。")
                    .font(.system(size: 12)).foregroundStyle(Palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }

        VStack(alignment: .leading, spacing: 10) {
            Text("接入前，确认这两件事")
                .font(.system(size: 14, weight: .medium))
            Text("应用需要支持自定义全局语音快捷键。检测到已安装后，仍需完成设置并实际按 Fn 测试。豆包、微信等预设是接入模板，兼容性以当前版本的实际行为为准。")
            Text("免费额度、订阅与模型在原应用中管理。你可以在备注中记录额度和使用习惯。")
        }
        .font(.system(size: 13))
        .foregroundStyle(Palette.secondary)
        .lineSpacing(4)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var settingsPage: some View {
        pageHeading("设置", subtitle: "让 Fn 安静地融入你的 Mac。")

        settingsSection("系统权限", caption: "只监听按键并发送快捷键，不录音、不读取转写文本。") {
            settingRow(symbol: "hand.raised", title: "辅助功能", subtitle: "向语音应用发送专属快捷键。") {
                permissionButton(granted: store.hasAccessibility, action: store.requestAccessibility)
            }
            Rectangle().fill(Palette.line).frame(height: 1)
            settingRow(symbol: "keyboard", title: "输入监控", subtitle: "接收 Fn 与 Shift + Fn。授权后请重新打开应用。") {
                permissionButton(granted: store.hasInputMonitoring, action: store.requestInputMonitoring)
            }
        }

        settingsSection("使用习惯", caption: nil) {
            settingRow(symbol: "power", title: "登录时启动", subtitle: "登录 Mac 后自动准备好 Fn。") {
                Toggle("登录时启动", isOn: Binding(get: { store.launchAtLogin }, set: { store.setLaunchAtLogin($0) }))
                    .labelsHidden().toggleStyle(.switch).tint(Palette.dark).controlSize(.small)
            }
            Rectangle().fill(Palette.line).frame(height: 1)
            settingRow(symbol: "arrow.left.arrow.right", title: "快速切换输入法", subtitle: "按 ⌃⌥⌘Space 切换到下一个已接入应用。") {
                Toggle("快速切换", isOn: Binding(get: { store.hotkeyEnabled }, set: { store.setHotkeyEnabled($0) }))
                    .labelsHidden().toggleStyle(.switch).tint(Palette.dark).controlSize(.small)
            }
            Rectangle().fill(Palette.line).frame(height: 1)
            settingRow(symbol: "globe", title: "系统 Fn / 🌐 键", subtitle: "将“按下 🌐 键时”设为“不执行操作”。") {
                Button("打开设置", action: store.openKeyboardSettings)
                    .buttonStyle(OutlineButtonStyle(compact: true))
            }
        }

        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "waveform")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(Palette.clay)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 6) {
                Text("Voice Switch").font(.system(size: 14, weight: .medium))
                Text("One Fn. Any voice.").font(.system(size: 13)).foregroundStyle(Palette.secondary)
                Text("为 macOS 构建的开源语音切换器。设置保存在这台 Mac 上。")
                    .font(.system(size: 12)).foregroundStyle(Palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 6)
            Text("v0.1.0").font(.system(size: 12, design: .monospaced)).foregroundStyle(Palette.secondary)
        }
        .padding(.top, 6)

        if let message = store.message, !message.isEmpty {
            Text(message).font(.system(size: 13)).foregroundStyle(Palette.secondary)
                .lineSpacing(3).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func pageHeading(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(Palette.headingFont(30))
            Text(subtitle).font(.system(size: 13)).foregroundStyle(Palette.secondary)
        }
    }

    private func settingsSection<Content: View>(_ title: String, caption: String?, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.secondary)
            VStack(spacing: 0, content: content)
            if let caption {
                Text(caption).font(.system(size: 12)).foregroundStyle(Palette.secondary)
                    .lineSpacing(3).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func settingRow<Accessory: View>(symbol: String, title: String, subtitle: String, @ViewBuilder accessory: () -> Accessory) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).font(.system(size: 18)).frame(width: 25)
                .foregroundStyle(Palette.secondary)
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.system(size: 14, weight: .medium))
                Text(subtitle).font(.system(size: 12)).foregroundStyle(Palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            accessory()
        }
        .padding(.vertical, 17)
    }

    @ViewBuilder
    private func permissionButton(granted: Bool, action: @escaping () -> Void) -> some View {
        if granted {
            Label("已授权", systemImage: "checkmark.circle")
                .font(.system(size: 12)).foregroundStyle(Palette.secondary)
        } else {
            Button("去授权", action: action).buttonStyle(OutlineButtonStyle(compact: true))
        }
    }
}

private struct SidebarItem: View {
    let destination: Destination
    let selected: Bool
    let action: () -> Void
    @ViewState private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: destination.symbol)
                    .font(.system(size: 16, weight: .regular)).frame(width: 21)
                    .foregroundStyle(selected ? Palette.accentText : Palette.secondary)
                Text(destination.rawValue).font(.system(size: 14, weight: selected ? .medium : .regular))
                Spacer()
            }
            .padding(.horizontal, 13)
            .frame(height: 43)
            .background(selected ? Palette.paper : hovering ? Palette.hover : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct ProviderRow: View {
    @ObservedObject var store: AppStore
    let provider: Provider
    let onConfigure: () -> Void
    @ViewState private var hovering = false

    private var installed: Bool { store.isInstalled(provider) }
    private var selected: Bool { store.selectedID == provider.id }

    var body: some View {
        HStack(spacing: 10) {
            Button {
                if provider.isConfigured && installed { store.select(provider) }
                else { onConfigure() }
            } label: {
                HStack(spacing: 13) {
                    ProviderIcon(provider: provider, size: 37)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(provider.name).font(.system(size: 14, weight: .medium))
                        Text(provider.note.isEmpty ? provider.subtitle : provider.note)
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 4)
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if installed && provider.isConfigured {
                Button { store.select(provider) } label: {
                    if selected {
                        Label("当前", systemImage: "checkmark")
                            .foregroundStyle(Palette.accentText)
                    } else {
                        Text("切换").foregroundStyle(Palette.ink)
                    }
                }
                .buttonStyle(QuietButtonStyle())
                .help("选用 \(provider.name)")
            } else if installed {
                Text("已安装").font(.system(size: 12)).foregroundStyle(Palette.secondary)
                Button("接入", action: onConfigure)
                    .buttonStyle(OutlineButtonStyle(compact: true))
            } else {
                Button { store.openWebsite(provider) } label: {
                    HStack(spacing: 5) {
                        Text("获取")
                        Image(systemName: "arrow.up.right").font(.system(size: 10, weight: .medium))
                    }
                }
                .buttonStyle(QuietButtonStyle())
            }

            Button(action: onConfigure) {
                Image(systemName: "ellipsis").font(.system(size: 15, weight: .medium))
                    .frame(width: 28, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(hovering ? Palette.ink : Palette.secondary)
            .help("\(provider.name) 接入设置")
            .accessibilityLabel("\(provider.name) 接入设置")
        }
        .padding(.horizontal, 8)
        .frame(height: 66)
        .background(hovering ? Palette.shell.opacity(0.65) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .onHover { hovering = $0 }
    }
}

private struct ProviderSetupView: View {
    @ObservedObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @ViewState private var draft: Provider
    @ViewState private var confirmed: Bool
    @ViewState private var recording = false
    @ViewState private var recordingTranslation = false
    @ViewState private var showMessage = false

    init(store: AppStore, provider: Provider) {
        self.store = store
        _draft = State(initialValue: provider)
        _confirmed = State(initialValue: provider.isConfigured)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 13) {
                ProviderIcon(provider: draft, size: 43)
                VStack(alignment: .leading, spacing: 6) {
                    Text("接入 \(draft.name)").font(Palette.headingFont(26))
                    Text("一次设置，以后只需 Fn。")
                        .font(.system(size: 13)).foregroundStyle(Palette.secondary)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 12, weight: .medium))
                        .frame(width: 29, height: 29)
                }
                .buttonStyle(QuietButtonStyle())
                .help("关闭接入设置")
                .accessibilityLabel("关闭接入设置")
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 23)

            Rectangle().fill(Palette.line).frame(height: 1)

            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    GuideStep(number: "01", title: "释放原应用中的 Fn", text: "在所有语音应用中，移除语音、翻译、指令等功能对 Fn 的占用。系统键盘设置中，将“按下 🌐 键时”设为“不执行操作”。") {
                        HStack(spacing: 22) {
                            Button("打开应用设置") { store.openSettings(draft) }.buttonStyle(TextActionStyle())
                            Button("系统键盘设置", action: store.openKeyboardSettings).buttonStyle(TextActionStyle())
                        }
                    }

                    GuideStep(number: "02", title: "接入语音输入", text: dictationGuidance) {
                        VStack(alignment: .leading, spacing: 11) {
                            HStack(spacing: 14) {
                                Button {
                                    recordingTranslation = false
                                    recording.toggle()
                                } label: {
                                    shortcutLabel(recording ? "请按下组合键…" : draft.shortcut.display, recording: recording)
                                }
                                .buttonStyle(.plain)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(recording ? "Esc 取消录制" : "点击录制其他快捷键")
                                    Text("纯修饰键组合：按下后松开")
                                }
                                .font(.system(size: 12)).foregroundStyle(Palette.secondary)
                            }
                            .background(ShortcutCapture(shortcut: $draft.shortcut, recording: $recording).frame(width: 0, height: 0))
                            Text("原应用请选择点按开始 / 结束模式，以后只需点按 Fn。")
                                .font(.system(size: 12)).foregroundStyle(Palette.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    GuideStep(number: "03", title: "接入语音翻译 · 可选", text: "原应用支持语音翻译时，给它另设一个独立组合键。以后用 Shift + Fn 触发翻译。") {
                        VStack(alignment: .leading, spacing: 13) {
                            Toggle("此应用支持语音翻译，我要接入", isOn: Binding(
                                get: { draft.translationShortcut != nil },
                                set: { draft.translationShortcut = $0 ? suggestedTranslation : nil; recordingTranslation = false }
                            ))
                            .toggleStyle(.checkbox)
                            .font(.system(size: 13))
                            .tint(Palette.dark)

                            if draft.translationShortcut != nil {
                                HStack(spacing: 14) {
                                    Button {
                                        recording = false
                                        recordingTranslation.toggle()
                                    } label: {
                                        shortcutLabel(recordingTranslation ? "请按下组合键…" : (draft.translationShortcut?.display ?? ""), recording: recordingTranslation)
                                    }
                                    .buttonStyle(.plain)
                                    Text(recordingTranslation ? "Esc 取消录制" : "设为原应用的翻译快捷键")
                                        .font(.system(size: 12)).foregroundStyle(Palette.secondary)
                                }
                                .background(ShortcutCapture(shortcut: translationBinding, recording: $recordingTranslation).frame(width: 0, height: 0))
                            }
                        }
                    }

                    Rectangle().fill(Palette.line).frame(height: 1)

                    HStack {
                        if store.isInstalled(draft) {
                            Button("测试语音快捷键") { showMessage = true; store.testShortcut(draft) }
                                .buttonStyle(OutlineButtonStyle())
                        } else {
                            Button("定位已安装的应用…") { showMessage = true; store.locate(draft) }
                                .buttonStyle(OutlineButtonStyle())
                        }
                        Spacer()
                    }

                    VStack(alignment: .leading, spacing: 9) {
                        HStack(spacing: 8) {
                            Text("我的备注").font(.system(size: 13, weight: .medium))
                            Text("仅保存在本机").font(.system(size: 12)).foregroundStyle(Palette.secondary)
                        }
                        TextField("免费额度、常用语言、适合的场景…", text: $draft.note)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                            .padding(12)
                            .background(Palette.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Palette.line, lineWidth: 1))
                    }

                    if draft.id == "doubao" || draft.id == "wetype" {
                        Text("此预设为接入模板。请确认当前版本支持自定义全局语音快捷键，并实际测试。")
                            .font(.system(size: 12)).foregroundStyle(Palette.secondary)
                            .lineSpacing(3).fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(28)
            }

            Rectangle().fill(Palette.line).frame(height: 1)

            VStack(alignment: .leading, spacing: 16) {
                if showMessage, let message = store.message, !message.isEmpty {
                    Text(message).font(.system(size: 12)).foregroundStyle(Palette.secondary)
                        .lineSpacing(3).fixedSize(horizontal: false, vertical: true)
                }

                Toggle(isOn: $confirmed) {
                    Text("已在原应用中设置好快捷键，并移除所有 Fn 占用")
                        .font(.system(size: 13))
                }
                .toggleStyle(.checkbox)
                .tint(Palette.dark)

                HStack(spacing: 10) {
                    if draft.isCustom {
                        Button("移除应用") { store.removeProvider(draft); dismiss() }
                            .buttonStyle(QuietButtonStyle())
                    } else if !store.isInstalled(draft) {
                        Button("获取 \(draft.name)") { store.openWebsite(draft) }
                            .buttonStyle(TextActionStyle())
                    }
                    Spacer()
                    Button("取消") { dismiss() }.buttonStyle(OutlineButtonStyle())
                    Button(confirmed ? "保存并选用" : "保存设置") {
                        draft.isConfigured = confirmed
                        showMessage = true
                        if store.saveProvider(draft) {
                            if confirmed { store.select(draft) }
                            dismiss()
                        }
                    }
                    .buttonStyle(SolidButtonStyle())
                    .disabled(recording || recordingTranslation)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 20)
        }
        .frame(width: 620, height: 660)
        .foregroundStyle(Palette.ink)
        .background(Palette.paper)
        .onChange(of: draft.shortcut) { _ in confirmed = false }
        .onChange(of: draft.translationShortcut) { _ in confirmed = false }
        .onChange(of: store.providers) { providers in
            if let provider = providers.first(where: { $0.id == draft.id }) {
                if draft.appPath != provider.appPath || draft.bundleIDs != provider.bundleIDs { confirmed = false }
                draft.appPath = provider.appPath
                draft.bundleIDs = provider.bundleIDs
            }
        }
        .onAppear { store.beginSetup() }
        .onDisappear { store.endSetup() }
    }

    private var dictationGuidance: String {
        if draft.id == "chatterfly" {
            return "将下面的组合键设为 Chatterfly 的语音快捷键，最多使用 3 个修饰键。"
        }
        if draft.id == "typeless" {
            return "将下面的组合键设为 Typeless 的语音快捷键，修饰键和普通键合计最多 3 个。"
        }
        return "将下面的组合键设为 \(draft.name) 的全局语音快捷键。"
    }

    private func shortcutLabel(_ text: String, recording: Bool) -> some View {
        Text(text)
            .font(.system(size: 19, weight: .medium, design: .monospaced))
            .foregroundStyle(recording ? Palette.accentText : Palette.ink)
            .frame(minWidth: 132, minHeight: 45)
            .padding(.horizontal, 14)
            .background(Palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(recording ? Palette.clay : Palette.line, lineWidth: recording ? 1.5 : 1))
    }

    private var suggestedTranslation: Shortcut { draft.suggestedTranslationShortcut }

    private var translationBinding: Binding<Shortcut> {
        Binding(get: { draft.translationShortcut ?? suggestedTranslation }, set: { draft.translationShortcut = $0 })
    }
}

private struct GuideStep<Accessory: View>: View {
    let number: String
    let title: String
    let text: String
    @ViewBuilder var accessory: () -> Accessory

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(number)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(Palette.accentText)
                .frame(width: 26, height: 21, alignment: .leading)
            VStack(alignment: .leading, spacing: 9) {
                Text(title).font(.system(size: 14, weight: .medium))
                Text(text)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.secondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                accessory().padding(.top, 3)
            }
        }
    }
}

private struct KeyLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Palette.paper)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

private struct FnKeyView: View {
    var pressed: Bool
    var small = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let size: CGFloat = small ? 54 : 74
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: "globe")
                .font(.system(size: small ? 11 : 13, weight: .regular))
                .foregroundStyle(Palette.secondary)
            Spacer(minLength: 3)
            Text("fn")
                .font(.system(size: small ? 23 : 29, weight: .regular, design: .rounded))
                .foregroundStyle(Palette.ink)
        }
        .padding(small ? 10 : 13)
        .frame(width: size, height: size, alignment: .leading)
        .background(Palette.paper)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.line, lineWidth: 1))
        .shadow(color: Palette.ink.opacity(0.09), radius: 0, x: 0, y: pressed ? 1 : 4)
        .offset(y: pressed ? 3 : 0)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: pressed)
    }
}

struct MenuContentView: View {
    @ObservedObject var store: AppStore
    let onOpen: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Voice Switch").font(.system(size: 16, weight: .medium))
                    Text("One Fn. Any voice.").font(.system(size: 12)).foregroundStyle(Palette.secondary)
                }
                Spacer()
                FnKeyView(pressed: store.isPressing, small: true)
            }
            .padding(20)

            Rectangle().fill(Palette.line).frame(height: 1).padding(.horizontal, 20)

            if store.configuredProviders.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("给 Fn 选一个声音").font(Palette.headingFont(23))
                    Text("打开 Voice Switch，完成一次接入。")
                        .font(.system(size: 13)).foregroundStyle(Palette.secondary)
                }
                .padding(20)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("切换输入法").font(.system(size: 12)).foregroundStyle(Palette.secondary)
                        .padding(.horizontal, 10)
                        .padding(.bottom, 3)
                    ForEach(store.configuredProviders) { provider in
                        MenuProviderButton(provider: provider, selected: store.selectedID == provider.id) {
                            store.select(provider)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 15)
            }

            Rectangle().fill(Palette.line).frame(height: 1).padding(.horizontal, 20)

            HStack(spacing: 8) {
                Circle().fill(store.isListening ? Palette.clay : Palette.secondary.opacity(0.45))
                    .frame(width: 6, height: 6)
                Text(store.isListening ? "Fn 已就绪" : store.isEnabled ? "等待完成接入" : "Fn 已暂停")
                    .font(.system(size: 13)).foregroundStyle(Palette.secondary)
                Spacer()
                Toggle("启用 Fn", isOn: Binding(get: { store.isEnabled }, set: { store.setEnabled($0) }))
                    .labelsHidden().toggleStyle(.switch).controlSize(.small).tint(Palette.dark)
            }
            .padding(.horizontal, 20).padding(.vertical, 15)

            HStack {
                Button(action: onOpen) {
                    Label("打开 Voice Switch", systemImage: "slider.horizontal.3")
                }
                .buttonStyle(QuietButtonStyle())
                Spacer()
                Button(action: onQuit) {
                    Image(systemName: "power").frame(width: 25, height: 24)
                }
                .buttonStyle(QuietButtonStyle())
                .help("退出 Voice Switch")
                .accessibilityLabel("退出 Voice Switch")
            }
            .padding(.horizontal, 10).padding(.vertical, 10)
            .background(Palette.shell)
        }
        .foregroundStyle(Palette.ink)
        .frame(width: 320)
        .background(Palette.paper)
        .preferredColorScheme(.light)
    }
}

private struct MenuProviderButton: View {
    let provider: Provider
    let selected: Bool
    let action: () -> Void
    @ViewState private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                ProviderIcon(provider: provider, size: 30)
                Text(provider.name).font(.system(size: 14, weight: .medium))
                Spacer()
                if selected {
                    Image(systemName: "checkmark").font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Palette.accentText)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 46)
            .background(selected ? Palette.shell : hovering ? Palette.hover : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct ShortcutCapture: NSViewRepresentable {
    @Binding var shortcut: Shortcut
    @Binding var recording: Bool

    func makeNSView(context: Context) -> CaptureView { CaptureView() }

    func updateNSView(_ nsView: CaptureView, context: Context) {
        nsView.onKey = { event in
            if event.keyCode == 53 { recording = false; return }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let names: [UInt16: String] = [36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 117: "⌦", 123: "←", 124: "→", 125: "↓", 126: "↑"]
            let label = names[event.keyCode] ?? event.charactersIgnoringModifiers?.uppercased() ?? "Key \(event.keyCode)"
            shortcut = Shortcut(keyCode: event.keyCode, key: label, control: flags.contains(.control), option: flags.contains(.option), shift: flags.contains(.shift), command: flags.contains(.command))
            recording = false
        }
        nsView.onModifiers = { flags in
            shortcut = Shortcut(keyCode: UInt16.max, key: "", control: flags.contains(.control), option: flags.contains(.option), shift: flags.contains(.shift), command: flags.contains(.command))
            recording = false
        }
        if nsView.recording != recording { nsView.heldModifiers = [] }
        nsView.recording = recording
        if recording {
            DispatchQueue.main.async { nsView.window?.makeFirstResponder(nsView) }
        } else if nsView.window?.firstResponder === nsView {
            nsView.window?.makeFirstResponder(nil)
        }
    }

    final class CaptureView: NSView {
        var recording = false
        var onKey: ((NSEvent) -> Void)?
        var onModifiers: ((NSEvent.ModifierFlags) -> Void)?
        var heldModifiers: NSEvent.ModifierFlags = []
        override var acceptsFirstResponder: Bool { true }
        override func keyDown(with event: NSEvent) {
            if recording { onKey?(event) } else { super.keyDown(with: event) }
        }
        override func performKeyEquivalent(with event: NSEvent) -> Bool {
            if recording { onKey?(event); return true }
            return super.performKeyEquivalent(with: event)
        }
        override func flagsChanged(with event: NSEvent) {
            if !recording { super.flagsChanged(with: event); return }
            let flags = event.modifierFlags.intersection([.control, .option, .shift, .command])
            if flags.isEmpty {
                if !heldModifiers.isEmpty { onModifiers?(heldModifiers) }
            } else if flags.rawValue.nonzeroBitCount >= heldModifiers.rawValue.nonzeroBitCount {
                heldModifiers = flags
            }
        }
    }
}

struct OutlineButtonStyle: ButtonStyle {
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        ButtonSurface(kind: .outline, compact: compact, isPressed: configuration.isPressed) {
            configuration.label
        }
    }
}

struct SolidButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        ButtonSurface(kind: .solid, compact: false, isPressed: configuration.isPressed) {
            configuration.label
        }
    }
}

struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        ButtonSurface(kind: .quiet, compact: true, isPressed: configuration.isPressed) {
            configuration.label
        }
    }
}

struct TextActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Palette.accentText.opacity(configuration.isPressed ? 0.65 : 1))
            .padding(.vertical, 3)
            .contentShape(Rectangle())
    }
}

private struct ButtonSurface<Label: View>: View {
    enum Kind { case outline, solid, quiet }
    let kind: Kind
    let compact: Bool
    let isPressed: Bool
    @ViewBuilder var label: () -> Label
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ViewState private var hovering = false

    var body: some View {
        label()
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, kind == .quiet ? 8 : compact ? 11 : 14)
            .frame(height: compact ? 31 : 36)
            .foregroundStyle(kind == .solid ? Palette.paper : Palette.ink)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay {
                if kind == .outline {
                    RoundedRectangle(cornerRadius: 7).stroke(Palette.line, lineWidth: 1)
                }
            }
            .opacity(isEnabled ? 1 : 0.45)
            .contentShape(Rectangle())
            .onHover { hovering = $0 }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: hovering)
    }

    private var background: Color {
        switch kind {
        case .solid: return Palette.dark.opacity(isPressed ? 0.78 : hovering ? 0.9 : 1)
        case .outline: return isPressed || hovering ? Palette.hover : Palette.surface.opacity(0.5)
        case .quiet: return isPressed || hovering ? Palette.hover : .clear
        }
    }
}

private extension Color {
    init(hex: String) {
        let value = UInt64(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0
        self.init(.sRGB, red: Double((value >> 16) & 0xff) / 255, green: Double((value >> 8) & 0xff) / 255, blue: Double(value & 0xff) / 255, opacity: 1)
    }
}
