import Charts
import SwiftUI
import VoiceSwitchCore

private typealias ViewState<Value> = SwiftUI.State<Value>

struct UsageView: View {
    @ObservedObject var store: UsageStore
    let providers: [Provider]
    @ViewState private var period: UsagePeriod = .week
    @ViewState private var highlightedDay: Date?
    @ViewState private var now = Date()

    private var summary: UsageSummary { store.history.summary(for: period, now: now) }
    private var maximumStarts: Int { max(1, summary.days.map(\.starts).max() ?? 0) }

    var body: some View {
        Form {
            Section("统计范围") {
                Picker("统计范围", selection: $period) {
                    ForEach(UsagePeriod.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            Section("概览") {
                metric(title: "启动次数", value: "\(summary.starts)", detail: "经 One Fn 发起")
                metric(title: "估算使用时长", value: durationText(summary.duration), detail: "已完成 \(summary.completed) 次")
                metric(title: "平均每次时长", value: durationText(summary.averageDuration), detail: "按已完成记录计算")
                if summary.incomplete > 0 || summary.active > 0 {
                    Label(pendingText(incomplete: summary.incomplete, active: summary.active) + "，尚未计入时长。", systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section(period == .all ? "每日启动 · 最近 30 天" : "每日启动") {
                dailyActivity
            }

            Section {
                if summary.providers.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("这段时间还没有使用记录。")
                        Text("通过 One Fn 发起语音后，这里会显示启动次数；配对到结束操作后再计入估算时长。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(summary.providers) { item in
                        providerRow(item)
                    }
                }
            } header: {
                Text("各应用使用情况")
            } footer: {
                Text("按估算使用时长排序。")
            }

            Section("统计说明") {
                measurementNote
            }

            if let message = store.message, !message.isEmpty {
                Section {
                    Label(message, systemImage: "info.circle")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .onChange(of: period) { _ in highlightedDay = nil }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { now = $0 }
    }

    private func metric(title: String, value: String, detail: String) -> some View {
        LabeledContent {
            Text(value)
                .font(.headline)
                .monospacedDigit()
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var dailyActivity: some View {
        VStack(alignment: .leading, spacing: 8) {
            Chart(summary.days) { day in
                BarMark(
                    x: .value("日期", day.date, unit: .day),
                    y: .value("启动次数", day.starts)
                )
                .foregroundStyle(Color.accentColor.opacity(highlightedDay == nil || highlightedDay == day.date ? 1 : 0.5))
                .accessibilityLabel(day.date.formatted(date: .abbreviated, time: .omitted))
                .accessibilityValue("\(day.starts) 次启动，估算使用 \(durationText(day.duration))")
            }
            .chartYScale(domain: 0...maximumStarts)
            .chartYAxis {
                AxisMarks(values: [0, maximumStarts])
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) {
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: .dateTime.month().day())
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(let location):
                                let x = location.x - geometry[proxy.plotAreaFrame].origin.x
                                highlightedDay = proxy.value(atX: x, as: Date.self).map {
                                    Calendar.current.startOfDay(for: $0)
                                }
                            case .ended:
                                highlightedDay = nil
                            }
                        }
                }
            }
            .frame(height: 150)
            .help(highlightedDayDescription)

            Text(highlightedDayDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var highlightedDayDescription: String {
        if let highlightedDay, let day = summary.days.first(where: { $0.date == highlightedDay }) {
            return "\(day.date.formatted(date: .abbreviated, time: .omitted)) · \(day.starts) 次启动 · 估算使用 \(durationText(day.duration))"
        }
        return "单位：次。将指针移到图表上查看每天的记录。"
    }

    private func providerRow(_ item: UsageProviderSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                ProviderIcon(provider: iconProvider(for: item.provider), size: 32)
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.provider.name).font(.headline)
                    Text("\(item.starts) 次启动 · 听写 \(item.dictations) · 翻译 \(item.translations)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            LabeledContent("估算使用时长", value: durationText(item.duration))
            LabeledContent("平均每次时长", value: durationText(item.averageDuration))
            LabeledContent("时长占比", value: "\(Int((item.share * 100).rounded()))%")
            ProgressView(value: item.share)
                .progressViewStyle(.linear)
                .tint(.accentColor)
                .accessibilityHidden(true)

            if item.incomplete > 0 || item.active > 0 {
                Text(pendingText(incomplete: item.incomplete, active: item.active))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private var measurementNote: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("统计仅包含经 One Fn 发起的操作。")
            Text("时长按 One Fn 的开始与结束操作估算。直接在原应用中触发的语音不计入；缺少结束操作的记录不计时长和平均值。")
            Text("记录归入开始当天，跨日使用的完整时长也计入开始当天。")
            Text("不记录音频或转写文本，记录保存在本机。")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func iconProvider(for snapshot: UsageProvider) -> Provider {
        if let provider = providers.first(where: { $0.id == snapshot.id }) ?? Provider.catalog.first(where: { $0.id == snapshot.id }) {
            return provider
        }
        return Provider(
            id: snapshot.id,
            name: snapshot.name,
            subtitle: "",
            symbol: "waveform",
            tint: "77746B",
            website: "",
            bundleIDs: snapshot.bundleIDs,
            appNames: snapshot.appNames,
            appPath: snapshot.appPath,
            shortcut: Shortcut(keyCode: 0, key: ""),
            isCustom: true
        )
    }

    private func pendingText(incomplete: Int, active: Int) -> String {
        var parts: [String] = []
        if incomplete > 0 { parts.append("\(incomplete) 次未完成") }
        if active > 0 { parts.append("\(active) 次等待结束") }
        return parts.joined(separator: "，")
    }

    private func durationText(_ duration: TimeInterval) -> String {
        let seconds = Int(duration.rounded())
        if seconds < 60 { return "\(seconds) 秒" }
        let minutes = seconds / 60
        if minutes < 60 {
            let remainder = seconds % 60
            return remainder == 0 ? "\(minutes) 分" : "\(minutes) 分 \(remainder) 秒"
        }
        let hours = minutes / 60
        let remainder = minutes % 60
        return remainder == 0 ? "\(hours) 小时" : "\(hours) 小时 \(remainder) 分"
    }
}
