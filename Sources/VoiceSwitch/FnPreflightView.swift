import SwiftUI

struct FnPreflightSections: View {
    @ObservedObject var store: AppStore

    var body: some View {
        Section {
            Text("先把 Fn 留给声选")
                .font(.headline)
            Text("检查所有已检测到的语音应用，以及飞书等带内置语音的应用。未选中的应用也可能占用 Fn。")
            Button("重新检查", action: store.refreshFnChecks)
        } footer: {
            Text("可读取的绑定会自动检查；其余项目需要到原应用确认。“已手动确认”是你的检查记录，无法反映之后的设置变化。列表不覆盖所有软件。")
        }
        ForEach(store.fnChecks) { check in
            Section(check.name) {
                Label(check.status, systemImage: check.hasConflict ? "exclamationmark.triangle" : (check.needsReview ? "questionmark.circle" : "checkmark.circle"))
                    .foregroundStyle(check.hasConflict ? Color.orange : Color.secondary)
                if let snapshot = check.snapshot {
                    ForEach(Array(snapshot.bindings.enumerated()), id: \.offset) { _, binding in
                        LabeledContent(binding.action, value: binding.keys.isEmpty ? "未绑定" : binding.keys.joined(separator: "、"))
                    }
                    Text("读取的是本机保存的快捷键；原应用是否已生效，需要实际试用。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Text(check.instructions).fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button(check.id == "system" ? "打开键盘设置…" : "打开 \(check.name)…") { store.openFnCheck(check) }
                    if check.snapshot == nil {
                        Button(check.manuallyReviewed ? "重新标为待检查" : "我已检查并释放 Fn") {
                            store.markFnCheck(check, reviewed: !check.manuallyReviewed)
                        }
                    }
                }
            }
        }
    }
}

struct FnPreflightView: View {
    @ObservedObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Fn 冲突检查").font(.headline)
                Spacer()
                Button("完成") { dismiss() }.keyboardShortcut(.cancelAction)
            }.padding(20)
            Divider()
            Form { FnPreflightSections(store: store) }.formStyle(.grouped)
        }
        .frame(width: 620, height: 620)
        .onAppear { store.refreshFnChecks() }
    }
}
