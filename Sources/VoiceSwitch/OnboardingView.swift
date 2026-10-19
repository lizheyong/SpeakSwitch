import AppKit
import SwiftUI
import VoiceSwitchCore

private typealias OnboardingState<Value> = SwiftUI.State<Value>

struct OnboardingView: View {
    @ObservedObject var store: AppStore
    @Binding var step: Int
    @Binding var providerID: String
    @Binding var trialConfirmed: Bool
    let onFinish: () -> Void

    @Environment(\.dismiss) private var dismiss
    @OnboardingState private var editingProvider: Provider?
    @OnboardingState private var practiceText = ""
    @OnboardingState private var showActionMessage = false

    private enum Step: Int, CaseIterable {
        case choose, permissions, conflicts, shortcut, trial

        var title: String {
            switch self {
            case .choose: return "选择输入法"
            case .permissions: return "允许系统权限"
            case .conflicts: return "检查 Fn 占用"
            case .shortcut: return "设置快捷键"
            case .trial: return "试用 Fn"
            }
        }
    }

    private var currentStep: Step { Step(rawValue: step) ?? .choose }
    private var installedProviders: [Provider] { store.providers.filter(store.isInstalled) }
    private var provider: Provider? { installedProviders.first { $0.id == providerID } }
    private var permissionsReady: Bool { store.hasAccessibility && store.hasInputMonitoring }
    private var trialReady: Bool {
        permissionsReady && provider?.isConfigured == true
            && store.selectedID == providerID && store.isListening
    }

    private var canContinue: Bool {
        switch currentStep {
        case .choose: return provider != nil
        case .permissions: return provider != nil && permissionsReady
        case .conflicts: return provider != nil
        case .shortcut: return provider?.isConfigured == true && permissionsReady
        case .trial: return trialReady && trialConfirmed
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("接入助手").font(.headline)
                Text("第 \(currentStep.rawValue + 1) 步，共 \(Step.allCases.count) 步：\(currentStep.title)")
                    .foregroundStyle(.secondary)
                ProgressView(value: Double(currentStep.rawValue + 1), total: Double(Step.allCases.count))
                    .accessibilityLabel("接入进度")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            Divider()

            Form {
                if currentStep != .choose && provider == nil {
                    Section("重新选择输入法") {
                        Text("找不到之前选择的应用。请确认它已安装，或选择其他输入法。")
                        Button("返回选择输入法") { step = Step.choose.rawValue }
                        Button("重新检测", action: store.refresh)
                    }
                } else {
                    switch currentStep {
                    case .choose: chooseStep
                    case .permissions: permissionsStep
                    case .conflicts: FnPreflightSections(store: store)
                    case .shortcut: shortcutStep
                    case .trial: trialStep
                    }
                }
                if showActionMessage, let message = store.message, !message.isEmpty {
                    Section {
                        Text(message).font(.caption).foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }
            .formStyle(.grouped)
            Divider()

            HStack {
                Button("稍后设置") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                if currentStep != .choose {
                    Button("上一步") {
                        step = currentStep.rawValue - 1
                        showActionMessage = false
                    }
                }
                Button(currentStep == .trial ? "完成" : "继续") {
                    if currentStep == .trial {
                        practiceText = ""
                        onFinish()
                        dismiss()
                    } else {
                        step = currentStep.rawValue + 1
                        showActionMessage = false
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canContinue)
            }
            .padding(16)
        }
        .frame(width: 580, height: 540)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(item: $editingProvider) { provider in
            ProviderSetupView(store: store, provider: provider)
        }
        .onAppear {
            store.refresh()
            store.refreshFnChecks()
            if providerID.isEmpty {
                providerID = installedProviders.first(where: { $0.id == store.selectedID })?.id
                    ?? installedProviders.first?.id ?? ""
            }
        }
        .onDisappear { practiceText = "" }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            store.refresh()
            store.refreshFnChecks()
        }
        .onChange(of: providerID) { _ in resetTrial() }
        .onChange(of: provider?.shortcut) { _ in resetTrial() }
        .onChange(of: provider?.translationShortcut) { _ in resetTrial() }
        .onChange(of: provider?.isConfigured) { configured in
            if configured != true { resetTrial() }
        }
        .onChange(of: permissionsReady) { ready in
            if !ready { resetTrial() }
        }
    }

    private var chooseStep: some View {
        Group {
            Section {
                Text("选择一个已安装的语音输入法。声选把 Fn 交给当前选择的应用，语音识别仍由它完成。")
            }
            Section("这台 Mac 上的输入法") {
                if installedProviders.isEmpty {
                    Text("还没有检测到语音输入法。可以先安装一个，或添加已有应用。")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("输入法", selection: $providerID) {
                        ForEach(installedProviders) { provider in
                            HStack(spacing: 8) {
                                ProviderIcon(provider: provider, size: 20)
                                Text(provider.name)
                                if provider.isConfigured {
                                    Text("已接入").foregroundStyle(.secondary)
                                }
                            }
                            .tag(provider.id)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()
                }
                HStack {
                    Button("重新检测", action: store.refresh)
                    Button("添加应用…") { showActionMessage = true; store.addApplication() }
                }
            }
            Section {
                DisclosureGroup("还没有安装输入法？") {
                    ForEach(store.providers.filter { !store.isInstalled($0) && !$0.website.isEmpty }) { provider in
                        HStack(spacing: 8) {
                            ProviderIcon(provider: provider, size: 20)
                            Text(provider.name)
                            Spacer()
                            Button("访问官网") { store.openWebsite(provider) }
                        }
                    }
                }
            } footer: {
                Text("检测到应用后，还需要设置它的快捷键并实际试用 Fn。")
            }
        }
    }

    private var permissionsStep: some View {
        Group {
            Section {
                permissionRow(
                    title: "辅助功能",
                    explanation: "允许发送输入法快捷键。部分 macOS 将此项显示为“设备控制和数据访问”。",
                    granted: store.hasAccessibility,
                    action: store.requestAccessibility
                )
                permissionRow(
                    title: "输入监控",
                    explanation: "允许声选接收 Fn 与 Shift + Fn 按键。",
                    granted: store.hasInputMonitoring,
                    action: store.requestInputMonitoring
                )
            } header: {
                Text("需要允许两项权限")
            } footer: {
                Text("在系统设置中开启声选对应的开关。返回这里后状态会自动更新。")
            }
            Section("授权后") {
                Text("如果 macOS 要求退出并重新打开声选，请按系统提示操作。重新打开后可以继续接入。")
                Button("重新检查权限", action: store.refresh)
                Text("声选不需要麦克风权限。录音和语音识别由你选择的输入法处理。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section {
                DisclosureGroup("列表里没有声选？") {
                    Text("在系统权限页点“＋”，添加当前这份声选，再开启它的开关。")
                    Button("在 Finder 中显示应用", action: store.revealApplication)
                }
            }
        }
    }

    @ViewBuilder
    private var shortcutStep: some View {
        if let provider {
            Section(provider.name) {
                HStack(spacing: 10) {
                    ProviderIcon(provider: provider, size: 28)
                    Text(provider.isConfigured ? "已保存快捷键接入设置" : "设置输入法自己的触发快捷键")
                }
                LabeledContent("语音快捷键", value: provider.shortcut.display)
                if let translation = provider.translationShortcut {
                    LabeledContent("翻译快捷键", value: translation.display)
                }
                Text("按各家输入法的说明，把下方组合键设到原应用里，并释放它占用的 Fn。只需配置一次，日常统一用 Fn 开始和结束。")
                Button(provider.isConfigured ? "查看或调整接入设置…" : "设置快捷键…") {
                    resetTrial()
                    showActionMessage = false
                    editingProvider = provider
                }
            }
            if !permissionsReady { permissionRecovery }
            Section {
                Text("在接入设置中完成确认并保存后，继续实际试用。保存设置本身不能说明 Fn 已经正常工作。")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var trialStep: some View {
        if let provider {
            Section("准备试用 \(provider.name)") {
                if trialReady {
                    Label("Fn 已就绪", systemImage: "checkmark.circle")
                } else {
                    Text("先启用 Fn，再到下面的输入区试一下。")
                }
                Button(trialReady ? "重新准备试用" : "启用 Fn，开始试用") {
                    resetTrial()
                    showActionMessage = true
                    if store.select(provider) { store.setEnabled(true) }
                }
                .disabled(!permissionsReady || !provider.isConfigured)
                if !permissionsReady { permissionRecovery }
                if !provider.isConfigured {
                    Button("返回设置快捷键") { step = Step.shortcut.rawValue }
                }
            }
            Section {
                Text("1. 点击下面的输入区。\n2. 点按 Fn，确认输入法开始录音，再说一句话。\n3. 再点按 Fn，等待文字出现在输入区中。")
                TextEditor(text: $practiceText)
                    .font(.body)
                    .frame(height: 110)
                    .border(Color(nsColor: .separatorColor))
                    .accessibilityLabel("Fn 试用输入区")
            } header: {
                Text("练习输入区")
            } footer: {
                Text("练习文字仅在此页临时显示，退出助手后清空，不会保存或用于判断试用结果。也可以在你常用的文字输入框中试用。")
            }
            Section("确认结果") {
                Toggle("我已用 Fn 开始、结束，并看到文字出现在输入框中", isOn: $trialConfirmed)
                    .toggleStyle(.checkbox)
                    .disabled(!trialReady)
                Text("完成当前录音后，再返回助手或切换输入法。")
                    .font(.caption).foregroundStyle(.secondary)
                if provider.translationShortcut != nil {
                    Text("翻译可另行试用：Shift + Fn 开始，单独点 Fn 结束。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Button("没有成功，返回接入设置") {
                    resetTrial()
                    step = Step.shortcut.rawValue
                }
                DisclosureGroup("如何判断问题出在哪里？") {
                    Text("直接按 \(provider.shortcut.display) 也无法开始：先检查原应用是否已登录，以及它的麦克风权限。")
                    Text("原快捷键正常，Fn 没有响应：检查系统权限和所有应用的 Fn 占用。")
                    Text("录音正常但没有文字：先点击输入区，再检查原应用的文字输入权限。")
                    if provider.id == "wetype" {
                        Text("微信输入法需要对应的系统输入源。若手动切到了 ABC，请重新选用微信输入法后再试。")
                    }
                }
            }
        }
    }

    private var permissionRecovery: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("需要完成系统权限设置", systemImage: "exclamationmark.triangle")
            Button("返回权限设置") { step = Step.permissions.rawValue }
        }
    }

    private func permissionRow(title: String, explanation: String, granted: Bool, action: @escaping () -> Void) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                Text(explanation).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if granted {
                Label("已允许", systemImage: "checkmark.circle")
                    .foregroundStyle(.secondary)
            } else {
                Button("打开系统设置", action: action)
            }
        }
    }

    private func resetTrial() {
        trialConfirmed = false
        practiceText = ""
    }
}
