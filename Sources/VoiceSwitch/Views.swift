import AppKit
import SwiftUI
import VoiceSwitchCore

private typealias ViewState<Value> = SwiftUI.State<Value>

private enum Palette {
    static let paper = Color(hex: "F7F8F2")
    static let ink = Color(hex: "23332D")
    static let secondary = Color(hex: "7A847B")
    static let mint = Color(hex: "C2E8C7")
    static let dark = Color(hex: "21372D")
    static let line = Color(hex: "E2E6DC")
}

private enum Destination: String, CaseIterable {
    case providers = "我的输入法"
    case guide = "接入指南"
    case settings = "设置"

    var symbol: String {
        switch self {
        case .providers: return "waveform"
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
            ZStack(alignment: .topLeading) {
                Palette.paper
                ScrollView {
                    VStack(alignment: .leading, spacing: 27) {
                        switch destination {
                        case .providers: providersPage
                        case .guide: guidePage
                        case .settings: settingsPage
                        }
                    }
                    .padding(.horizontal, 34)
                    .padding(.top, 31)
                    .padding(.bottom, 28)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .font(.system(size: 13))
        .foregroundStyle(Palette.ink)
        .frame(minWidth: 880, minHeight: 640)
        .preferredColorScheme(.light)
        .sheet(item: $editingProvider) { provider in
            ProviderSetupView(store: store, provider: provider)
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11).fill(Palette.mint)
                    Image(systemName: "waveform")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(Palette.dark)
                }
                .frame(width: 38, height: 38)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Voice Switch").font(.system(size: 16, weight: .semibold))
                    Text("ONE FN. ANY VOICE.")
                        .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                        .tracking(1.1)
                        .foregroundStyle(Palette.mint.opacity(0.68))
                }
            }
            .padding(.bottom, 39)

            Text("工作空间")
                .font(.system(size: 10, weight: .medium))
                .tracking(1.4)
                .foregroundStyle(.white.opacity(0.35))
                .padding(.leading, 12)
                .padding(.bottom, 11)

            VStack(spacing: 7) {
                ForEach(Destination.allCases, id: \.self) { item in
                    Button {
                        destination = item
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: item.symbol)
                                .font(.system(size: 15, weight: .medium))
                                .frame(width: 19)
                            Text(item.rawValue).font(.system(size: 13, weight: .medium))
                            Spacer()
                            if destination == item {
                                Circle().fill(Palette.mint).frame(width: 5, height: 5)
                            }
                        }
                        .foregroundStyle(destination == item ? Color.white : Color.white.opacity(0.54))
                        .padding(.horizontal, 12)
                        .frame(height: 42)
                        .background(destination == item ? Color.white.opacity(0.08) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer(minLength: 40)

            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: "keyboard")
                    .font(.system(size: 23, weight: .light))
                    .foregroundStyle(Palette.mint.opacity(0.75))
                Text("好用的声音，\n共用一个按键。")
                    .font(.system(size: 16, weight: .medium))
                    .lineSpacing(5)
                    .foregroundStyle(.white.opacity(0.85))
                Text("喜欢哪个，就切到哪个。")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.38))
            }
            .padding(.leading, 12)
            .padding(.bottom, 28)

            Rectangle().fill(.white.opacity(0.1)).frame(height: 1)

            HStack(spacing: 9) {
                Circle()
                    .fill(store.isListening ? Palette.mint : .white.opacity(0.24))
                    .frame(width: 6, height: 6)
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.isListening ? "Fn 已就位" : "Fn 待命中")
                        .font(.system(size: 11, weight: .medium))
                    Text(store.isListening ? "按下，开始表达" : "完成接入后开启")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.4))
                }
                Spacer(minLength: 0)
                Toggle("启用 Fn", isOn: Binding(get: { store.isEnabled }, set: { store.setEnabled($0) }))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(Palette.mint)
                    .controlSize(.small)
                    .help("开启或暂停统一 Fn 按键")
            }
            .padding(.top, 20)
            .padding(.horizontal, 5)
        }
        .padding(.horizontal, 20)
        .padding(.top, 36)
        .padding(.bottom, 24)
        .foregroundStyle(.white)
        .frame(width: 218)
        .background(Palette.dark)
    }

    @ViewBuilder
    private var providersPage: some View {
        HStack(alignment: .top) {
            pageHeading("我的输入法", subtitle: "把选择留给自己，把 Fn 留给习惯。")
            Spacer()
            Button(action: store.addApplication) {
                Label("添加应用", systemImage: "plus")
            }
            .buttonStyle(OutlineButtonStyle())
            .padding(.top, 3)
        }

        hero

        if !store.hasAccessibility || !store.hasInputMonitoring {
            permissionNotice
        } else if let message = store.message, !message.isEmpty {
            HStack(alignment: .top, spacing: 9) {
                Image(systemName: "info.circle").padding(.top, 1)
                Text(message).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .font(.system(size: 11))
            .foregroundStyle(Palette.secondary)
        }

        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Text("声音工具箱").font(.system(size: 14, weight: .semibold))
                Text("\(store.providers.count)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Palette.secondary)
                Spacer()
                Button(action: store.refresh) {
                    Label("重新检测", systemImage: "arrow.clockwise")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Palette.secondary)
            }

            VStack(spacing: 0) {
                ForEach(Array(orderedProviders.enumerated()), id: \.element.id) { index, provider in
                    ProviderRow(store: store, provider: provider, onConfigure: { editingProvider = provider })
                    if index < orderedProviders.count - 1 {
                        Rectangle().fill(Palette.line.opacity(0.75)).frame(height: 1).padding(.leading, 58)
                    }
                }
            }
            .padding(.horizontal, 15)
            .background(.white.opacity(0.66))
            .clipShape(RoundedRectangle(cornerRadius: 13))
            .overlay(RoundedRectangle(cornerRadius: 13).stroke(Palette.line, lineWidth: 1))

            HStack(spacing: 6) {
                Image(systemName: "lock.shield").font(.system(size: 10))
                Text("结束当前录音后再切换。应用保持常驻，声音和文本由原应用处理。")
                    .font(.system(size: 10))
            }
            .foregroundStyle(Palette.secondary)
            .padding(.top, 2)
        }
    }

    private var orderedProviders: [Provider] {
        store.providers.filter { store.isInstalled($0) } + store.providers.filter { !store.isInstalled($0) }
    }

    private var hero: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Circle().fill(Palette.dark.opacity(store.isListening ? 0.85 : 0.3)).frame(width: 5, height: 5)
                    Text(store.isListening ? "当前声音 · FN 已就位" : "ONE FN. ANY VOICE.")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .tracking(1.1)
                }
                .foregroundStyle(Palette.dark.opacity(0.6))

                Text(store.selectedProvider?.name ?? "给 Fn 选一个声音。")
                    .font(.system(size: store.selectedProvider == nil ? 28 : 34, weight: .semibold))
                    .tracking(-1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.top, 14)

                Text(store.isListening ? "随时换个声音，熟悉的按键一直都在。" : "接入你喜欢的语音应用，一键开始表达。")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.dark.opacity(0.65))
                    .padding(.top, 7)

                HStack(spacing: 9) {
                    shortcutChip("fn")
                    Text("开始 / 结束").font(.system(size: 9))
                    shortcutChip("⇧ fn")
                    Text(store.selectedProvider?.translationShortcut == nil ? "翻译 · 待接入" : "翻译")
                        .font(.system(size: 9))
                }
                .padding(.top, 17)
                Text("点按 Fn 开始，再按结束。翻译以应用支持为准。")
                    .font(.system(size: 8))
                    .foregroundStyle(Palette.dark.opacity(0.5))
                    .padding(.top, 8)
            }
            Spacer(minLength: 2)
            FnKeyView(pressed: store.isPressing)
                .padding(.trailing, 8)
                .accessibilityLabel(store.isPressing ? "Fn 按下" : "Fn 按键")
        }
        .padding(.horizontal, 27)
        .padding(.vertical, 25)
        .frame(maxWidth: .infinity, minHeight: 195, alignment: .leading)
        .background(Palette.mint)
        .clipShape(RoundedRectangle(cornerRadius: 17))
    }

    private var permissionNotice: some View {
        HStack(spacing: 11) {
            Image(systemName: "hand.raised").font(.system(size: 16))
            VStack(alignment: .leading, spacing: 4) {
                Text("让 Fn 接住你的声音").font(.system(size: 11, weight: .semibold))
                Text("授权辅助功能与输入监控，让一个按键连接所有应用。")
                    .font(.system(size: 10)).foregroundStyle(Palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 5)
            Button("去设置") { destination = .settings }.buttonStyle(OutlineButtonStyle(compact: true))
        }
        .padding(.horizontal, 15).padding(.vertical, 13)
        .background(Color(hex: "EEF0E7"))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private var guidePage: some View {
        pageHeading("一个 Fn，怎么接入？", subtitle: "只做一次设置，以后随时换声音。")

        HStack(spacing: 18) {
            FnKeyView(pressed: false, small: true)
            Image(systemName: "arrow.right").foregroundStyle(Palette.secondary)
            VStack(alignment: .leading, spacing: 5) {
                Text("Voice Switch").font(.system(size: 16, weight: .semibold))
                Text("将 Fn 传递为当前应用的专属快捷键")
                    .font(.system(size: 11)).foregroundStyle(Palette.secondary)
            }
            Spacer()
            Image(systemName: "waveform")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(Palette.dark)
        }
        .padding(24)
        .background(Palette.mint.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 15))

        VStack(alignment: .leading, spacing: 25) {
            GuideStep(number: "01", title: "把 Fn 腾出来", text: "在每个语音应用的设置中，移除所有占用 Fn 的快捷键，包括语音输入、翻译、指令等功能。再将系统“按下 🌐 键时”设为“不执行操作”。") {
                Button("打开键盘设置", action: store.openKeyboardSettings)
                    .buttonStyle(TextActionStyle())
            }
            GuideStep(number: "02", title: "给每个应用一个专属快捷键", text: "在“我的输入法”中点击接入，将显示的组合键填入原应用的语音快捷键。也可以录制你自己的组合键，两边保持一致。") {
                Text("例如  ⌃⌥⌘1 → Typeless     ⌃⌥⇧ → Chatterfly")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Palette.secondary)
            }
            GuideStep(number: "03", title: "Fn 说话，Shift + Fn 翻译", text: "在原应用中选择点按模式。按一下 Fn 开始语音，再按一下结束。如果应用支持语音翻译，可再接入一个独立的翻译快捷键，用 Shift + Fn 唤起。") {
                Text("结束当前录音后再切换输入法。Fn + 方向键等系统组合键仍可使用。")
                    .font(.system(size: 10)).foregroundStyle(Palette.secondary)
            }
        }

        VStack(alignment: .leading, spacing: 9) {
            Text("关于兼容性").font(.system(size: 12, weight: .semibold))
            Text("应用需要支持可自定义的全局语音快捷键。检测到已安装，表示找到了应用；完成接入后仍需实际按 Fn 测试。豆包、微信等预设是接入模板，兼容性以当前版本的实际行为为准。")
                .font(.system(size: 11))
                .foregroundStyle(Palette.secondary)
                .lineSpacing(4)
            Text("免费额度、订阅与模型在原应用中管理。你可以在应用备注中记录额度和使用习惯。")
                .font(.system(size: 11)).foregroundStyle(Palette.secondary).lineSpacing(4)
        }
        .padding(19)
        .background(.white.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 11))
    }

    @ViewBuilder
    private var settingsPage: some View {
        pageHeading("设置", subtitle: "让一个按键，安静地融入你的 Mac。")

        settingsSection("权限", caption: "只监听按键并发送快捷键，不录音、不读取转写文本。") {
            settingRow(symbol: "hand.raised", title: "辅助功能", subtitle: "允许 Voice Switch 向语音应用发送快捷键。") {
                permissionButton(granted: store.hasAccessibility, action: store.requestAccessibility)
            }
            Divider().overlay(Palette.line)
            settingRow(symbol: "keyboard", title: "输入监控", subtitle: "接收 Fn 与 Shift + Fn。授权后请重新打开应用。") {
                permissionButton(granted: store.hasInputMonitoring, action: store.requestInputMonitoring)
            }
        }

        settingsSection("使用习惯", caption: nil) {
            settingRow(symbol: "power", title: "登录时启动", subtitle: "开机后，Fn 随时准备就绪。") {
                Toggle("登录时启动", isOn: Binding(get: { store.launchAtLogin }, set: { store.setLaunchAtLogin($0) }))
                    .labelsHidden().toggleStyle(.switch).tint(Palette.dark).controlSize(.small)
            }
            Divider().overlay(Palette.line)
            settingRow(symbol: "arrow.left.arrow.right", title: "快速切换输入法", subtitle: "按 ⌃⌥⌘Space 切换到下一个已接入的应用。") {
                Toggle("快速切换", isOn: Binding(get: { store.hotkeyEnabled }, set: { store.setHotkeyEnabled($0) }))
                    .labelsHidden().toggleStyle(.switch).tint(Palette.dark).controlSize(.small)
            }
            Divider().overlay(Palette.line)
            settingRow(symbol: "globe", title: "系统 Fn / 🌐 键", subtitle: "将“按下 🌐 键时”设为“不执行操作”。") {
                Button("打开设置", action: store.openKeyboardSettings).buttonStyle(OutlineButtonStyle(compact: true))
            }
        }

        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "waveform").font(.system(size: 24, weight: .light))
            VStack(alignment: .leading, spacing: 6) {
                Text("Voice Switch").font(.system(size: 14, weight: .semibold))
                Text("One Fn. Any voice.").font(.system(size: 11)).foregroundStyle(Palette.secondary)
                Text("为 macOS 构建的开源语音切换器。设置保存在这台 Mac 上。")
                    .font(.system(size: 10)).foregroundStyle(Palette.secondary)
            }
            Spacer()
            Text("v0.1.0")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Palette.secondary)
        }
        .padding(.top, 7)

        if let message = store.message, !message.isEmpty {
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(Palette.secondary)
                .lineSpacing(3)
        }
    }

    private func pageHeading(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title).font(.system(size: 25, weight: .semibold)).tracking(-0.7)
            Text(subtitle).font(.system(size: 11)).foregroundStyle(Palette.secondary)
        }
    }

    private func shortcutChip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(.white.opacity(0.36))
            .clipShape(RoundedRectangle(cornerRadius: 5))
    }

    private func settingsSection<Content: View>(_ title: String, caption: String?, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            Text(title).font(.system(size: 13, weight: .semibold))
            VStack(spacing: 0, content: content)
                .padding(.horizontal, 18)
                .background(.white.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.line, lineWidth: 1))
            if let caption {
                Text(caption).font(.system(size: 10)).foregroundStyle(Palette.secondary)
            }
        }
    }

    private func settingRow<Accessory: View>(symbol: String, title: String, subtitle: String, @ViewBuilder accessory: () -> Accessory) -> some View {
        HStack(spacing: 13) {
            Image(systemName: symbol).font(.system(size: 17)).frame(width: 25).foregroundStyle(Palette.secondary)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size: 12, weight: .medium))
                Text(subtitle).font(.system(size: 10)).foregroundStyle(Palette.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 10)
            accessory()
        }
        .padding(.vertical, 17)
    }

    @ViewBuilder
    private func permissionButton(granted: Bool, action: @escaping () -> Void) -> some View {
        if granted {
            Label("已授权", systemImage: "checkmark.circle.fill")
                .font(.system(size: 10))
                .foregroundStyle(Color(hex: "4F8762"))
        } else {
            Button("去授权", action: action).buttonStyle(OutlineButtonStyle(compact: true))
        }
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
        HStack(spacing: 13) {
            Button {
                if provider.isConfigured && installed { store.select(provider) }
                else { onConfigure() }
            } label: {
                HStack(spacing: 13) {
                    ProviderIcon(provider: provider, size: 34)
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 7) {
                            Text(provider.name).font(.system(size: 12, weight: .semibold))
                            if selected {
                                Text("当前").font(.system(size: 8, weight: .medium))
                                    .padding(.horizontal, 5).padding(.vertical, 2)
                                    .background(Palette.mint.opacity(0.65))
                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                            }
                        }
                        Text(provider.note.isEmpty ? provider.subtitle : provider.note)
                            .font(.system(size: 10))
                            .foregroundStyle(Palette.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if installed && provider.isConfigured {
                Text(provider.shortcut.display)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Palette.secondary)
                    .padding(.horizontal, 7).padding(.vertical, 5)
                    .background(Palette.paper)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                Button {
                    store.select(provider)
                } label: {
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18, weight: .light))
                        .foregroundStyle(selected ? Palette.dark : Palette.line)
                }
                .buttonStyle(.plain)
                .help("选用 \(provider.name)")
            } else if installed {
                Text("已安装").font(.system(size: 9)).foregroundStyle(Palette.secondary)
                Button("接入", action: onConfigure).buttonStyle(OutlineButtonStyle(compact: true))
            } else {
                Button("获取") { store.openWebsite(provider) }
                    .buttonStyle(.plain)
                    .font(.system(size: 10))
                    .foregroundStyle(Palette.secondary)
            }

            Button(action: onConfigure) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.secondary.opacity(hovering ? 1 : 0.65))
                    .frame(width: 21, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("\(provider.name) 接入设置")
        }
        .frame(height: 65)
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
                VStack(alignment: .leading, spacing: 5) {
                    Text("接入 \(draft.name)").font(.system(size: 21, weight: .semibold))
                    Text("一次设置，以后只需 Fn。")
                        .font(.system(size: 11)).foregroundStyle(Palette.secondary)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 11, weight: .semibold)).frame(width: 27, height: 27)
                }
                .buttonStyle(.plain).foregroundStyle(Palette.secondary)
            }
            .padding(25)

            Divider().overlay(Palette.line)

            ScrollView {
            VStack(alignment: .leading, spacing: 23) {
                GuideStep(number: "01", title: "释放原应用中的 Fn", text: "在所有语音应用中，移除语音、翻译、指令等功能对 Fn 的占用。系统键盘设置中，将“按下 🌐 键时”设为“不执行操作”。") {
                    HStack(spacing: 18) {
                        Button("打开应用设置") { store.openSettings(draft) }.buttonStyle(TextActionStyle())
                        Button("系统键盘设置", action: store.openKeyboardSettings).buttonStyle(TextActionStyle())
                    }
                }

                VStack(alignment: .leading, spacing: 11) {
                    HStack(alignment: .top, spacing: 14) {
                        stepNumber("02")
                        VStack(alignment: .leading, spacing: 7) {
                            Text("接入语音输入").font(.system(size: 12, weight: .semibold))
                            Text(draft.id == "chatterfly" ? "将下面的组合键设为 Chatterfly 的语音快捷键，最多使用 3 个修饰键。" : "将下面的组合键设为 \(draft.name) 的全局语音快捷键。")
                                .font(.system(size: 11)).foregroundStyle(Palette.secondary).lineSpacing(3)
                            HStack(spacing: 12) {
                                Button {
                                    recordingTranslation = false
                                    recording.toggle()
                                } label: {
                                    Text(recording ? "请按下组合键…" : draft.shortcut.display)
                                        .font(.system(size: 19, weight: .medium, design: .monospaced))
                                        .frame(minWidth: 137, minHeight: 42)
                                        .padding(.horizontal, 14)
                                        .background(.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(recording ? Palette.dark : Palette.line, lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(recording ? "Esc 取消录制" : "点击录制其他快捷键")
                                    Text("纯修饰键组合：按下后松开")
                                }
                                .font(.system(size: 9)).foregroundStyle(Palette.secondary)
                            }
                            .background(ShortcutCapture(shortcut: $draft.shortcut, recording: $recording).frame(width: 0, height: 0))
                            Text("原应用请选择点按开始 / 结束模式。以后只需点按 Fn。")
                                .font(.system(size: 10)).foregroundStyle(Palette.secondary)
                        }
                    }
                }

                GuideStep(number: "03", title: "接入语音翻译 · 可选", text: "原应用支持语音翻译时，给它另设一个独立组合键。以后用 Shift + Fn 触发翻译。") {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("此应用支持语音翻译，我要接入", isOn: Binding(
                            get: { draft.translationShortcut != nil },
                            set: { draft.translationShortcut = $0 ? suggestedTranslation : nil; recordingTranslation = false }
                        ))
                        .toggleStyle(.checkbox)
                        .font(.system(size: 10))
                        .tint(Palette.dark)

                        if draft.translationShortcut != nil {
                            HStack(spacing: 12) {
                                Button {
                                    recording = false
                                    recordingTranslation.toggle()
                                } label: {
                                    Text(recordingTranslation ? "请按下组合键…" : (draft.translationShortcut?.display ?? ""))
                                        .font(.system(size: 19, weight: .medium, design: .monospaced))
                                        .frame(minWidth: 137, minHeight: 42)
                                        .padding(.horizontal, 14)
                                        .background(.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(recordingTranslation ? Palette.dark : Palette.line, lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                                Text(recordingTranslation ? "Esc 取消录制" : "设为原应用的翻译快捷键")
                                    .font(.system(size: 9)).foregroundStyle(Palette.secondary)
                            }
                            .background(ShortcutCapture(shortcut: translationBinding, recording: $recordingTranslation).frame(width: 0, height: 0))
                        }
                    }
                }

                HStack(spacing: 17) {
                    if store.isInstalled(draft) {
                        Button("测试语音快捷键") { showMessage = true; store.testShortcut(draft) }
                            .buttonStyle(TextActionStyle())
                    } else {
                        Button("定位已安装的应用…") { showMessage = true; store.locate(draft) }
                            .buttonStyle(TextActionStyle())
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("我的备注").font(.system(size: 11, weight: .medium))
                        Text("仅保存在本机").font(.system(size: 9)).foregroundStyle(Palette.secondary)
                    }
                    TextField("例如：免费额度、常用语言、适合什么场景", text: $draft.note)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))
                        .padding(11)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Palette.line, lineWidth: 1))
                }

                if draft.id == "doubao" || draft.id == "wetype" {
                    Text("此预设为接入模板；请确认当前版本支持自定义全局语音快捷键，并实际测试。")
                        .font(.system(size: 10)).foregroundStyle(Palette.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(25)
            }

            Divider().overlay(Palette.line)

            VStack(alignment: .leading, spacing: 15) {
                if showMessage, let message = store.message, !message.isEmpty {
                    Text(message).font(.system(size: 10)).foregroundStyle(Palette.secondary)
                        .lineSpacing(3).fixedSize(horizontal: false, vertical: true)
                }

                Toggle(isOn: $confirmed) {
                    Text("已在原应用中设置好快捷键，并移除所有 Fn 占用")
                        .font(.system(size: 11))
                }
                .toggleStyle(.checkbox)
                .tint(Palette.dark)

                HStack {
                    if draft.isCustom {
                        Button("移除应用") { store.removeProvider(draft); dismiss() }
                            .buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(Palette.secondary)
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
            .padding(25)
        }
        .frame(width: 580, height: 670)
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

    private var suggestedTranslation: Shortcut {
        if draft.id == "chatterfly" {
            return Shortcut(keyCode: UInt16.max, key: "", control: false, option: true, shift: true, command: true)
        }
        return Shortcut(keyCode: draft.shortcut.keyCode, key: draft.shortcut.key, control: true, option: false, shift: true, command: true)
    }

    private var translationBinding: Binding<Shortcut> {
        Binding(get: { draft.translationShortcut ?? suggestedTranslation }, set: { draft.translationShortcut = $0 })
    }

    private func stepNumber(_ value: String) -> some View {
        Text(value)
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(Palette.secondary)
            .frame(width: 25, height: 25)
            .background(Palette.line.opacity(0.7))
            .clipShape(Circle())
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
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(Palette.secondary)
                .frame(width: 25, height: 25)
                .background(Palette.line.opacity(0.7))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 7) {
                Text(title).font(.system(size: 12, weight: .semibold))
                Text(text)
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.secondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                accessory().padding(.top, 2)
            }
        }
    }
}

private struct FnKeyView: View {
    var pressed: Bool
    var small = false

    var body: some View {
        let size: CGFloat = small ? 70 : 122
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: small ? 15 : 24)
                .fill(Color(hex: "6F9D78").opacity(0.35))
                .offset(y: pressed ? 2 : 8)
            RoundedRectangle(cornerRadius: small ? 15 : 24)
                .fill(LinearGradient(colors: [Color(hex: "F6FFF2"), Color(hex: "E3F1DE")], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(RoundedRectangle(cornerRadius: small ? 15 : 24).stroke(.white.opacity(0.8), lineWidth: 1))
            VStack(alignment: .leading, spacing: 0) {
                Image(systemName: "globe")
                    .font(.system(size: small ? 13 : 19, weight: .light))
                    .foregroundStyle(Palette.dark.opacity(0.5))
                Spacer()
                Text("fn")
                    .font(.system(size: small ? 25 : 42, weight: .regular, design: .rounded))
                    .foregroundStyle(Palette.dark)
            }
            .padding(small ? 12 : 21)
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(small ? 0 : -8))
        .offset(y: pressed ? 5 : 0)
        .scaleEffect(pressed ? 0.96 : 1)
        .animation(.easeOut(duration: 0.12), value: pressed)
    }
}

private struct ProviderIcon: View {
    let provider: Provider
    let size: CGFloat

    var body: some View {
        if let path = provider.appPath {
            Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                .resizable().interpolation(.high).frame(width: size, height: size)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.24)
                    .fill(Color(hex: provider.tint).opacity(0.11))
                Image(systemName: provider.symbol == "butterfly" ? "sparkles" : provider.symbol)
                    .font(.system(size: size * 0.45, weight: .medium))
                    .foregroundStyle(Color(hex: provider.tint))
            }
            .frame(width: size, height: size)
        }
    }
}

struct MenuContentView: View {
    @ObservedObject var store: AppStore
    let onOpen: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Voice Switch").font(.system(size: 15, weight: .semibold))
                    Text("ONE FN. ANY VOICE.")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .tracking(1.1).foregroundStyle(Palette.secondary)
                }
                Spacer()
                Text("fn")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .frame(width: 38, height: 36)
                    .background(Palette.mint)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(18)

            Divider().overlay(Palette.line)

            if store.configuredProviders.isEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    Text("给 Fn 选一个声音").font(.system(size: 12, weight: .medium))
                    Text("添加你喜欢的语音应用，完成一次接入。")
                        .font(.system(size: 10)).foregroundStyle(Palette.secondary)
                }
                .padding(18)
            } else {
                VStack(spacing: 3) {
                    ForEach(store.configuredProviders) { provider in
                        Button {
                            store.select(provider)
                        } label: {
                            HStack(spacing: 11) {
                                ProviderIcon(provider: provider, size: 27)
                                Text(provider.name).font(.system(size: 12, weight: .medium))
                                Spacer()
                                if store.selectedID == provider.id {
                                    Image(systemName: "checkmark").font(.system(size: 11, weight: .semibold))
                                }
                            }
                            .padding(.horizontal, 10)
                            .frame(height: 40)
                            .background(store.selectedID == provider.id ? Palette.mint.opacity(0.45) : .clear)
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
            }

            Divider().overlay(Palette.line)

            HStack(spacing: 7) {
                Circle().fill(store.isListening ? Color(hex: "5D956A") : Palette.secondary.opacity(0.4)).frame(width: 5, height: 5)
                Text(store.isListening ? "Fn 已就位" : "Fn 已暂停")
                    .font(.system(size: 10)).foregroundStyle(Palette.secondary)
                Spacer()
                Toggle("启用 Fn", isOn: Binding(get: { store.isEnabled }, set: { store.setEnabled($0) }))
                    .labelsHidden().toggleStyle(.switch).controlSize(.mini).tint(Palette.dark)
            }
            .padding(.horizontal, 18).padding(.vertical, 12)

            HStack {
                Button(action: onOpen) { Label("打开 Voice Switch", systemImage: "slider.horizontal.3") }
                    .buttonStyle(.plain)
                Spacer()
                Button(action: onQuit) { Image(systemName: "power") }
                    .buttonStyle(.plain)
                    .help("退出 Voice Switch")
            }
            .font(.system(size: 10)).foregroundStyle(Palette.secondary)
            .padding(.horizontal, 18).padding(.vertical, 13)
            .background(Palette.line.opacity(0.35))
        }
        .foregroundStyle(Palette.ink)
        .frame(width: 292)
        .background(Palette.paper)
        .preferredColorScheme(.light)
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

private struct OutlineButtonStyle: ButtonStyle {
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 10 : 11, weight: .medium))
            .padding(.horizontal, compact ? 10 : 13)
            .frame(height: compact ? 27 : 33)
            .foregroundStyle(Palette.ink)
            .background(configuration.isPressed ? Palette.line : .white.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: compact ? 6 : 7))
            .overlay(RoundedRectangle(cornerRadius: compact ? 6 : 7).stroke(Palette.line, lineWidth: 1))
            .contentShape(Rectangle())
    }
}

private struct SolidButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 16)
            .frame(height: 33)
            .foregroundStyle(.white)
            .background(Palette.dark.opacity(configuration.isPressed ? 0.8 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .contentShape(Rectangle())
    }
}

private struct TextActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 5) {
            configuration.label
            Image(systemName: "arrow.up.right").font(.system(size: 8, weight: .medium))
        }
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(Palette.dark.opacity(configuration.isPressed ? 0.6 : 1))
        .contentShape(Rectangle())
    }
}

private extension Color {
    init(hex: String) {
        let value = UInt64(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0
        self.init(.sRGB, red: Double((value >> 16) & 0xff) / 255, green: Double((value >> 8) & 0xff) / 255, blue: Double(value & 0xff) / 255, opacity: 1)
    }
}
