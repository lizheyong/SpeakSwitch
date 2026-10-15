import SwiftUI
import VoiceSwitchCore

private typealias VocabularyState<Value> = SwiftUI.State<Value>

struct VocabularyView: View {
    @ObservedObject var store: VocabularyStore
    @VocabularyState private var term = ""
    @VocabularyState private var note = ""
    @VocabularyState private var search = ""
    @VocabularyState private var editingEntry: VocabularyEntry?
    @VocabularyState private var removedEntry: VocabularyEntry?
    @FocusState private var termFocused: Bool

    private var filteredEntries: [VocabularyEntry] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty { return store.entries }
        return store.entries.filter {
            $0.term.localizedCaseInsensitiveContains(query) || $0.note.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            header
            introduction
            addForm
            wordList
            handoffSection
            fileFooter
        }
        .sheet(item: $editingEntry) { entry in
            VocabularyEditView(store: store, entry: entry)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 9) {
                Text("共享词库")
                    .font(.system(size: 25, weight: .semibold))
                    .tracking(-0.7)
                Text("名字、术语、习惯用词，都收在同一份词库。")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.secondary)
            }
            Spacer(minLength: 0)
            importMenu
            exportMenu
        }
    }

    private var introduction: some View {
        HStack(alignment: .center, spacing: 20) {
            VStack(alignment: .leading, spacing: 9) {
                Text("你的表达，自有词汇。")
                    .font(.system(size: 20, weight: .semibold))
                    .tracking(-0.6)
                Text("在这里维护本机主词库，导入已有词表，或带到支持词表导入的语音应用。")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.dark.opacity(0.68))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 5)
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(store.count)")
                    .font(.system(size: 38, weight: .light, design: .rounded))
                    .monospacedDigit()
                Text("个词条")
                    .font(.system(size: 10))
                    .foregroundStyle(Palette.dark.opacity(0.62))
            }
            .accessibilityElement(children: .combine)
        }
        .padding(.horizontal, 25)
        .padding(.vertical, 22)
        .background(Palette.mint.opacity(0.63))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var addForm: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("加入一个常用词")
                .font(.system(size: 13, weight: .semibold))
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("词语").font(.system(size: 10)).foregroundStyle(Palette.secondary)
                    TextField("例如：灵境、Voice Switch", text: $term)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))
                        .focused($termFocused)
                        .onSubmit(addEntry)
                        .padding(.horizontal, 11)
                        .frame(height: 34)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Palette.line, lineWidth: 1))
                }
                entryField("备注 · 可选", placeholder: "读音、含义或使用场景", text: $note)
                    .onSubmit(addEntry)
                Button(action: addEntry) {
                    Label("添加", systemImage: "plus")
                }
                .buttonStyle(VocabularyPrimaryStyle())
                .disabled(term.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .padding(.top, 22)
            }
            if let message = store.message, !message.isEmpty {
                Label(message, systemImage: "info.circle")
                    .font(.system(size: 10))
                    .foregroundStyle(Palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var wordList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("我的词条").font(.system(size: 13, weight: .semibold))
                if !search.isEmpty {
                    Text("\(filteredEntries.count) 个结果")
                        .font(.system(size: 10)).foregroundStyle(Palette.secondary)
                }
                Spacer()
                HStack(spacing: 7) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.secondary)
                    TextField("搜索词语或备注", text: $search)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))
                    if !search.isEmpty {
                        Button { search = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11)).foregroundStyle(Palette.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("清空搜索")
                    }
                }
                .padding(.horizontal, 11)
                .frame(width: 190, height: 31)
                .background(.white.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Palette.line, lineWidth: 1))
            }

            VStack(spacing: 0) {
                if store.entries.isEmpty {
                    emptyState
                } else if filteredEntries.isEmpty {
                    VStack(spacing: 9) {
                        Text("还没有找到“\(search)”")
                            .font(.system(size: 13, weight: .medium))
                        Button("查看全部词条") { search = "" }
                            .buttonStyle(.plain)
                            .font(.system(size: 11))
                            .foregroundStyle(Palette.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 135)
                } else {
                    HStack {
                        Text("词语")
                        Spacer()
                        Text("点击词条编辑")
                    }
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Palette.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .background(Palette.line.opacity(0.24))

                    LazyVStack(spacing: 0) {
                        ForEach(Array(filteredEntries.enumerated()), id: \.element.id) { index, entry in
                            wordRow(entry)
                            if index < filteredEntries.count - 1 {
                                Rectangle().fill(Palette.line.opacity(0.7))
                                    .frame(height: 1).padding(.horizontal, 16)
                            }
                        }
                    }
                }
            }
            .background(.white.opacity(0.66))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.line, lineWidth: 1))

            if let removedEntry {
                HStack(spacing: 8) {
                    Text("已移除“\(removedEntry.term)”")
                        .lineLimit(1)
                        .foregroundStyle(Palette.secondary)
                    Button("撤销") {
                        if store.restore(removedEntry) { self.removedEntry = nil }
                    }
                    .buttonStyle(.plain)
                    .fontWeight(.medium)
                    Spacer()
                }
                .font(.system(size: 10))
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "text.book.closed")
                .font(.system(size: 27, weight: .light))
                .foregroundStyle(Palette.dark.opacity(0.55))
            Text("从一个经常被听错的词开始")
                .font(.system(size: 13, weight: .medium))
            Text("人名、品牌、项目名、专业术语，都可以加入。")
                .font(.system(size: 10))
                .foregroundStyle(Palette.secondary)
            Button("导入已有词表", action: store.importFile)
                .buttonStyle(.plain)
                .font(.system(size: 10, weight: .medium))
                .padding(.top, 2)
        }
        .padding(.vertical, 30)
        .frame(maxWidth: .infinity)
    }

    private var handoffSection: some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: "arrow.up.forward.app")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(Palette.dark.opacity(0.6))
                .frame(width: 25)
            VStack(alignment: .leading, spacing: 7) {
                Text("把词库带到输入法")
                    .font(.system(size: 12, weight: .semibold))
                Text("准备文件后，在原应用的词库中选择“导入 CSV”。导入前可预览，确认后由原应用保存。")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.secondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 9) {
                    ForEach(Provider.catalog.filter { $0.id == "typeless" || $0.id == "chatterfly" }) { provider in
                        Button("\(provider.name) · 准备导入") {
                            store.prepareImport(for: provider)
                        }
                        .buttonStyle(VocabularyOutlineStyle())
                        .disabled(store.entries.isEmpty)
                    }
                }
                .padding(.top, 3)
                Text("CSV 包含词语；JSON 备份同时保留备注。纠错替换规则在原应用中管理。")
                    .font(.system(size: 10))
                    .foregroundStyle(Palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(17)
        .background(Palette.line.opacity(0.36))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var fileFooter: some View {
        HStack(spacing: 6) {
            Image(systemName: "internaldrive").font(.system(size: 10))
            Text("主词库保存在这台 Mac 上")
            Spacer()
            Button("查看词库文件", action: store.revealFile).buttonStyle(.plain)
        }
        .font(.system(size: 10))
        .foregroundStyle(Palette.secondary)
    }

    private var exportMenu: some View {
        Menu {
            Button("导出 TXT · 每行一个词", action: store.exportPlainText)
            Button("导出 CSV · 输入法兼容格式", action: store.exportCSV)
            Divider()
            Button("导出 JSON · 完整词库备份", action: store.exportBackup)
        } label: {
            Label("导出词表", systemImage: "square.and.arrow.up")
                .font(.system(size: 11, weight: .medium))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .padding(.horizontal, 12)
        .frame(height: 33)
        .background(.white.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Palette.line, lineWidth: 1))
        .disabled(store.entries.isEmpty)
    }

    private var importMenu: some View {
        Menu {
            Button("从文件导入…", action: store.importFile)
        } label: {
            Label("导入", systemImage: "square.and.arrow.down")
                .font(.system(size: 11, weight: .medium))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .padding(.horizontal, 12)
        .frame(height: 33)
        .background(.white.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Palette.line, lineWidth: 1))
    }

    private func entryField(_ title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 10)).foregroundStyle(Palette.secondary)
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .padding(.horizontal, 11)
                .frame(height: 34)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Palette.line, lineWidth: 1))
        }
    }

    private func wordRow(_ entry: VocabularyEntry) -> some View {
        HStack(spacing: 14) {
            Button { editingEntry = entry } label: {
                VStack(alignment: .leading, spacing: 5) {
                    Text(entry.term)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(2)
                        .help(entry.term)
                    if !entry.note.isEmpty {
                        Text(entry.note)
                            .font(.system(size: 10))
                            .foregroundStyle(Palette.secondary)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button { editingEntry = entry } label: {
                Image(systemName: "pencil").font(.system(size: 11)).frame(width: 24, height: 28)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Palette.secondary)
            .help("编辑 \(entry.term)")

            Button {
                if store.remove(entry) { removedEntry = entry }
            } label: {
                Image(systemName: "trash").font(.system(size: 11)).frame(width: 24, height: 28)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Palette.secondary)
            .help("移除 \(entry.term)")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func addEntry() {
        if store.add(term: term, note: note) {
            term = ""
            note = ""
            search = ""
            termFocused = true
        }
    }
}

private struct VocabularyEditView: View {
    @ObservedObject var store: VocabularyStore
    @Environment(\.dismiss) private var dismiss
    @VocabularyState private var draft: VocabularyEntry
    @VocabularyState private var attemptedSave = false

    init(store: VocabularyStore, entry: VocabularyEntry) {
        self.store = store
        _draft = VocabularyState(initialValue: entry)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 21) {
            VStack(alignment: .leading, spacing: 7) {
                Text("编辑词条").font(.system(size: 21, weight: .semibold))
                Text("让常用词保持准确，备注保留给自己。")
                    .font(.system(size: 11)).foregroundStyle(Palette.secondary)
            }

            VStack(alignment: .leading, spacing: 9) {
                Text("词语").font(.system(size: 11, weight: .medium))
                TextField("词语", text: $draft.term)
                    .textFieldStyle(.plain)
                    .padding(11)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(Palette.line, lineWidth: 1))
            }

            VStack(alignment: .leading, spacing: 9) {
                Text("备注 · 可选").font(.system(size: 11, weight: .medium))
                TextField("读音、含义或使用场景", text: $draft.note)
                    .textFieldStyle(.plain)
                    .padding(11)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(Palette.line, lineWidth: 1))
            }

            if attemptedSave, let message = store.message {
                Text(message).font(.system(size: 10)).foregroundStyle(Palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Spacer()
                Button("取消") { dismiss() }.buttonStyle(VocabularyOutlineStyle())
                Button("保存") {
                    attemptedSave = true
                    if store.update(draft) { dismiss() }
                }
                .buttonStyle(VocabularyPrimaryStyle())
                .keyboardShortcut(.defaultAction)
                .disabled(draft.term.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .font(.system(size: 12))
        .padding(27)
        .frame(width: 440)
        .foregroundStyle(Palette.ink)
        .background(Palette.paper)
    }
}

private struct VocabularyOutlineStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 12)
            .frame(height: 33)
            .foregroundStyle(Palette.ink)
            .background(configuration.isPressed ? Palette.line : .white.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Palette.line, lineWidth: 1))
    }
}

private struct VocabularyPrimaryStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 15)
            .frame(height: 34)
            .foregroundStyle(.white)
            .background(Palette.dark.opacity(enabled ? (configuration.isPressed ? 0.8 : 1) : 0.3))
            .clipShape(RoundedRectangle(cornerRadius: 7))
    }
}
