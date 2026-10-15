import SwiftUI
import VoiceSwitchCore

private typealias VocabularyState<Value> = SwiftUI.State<Value>

struct VocabularyView: View {
    @ObservedObject var store: VocabularyStore
    @VocabularyState private var term = ""
    @VocabularyState private var note = ""
    @VocabularyState private var search = ""
    @VocabularyState private var selectedID: UUID?
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

    private var selectedEntry: VocabularyEntry? {
        store.entries.first { $0.id == selectedID }
    }

    var body: some View {
        // Keep the table and its controls inside the detail column's viewport.
        GeometryReader { page in
            content.frame(width: page.size.width, height: page.size.height, alignment: .top)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(item: $editingEntry) { entry in
            VocabularyEditView(store: store, entry: entry)
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            HStack {
                Button("导入词表…", action: store.importFile)
                Menu("导出") {
                    Button("TXT · 每行一个词", action: store.exportPlainText)
                    Button("CSV · 输入法兼容格式", action: store.exportCSV)
                    Divider()
                    Button("JSON · 完整词库备份", action: store.exportBackup)
                }
                .disabled(store.entries.isEmpty)
                .fixedSize()
                Spacer()
                Button("查看词库文件", action: store.revealFile)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 14)

            VStack(alignment: .trailing, spacing: 8) {
                Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 8) {
                    GridRow {
                        Text("词语：").gridColumnAlignment(.trailing)
                        TextField("词语", text: $term, prompt: Text("输入常用词语"))
                            .labelsHidden()
                            .focused($termFocused)
                            .onSubmit(addEntry)
                    }
                    GridRow {
                        Text("备注：")
                        TextField("备注", text: $note, prompt: Text("可选，仅保存在本机"))
                            .labelsHidden()
                            .onSubmit(addEntry)
                    }
                }
                Button("添加词条", action: addEntry)
                    .disabled(term.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .textFieldStyle(.roundedBorder)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 20)
            .padding(.bottom, 14)

            if let message = store.message, !message.isEmpty {
                Text(message).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }
            Divider()

            HStack {
                Text(search.isEmpty ? "\(store.count) 个词条" : "\(filteredEntries.count) 个结果")
                    .foregroundStyle(.secondary)
                Spacer()
                TextField("搜索词语或备注", text: $search)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 220)
                if !search.isEmpty {
                    Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.borderless)
                        .help("清空搜索")
                        .accessibilityLabel("清空搜索")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Table(filteredEntries, selection: $selectedID) {
                TableColumn("词语", value: \.term)
                    .width(min: 140, ideal: 190, max: 280)
                TableColumn("备注", value: \.note)
            }
            .frame(minHeight: 0, maxHeight: .infinity)
            .onTapGesture(count: 2) {
                if let selectedEntry { editingEntry = selectedEntry }
            }
            .overlay {
                if filteredEntries.isEmpty {
                    VStack(spacing: 8) {
                        Text(store.entries.isEmpty ? "词库为空" : "没有匹配的词条")
                            .font(.headline)
                        Text(store.entries.isEmpty ? "添加常用词语，或导入 TXT、CSV 和词库备份。" : "尝试其他关键词。")
                            .foregroundStyle(.secondary)
                        if !search.isEmpty { Button("显示全部词条") { search = "" } }
                    }
                    .padding()
                }
            }

            HStack(spacing: 10) {
                Button("编辑…") { editingEntry = selectedEntry }
                    .disabled(selectedEntry == nil)
                Button("移除", action: removeSelectedEntry)
                    .disabled(selectedEntry == nil)
                if let removedEntry {
                    Text("已移除“\(removedEntry.term)”")
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    Button("撤销") {
                        if store.restore(removedEntry) { self.removedEntry = nil }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            Divider()

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Text("准备导入到：")
                    ForEach(Provider.catalog.filter { $0.id == "typeless" || $0.id == "chatterfly" }) { provider in
                        Button {
                            store.prepareImport(for: provider)
                        } label: {
                            HStack(spacing: 5) {
                                ProviderIcon(provider: provider, size: 16)
                                Text(provider.name)
                            }
                        }
                        .disabled(store.entries.isEmpty)
                    }
                    Spacer(minLength: 0)
                }
                Text("在原应用词库中选择“导入 CSV”并确认。CSV 只含词语，JSON 备份保留备注；纠错替换规则在原应用中管理。")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
        }
    }

    private func addEntry() {
        if store.add(term: term, note: note) {
            term = ""
            note = ""
            search = ""
            selectedID = nil
            termFocused = true
        }
    }

    private func removeSelectedEntry() {
        if let selectedEntry, store.remove(selectedEntry) {
            removedEntry = selectedEntry
            selectedID = nil
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
        VStack(alignment: .leading, spacing: 20) {
            Text("编辑词条").font(.headline)
            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 8) {
                GridRow {
                    Text("词语：").gridColumnAlignment(.trailing)
                    TextField("词语", text: $draft.term).labelsHidden()
                }
                GridRow {
                    Text("备注：")
                    TextField("备注", text: $draft.note).labelsHidden()
                }
            }
            .textFieldStyle(.roundedBorder)
            .fixedSize(horizontal: false, vertical: true)

            if attemptedSave, let message = store.message {
                Text(message).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Spacer()
                Button("取消") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("保存") {
                    attemptedSave = true
                    if store.update(draft) { dismiss() }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(draft.term.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 440)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
