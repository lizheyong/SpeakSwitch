import AppKit
import SwiftUI
import VoiceSwitchCore

private typealias ViewState<Value> = SwiftUI.State<Value>

private enum Destination: String, CaseIterable, Identifiable {
    case providers = "输入法"
    case usage = "使用统计"
    case vocabulary = "共享词库"
    case guide = "接入指南"
    case settings = "设置"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .providers: return "waveform"
        case .usage: return "chart.bar"
        case .vocabulary: return "text.book.closed"
        case .guide: return "questionmark.circle"
        case .settings: return "gearshape"
        }
    }
}

struct MainContentView: View {
    @ObservedObject var store: AppStore
    @ViewState private var destination: Destination? = .providers
    @ViewState private var editingProvider: Provider?
    @AppStorage("setupAssistantStep") private var assistantStep = 0
    @AppStorage("setupAssistantProvider") private var assistantProviderID = ""
    @AppStorage("setupAssistantTrialConfirmed") private var assistantTrialConfirmed = false
    @AppStorage("setupAssistantCompleted") private var assistantCompleted = false
    @AppStorage("setupAssistantInProgress") private var assistantInProgress = false
    @AppStorage("setupAssistantDeferred") private var assistantDeferred = false
    @AppStorage("setupAssistantRevision") private var assistantRevision = 0

    var body: some View {
        NavigationSplitView {
            List(Destination.allCases, selection: $destination) { item in
                Label(item.rawValue, systemImage: item.symbol).tag(item)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 250)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                    Toggle("启用 Fn", isOn: Binding(get: { store.isEnabled }, set: { store.setEnabled($0) }))
                        .toggleStyle(.switch)
                    Text(fnStatus).font(.caption).foregroundStyle(.secondary)
                }
                .padding(12)
            }
        } detail: {
            Group {
                switch destination ?? .providers {
                case .providers: providersPage
                case .usage: UsageView(store: store.usage, providers: store.providers)
                case .vocabulary: VocabularyView(store: store.vocabulary)
                case .guide: guidePage
                case .settings: settingsPage
                }
            }
            .navigationTitle((destination ?? .providers).rawValue)
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 760, minHeight: 520)
        .sheet(item: $editingProvider) { provider in
            ProviderSetupView(store: store, provider: provider)
        }
        .sheet(isPresented: $store.showsFnChecks) { FnPreflightView(store: store) }
        .sheet(isPresented: $store.showsSetupAssistant) {
            OnboardingView(store: store, step: $assistantStep, providerID: $assistantProviderID,
                           trialConfirmed: $assistantTrialConfirmed) {
                assistantCompleted = true
                store.showsSetupAssistant = false
            }
            .onAppear { assistantInProgress = true }
        }
        .onAppear {
            if assistantRevision < 1 {
                // Resume an unfinished assistant before the new conflict-check step.
                if assistantStep >= 2 { assistantStep = 2; assistantTrialConfirmed = false }
                assistantRevision = 1
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            store.refreshFnChecks()
        }
        .onChange(of: store.showsSetupAssistant) { shown in
            if shown {
                if !assistantInProgress {
                    assistantStep = 0
                    assistantProviderID = store.selectedID ?? ""
                    assistantTrialConfirmed = false
                }
                assistantInProgress = true
            } else {
                assistantInProgress = false
                assistantDeferred = true
            }
        }
    }

    private var fnStatus: String {
        if let selected = store.selectedProvider, !store.isRunning(selected) { return "当前输入法未启动" }
        if store.isListening { return "Fn 已就绪" }
        return store.isEnabled ? "等待完成接入" : "Fn 已暂停"
    }

    private var moreProviders: [Provider] {
        let configuredIDs = Set(store.configuredProviders.map(\.id))
        let remaining = store.providers.filter { !configuredIDs.contains($0.id) }
        return remaining.filter { store.isInstalled($0) } + remaining.filter { !store.isInstalled($0) }
    }

    private var providersPage: some View {
        Form {
            if store.fnChecks.contains(where: \.needsReview) {
                Section("Fn 冲突检查") {
                    Text(store.fnChecks.contains(where: \.hasConflict)
                         ? "发现其他快捷键仍包含 Fn，可能影响统一触发。"
                         : "有应用的 Fn 占用待检查，接入前请先确认。")
                    Text(store.fnChecks.filter(\.needsReview).map(\.name).joined(separator: "、"))
                        .foregroundStyle(.secondary)
                    Button("查看并处理…") { store.showsFnChecks = true }
                }
            }
            if store.configuredProviders.isEmpty {
                Section {
                    Text("连接你常用的语音输入法").font(.headline)
                    Text("跟随接入助手完成权限和快捷键设置，再亲自试一句。")
                        .foregroundStyle(.secondary)
                    Button("开始接入…") { store.showsSetupAssistant = true }
                        .buttonStyle(.borderedProminent)
                }
            }
            Section("当前输入法") {
                if let provider = store.selectedProvider {
                    HStack(spacing: 10) {
                        ProviderIcon(provider: provider, size: 28)
                        Text(provider.name).fontWeight(.medium)
                        Spacer()
                        Text(fnStatus).foregroundStyle(.secondary)
                    }
                    LabeledContent("语音输入", value: "Fn · 点按开始，再按结束")
                    LabeledContent("语音翻译", value: provider.translationShortcut == nil ? "尚未接入" : "Shift + Fn")
                } else {
                    Text("从下方选择并接入一个语音输入法。")
                        .foregroundStyle(.secondary)
                }
                if !store.hasAccessibility || !store.hasInputMonitoring {
                    HStack {
                        Label("需要辅助功能与输入监控权限", systemImage: "exclamationmark.triangle")
                        Spacer()
                        Button("打开设置") { destination = .settings }
                    }
                }
            }

            Section("已接入") {
                if store.configuredProviders.isEmpty {
                    Text("尚未接入输入法。完成快捷键设置后，可在这里切换。")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.configuredProviders) { provider in
                        ProviderRow(store: store, provider: provider) { editingProvider = provider }
                    }
                }
            }

            if !moreProviders.isEmpty {
                Section("更多输入法") {
                    ForEach(moreProviders) { provider in
                        ProviderRow(store: store, provider: provider) { editingProvider = provider }
                    }
                }
            }

            Section {
                HStack {
                    Button("添加应用…", action: store.addApplication)
                    Button("重新检测", action: store.refresh)
                    Spacer()
                    Button("切换下一个", action: store.selectNext)
                        .help("与 ⌃⌥⌘Space 相同，只切换正在运行且参与快捷切换的输入法")
                }
            } footer: {
                Text("快捷切换只经过正在运行且勾选“参与快捷切换”的输入法；已退出的应用会跳过。关闭窗口可能仍在后台运行，以列表状态为准。")
            }

            if let message = store.message, !message.isEmpty {
                Section {
                    Text(message).foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var guidePage: some View {
        Form {
            Section {
                Text("从安装到第一句语音输入").font(.headline)
                Text("助手会检测已有输入法，带你开启权限、设置专属快捷键，再用 Fn 试一句。随时可以退出，设置会保留。")
                    .foregroundStyle(.secondary)
                Button("打开接入助手…") { store.showsSetupAssistant = true }
            }
            FnPreflightSections(store: store)
            Section("1. 释放 Fn") {
                Text("在每个语音应用中，移除语音输入、翻译、指令等功能对 Fn 的占用。系统键盘设置中，将“按下 🌐 键时”设为“不执行任何操作”，并把系统听写的快捷键改为不含 Fn 的组合。")
                Button("打开键盘设置", action: store.openKeyboardSettings)
            }
            Section("2. 设置专属快捷键") {
                Text("在输入法列表中选择“接入”，将显示的组合键设为原应用的语音快捷键。也可以录制自己的组合键，两边保持一致。")
                Button("查看输入法") { destination = .providers }
                ForEach(store.providers.filter { store.isInstalled($0) }) { provider in
                    HStack(spacing: 10) {
                        ProviderIcon(provider: provider, size: 24)
                        Text(provider.name)
                        Spacer()
                        Button("查看接入步骤…") { editingProvider = provider }
                    }
                }
            }
            Section("3. 使用 Fn") {
                LabeledContent("语音输入", value: "Fn · 点按开始，再按结束")
                LabeledContent("语音翻译", value: "Shift + Fn · 需单独接入")
                Text("短按 Fn 开始，再按一次结束。翻译用 Shift + Fn 开始，单独点 Fn 结束。结束当前录音后再切换输入法，Fn + 方向键等系统组合键仍可使用。")
                    .foregroundStyle(.secondary)
            }
            Section("兼容性") {
                Text("应用需要支持自定义全局语音快捷键。检测到已安装后，仍需完成设置并实际按 Fn 测试，兼容性以当前版本的实际行为为准。")
                Text("免费额度、订阅与模型在原应用中管理。可以在接入设置的备注中记录额度和使用习惯。")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var settingsPage: some View {
        Form {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("辅助功能")
                        Text("允许发送语音应用的专属快捷键。部分 macOS 将此项显示为“设备控制和数据访问”。")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    permissionButton(granted: store.hasAccessibility, action: store.requestAccessibility)
                }
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("输入监控")
                        Text("接收 Fn 与 Shift + Fn。授权后请重新打开应用。")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    permissionButton(granted: store.hasInputMonitoring, action: store.requestInputMonitoring)
                }
            } header: {
                Text("系统权限")
            } footer: {
                Text("声选不录音、不记录其他应用中的键入内容。接入助手的练习文字仅临时显示，不保存。")
            }

            Section("通用") {
                Toggle("菜单栏显示当前输入法名称", isOn: Binding(get: { store.showsProviderNameInMenuBar }, set: { store.setShowsProviderNameInMenuBar($0) }))
                Toggle("登录时启动", isOn: Binding(get: { store.launchAtLogin }, set: { store.setLaunchAtLogin($0) }))
                Toggle("使用 ⌃⌥⌘Space 切换输入法", isOn: Binding(get: { store.hotkeyEnabled }, set: { store.setHotkeyEnabled($0) }))
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("系统 Fn / 🌐 键")
                        Text("将“按下 🌐 键时”设为“不执行操作”。")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("键盘设置…", action: store.openKeyboardSettings)
                }
            }

            Section("关于") {
                LabeledContent("声选 · SpeakSwitch", value: "0.1.0")
                Text("语音输入切换器")
                    .foregroundStyle(.secondary)
                Text("macOS 开源应用。设置保存在这台 Mac 上。")
                    .foregroundStyle(.secondary)
            }
            if let message = store.message, !message.isEmpty {
                Section {
                    Text(message).foregroundStyle(.secondary).textSelection(.enabled)
                }
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private func permissionButton(granted: Bool, action: @escaping () -> Void) -> some View {
        if granted {
            Label("已授权", systemImage: "checkmark.circle")
                .foregroundStyle(.secondary)
        } else {
            Button("去授权", action: action)
        }
    }
}

private struct ProviderRow: View {
    @ObservedObject var store: AppStore
    let provider: Provider
    let onConfigure: () -> Void

    private var installed: Bool { store.isInstalled(provider) }
    private var selected: Bool { store.selectedID == provider.id }

    var body: some View {
        HStack(spacing: 10) {
            Button {
                if provider.isConfigured && installed { store.select(provider) }
                else { onConfigure() }
            } label: {
                HStack(spacing: 10) {
                    ProviderIcon(provider: provider, size: 28)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(provider.name).fontWeight(.medium)
                        if installed {
                            Text(store.isRunning(provider) ? "运行中" : "未启动")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        if !provider.note.isEmpty {
                            Text(provider.note)
                                .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                        }
                    }
                    Spacer(minLength: 4)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if installed && provider.isConfigured {
                Toggle("参与快捷切换", isOn: Binding(
                    get: { store.participatesInCycle(provider) },
                    set: { store.setParticipatesInCycle(provider, enabled: $0) }
                ))
                .toggleStyle(.checkbox)
                .accessibilityLabel("\(provider.name) 参与快捷切换")
                if selected && store.isRunning(provider) {
                    Label("当前", systemImage: "checkmark").foregroundStyle(.secondary)
                } else {
                    Button(store.isRunning(provider) ? "使用" : "启动并使用") { store.select(provider) }
                }
            } else if installed {
                Button("接入…", action: onConfigure)
            } else {
                Button("获取") { store.openWebsite(provider) }
            }
            Button(action: onConfigure) {
                Image(systemName: "slider.horizontal.3")
            }
            .help("\(provider.name) 接入设置")
            .accessibilityLabel("\(provider.name) 接入设置")
        }
        .padding(.vertical, 3)
    }
}

struct ProviderSetupView: View {
    @ObservedObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @ViewState private var draft: Provider
    @ViewState private var confirmed: Bool
    @ViewState private var recording = false
    @ViewState private var recordingTranslation = false
    @ViewState private var showMessage = false

    init(store: AppStore, provider: Provider) {
        self.store = store
        _draft = ViewState(initialValue: provider)
        _confirmed = ViewState(initialValue: provider.isConfigured)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                ProviderIcon(provider: draft, size: 32)
                Text("接入 \(draft.name)").font(.headline)
                Spacer()
            }
            .padding(20)
            Divider()

            Form {
                if let snapshot = store.detectedShortcuts(for: draft), let shortcut = snapshot.dictation {
                    Section("自动读取快捷键") {
                        Text("已读取原应用保存的组合键，可以直接填入声选，省去重复录制。")
                        LabeledContent("语音输入", value: shortcut.display)
                        if let translation = snapshot.translation {
                            LabeledContent("翻译", value: translation.display)
                        }
                        Button("填入已读取的快捷键") {
                            draft.shortcut = shortcut
                            draft.translationShortcut = snapshot.translation
                            confirmed = false
                        }
                        if !snapshot.fnBindings.isEmpty {
                            Text("原应用仍有 Fn 绑定，请按下一步的说明先释放它。")
                                .foregroundStyle(.orange)
                        }
                    }
                }
                Section("1. 释放 Fn") {
                    Text(settingsLocation).fontWeight(.medium)
                    Text(releaseFnGuidance)
                    Text("系统键盘设置中，将“按下 🌐 / Fn 键时”设为“不执行任何操作”；系统听写也改用不含 Fn 的快捷键。其他常驻语音应用同样需要释放 Fn。")
                        .font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Button("打开 \(draft.name)…") { store.openSettings(draft) }
                        Button("键盘设置…", action: store.openKeyboardSettings)
                    }
                }
                Section("2. 语音输入") {
                    Text(dictationGuidance)
                    HStack {
                        Text("快捷键")
                        Spacer()
                        Button {
                            recordingTranslation = false
                            recording.toggle()
                        } label: {
                            Text(recording ? "请按下组合键…" : draft.shortcut.display)
                                .font(.system(.body, design: .monospaced))
                                .frame(minWidth: 110)
                        }
                    }
                    .background(ShortcutCapture(shortcut: $draft.shortcut, recording: $recording).frame(width: 0, height: 0))
                    Text(recording ? "Esc 取消录制。纯修饰键组合请按下后松开。" : "点击快捷键可以重新录制，纯修饰键组合请按下后松开。")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(draft.id == "wetype" ? "请选择“启动语音输入”，并先将系统输入源切到微信输入法。保存接入后，切换到微信时会自动选中它的输入源。" : "短按这组快捷键开始，再按一次结束；接入后用 Fn 执行相同操作。若原应用另有“按住说话”，请选择点按启动的功能。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("3. 语音翻译（可选）") {
                    Text(translationGuidance)
                    Toggle("接入此应用的语音翻译", isOn: Binding(
                        get: { draft.translationShortcut != nil },
                        set: { draft.translationShortcut = $0 ? suggestedTranslation : nil; recordingTranslation = false }
                    ))
                    if draft.translationShortcut != nil {
                        HStack {
                            Text("翻译快捷键")
                            Spacer()
                            Button {
                                recording = false
                                recordingTranslation.toggle()
                            } label: {
                                Text(recordingTranslation ? "请按下组合键…" : (draft.translationShortcut?.display ?? ""))
                                    .font(.system(.body, design: .monospaced))
                                    .frame(minWidth: 110)
                            }
                        }
                        .background(ShortcutCapture(shortcut: translationBinding, recording: $recordingTranslation).frame(width: 0, height: 0))
                        Text(recordingTranslation ? "Esc 取消录制" : "此组合键应与原应用的翻译快捷键一致。")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Section("其他") {
                    if store.isInstalled(draft) {
                        DisclosureGroup("排查原应用快捷键") {
                            Text("此页打开时 Fn 暂停接管。测试会在 3 秒后发送上方组合键，请先切到空白文字输入框，录音开始后使用原应用的快捷键结束。保存并关闭此页后，再试 Fn。")
                                .font(.caption).foregroundStyle(.secondary)
                            Button("3 秒后发送语音快捷键") { showMessage = true; store.testShortcut(draft) }
                        }
                    } else {
                        Button("定位已安装的应用…") { showMessage = true; store.locate(draft) }
                    }
                    TextField("备注", text: $draft.note, prompt: Text("免费额度、常用语言或使用场景"))
                    if draft.id == "doubao" {
                        Text("此预设为接入模板。请确认当前版本支持自定义全局语音快捷键，并实际测试。")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .formStyle(.grouped)
            Divider()

            VStack(alignment: .leading, spacing: 12) {
                if showMessage, let message = store.message, !message.isEmpty {
                    Text(message).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Toggle("已在原应用中设置好快捷键，并移除所有 Fn 占用", isOn: $confirmed)
                    .toggleStyle(.checkbox)
                HStack {
                    if draft.isCustom {
                        Button("移除应用") { store.removeProvider(draft); dismiss() }
                    } else if !store.isInstalled(draft) {
                        Button("获取 \(draft.name)") { store.openWebsite(draft) }
                    }
                    Spacer()
                    Button("取消") { dismiss() }
                    Button(confirmed ? "保存并选用" : "保存设置") {
                        draft.isConfigured = confirmed
                        showMessage = true
                        if store.saveProvider(draft) {
                            if confirmed && !store.select(draft) { return }
                            dismiss()
                        }
                    }
                    .disabled(recording || recordingTranslation)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(20)
        }
        .frame(width: 580, height: 600)
        .background(Color(nsColor: .windowBackgroundColor))
        .onChange(of: draft.shortcut) { _ in confirmed = false }
        .onChange(of: draft.translationShortcut) { _ in confirmed = false }
        .onChange(of: store.providers) { providers in
            if let provider = providers.first(where: { $0.id == draft.id }) {
                if draft.appPath != provider.appPath || draft.bundleIDs != provider.bundleIDs { confirmed = false }
                draft.appPath = provider.appPath
                draft.bundleIDs = provider.bundleIDs
            }
        }
        .onAppear { store.beginSetup(); store.refreshFnChecks() }
        .onDisappear { store.endSetup() }
    }

    private var dictationGuidance: String {
        if draft.id == "chatterfly" {
            return "将下面的组合键设为 Chatterfly 的语音快捷键，最多使用 3 个修饰键。"
        }
        if draft.id == "typeless" {
            return "将下面的组合键设为 Typeless 的语音快捷键，修饰键和普通键合计最多 3 个。"
        }
        if draft.id == "wetype" {
            return "在微信输入法中设置“启动语音输入”快捷键，修饰键和普通键合计最多 3 个。推荐 Control + Option + 2（⌃⌥2），并与下面的组合键保持一致。"
        }
        return "将下面的组合键设为 \(draft.name) 的全局语音快捷键。"
    }

    private var settingsLocation: String {
        switch draft.id {
        case "typeless": return "Typeless → 设置 → Keyboard shortcuts / 快捷键"
        case "chatterfly": return "Chatterfly 设置 → 语音输入"
        case "wetype": return "微信输入法设置 → 语音输入"
        default: return "打开 \(draft.name) 的快捷键设置"
        }
    }

    private var releaseFnGuidance: String {
        switch draft.id {
        case "typeless":
            return "将“语音输入”和“翻译”改为下方组合键；将“随便问”的 Fn + 空格改为 Option + Command + 1，并移除其余包含 Fn 的附加快捷键。"
        case "chatterfly":
            return "将“语音输入”改为下方组合键；将“指令模式 / AI 指令”的双击 Fn 改为 Option + Shift + Command。按下三个修饰键后一起松开，即可录入。"
        case "wetype":
            return "将“启动语音输入”的 Fn + 空格改为下方组合键。这个入口是点按开始、再按结束，和“按住说话”不同。"
        default:
            return "为语音输入设置独立组合键，并移除语音、翻译和指令等功能对 Fn 的占用。"
        }
    }

    private var translationGuidance: String {
        switch draft.id {
        case "chatterfly":
            return "AI 指令与语音翻译是不同功能。只有原应用提供独立的翻译动作时才接入，并重新录制它的组合键；不要使用上面的 AI 指令组合。"
        case "wetype":
            return "当前已确认的是语音输入快捷键。若你的微信输入法版本提供独立翻译快捷键，可在这里接入；默认不启用。"
        default:
            return "原应用支持语音翻译时，给它另设一个独立组合键。以后按 Shift + Fn 开始翻译，单独点 Fn 结束并上屏。"
        }
    }

    private var suggestedTranslation: Shortcut { draft.suggestedTranslationShortcut }

    private var translationBinding: Binding<Shortcut> {
        Binding(get: { draft.translationShortcut ?? suggestedTranslation }, set: { draft.translationShortcut = $0 })
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
