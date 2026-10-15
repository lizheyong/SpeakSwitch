import AppKit
import SwiftUI
import VoiceSwitchCore

/// 切换输入法后的短暂提示：屏幕顶部居中的一枚小卡片，显示真实图标与名称。
/// 面板不激活应用、不成为 key window、不接收鼠标，因此不会打断正在进行的输入。
@MainActor
final class SwitchFeedback {
    private let model = SwitchFeedbackModel()
    private lazy var panel = makePanel()
    private var dismissWork: DispatchWorkItem?
    /// 每次展示递增；旧的淡出回调据此判断自己是否已过期。
    private var generation = 0

    private static let size = NSSize(width: 360, height: 96)
    private static let visibleDuration: TimeInterval = 1.6

    func show(_ provider: Provider) {
        generation += 1
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if panel.isVisible && panel.alphaValue > 0 {
            // 连续切换：原地更新内容，不叠加新窗口。
            withAnimation(reduceMotion ? .easeInOut(duration: 0.15) : .spring(response: 0.32, dampingFraction: 0.78)) {
                model.provider = provider
            }
        } else {
            model.provider = provider
            panel.alphaValue = 0
        }
        position()
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = reduceMotion ? 0.1 : 0.16
            panel.animator().alphaValue = 1
        }
        NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested,
                             userInfo: [.announcement: "已切换到 \(provider.name)", .priority: NSAccessibilityPriorityLevel.high.rawValue])

        dismissWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.dismiss() }
        dismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.visibleDuration, execute: work)
    }

    private func dismiss() {
        let current = generation
        NSAnimationContext.runAnimationGroup { context in
            context.duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0.1 : 0.22
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            Task { @MainActor in
                guard let self, self.generation == current else { return }
                self.panel.orderOut(nil)
            }
        }
    }

    func close() {
        generation += 1
        dismissWork?.cancel()
        dismissWork = nil
        panel.orderOut(nil)
    }

    /// 放在鼠标所在屏幕的可见区域顶部居中，避开菜单栏与刘海。
    private func position() {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        let origin = NSPoint(x: visible.midX - Self.size.width / 2, y: visible.maxY - Self.size.height - 4)
        panel.setFrame(NSRect(origin: origin, size: Self.size), display: false)
    }

    private func makePanel() -> NSPanel {
        let panel = SwitchFeedbackPanel(contentRect: NSRect(origin: .zero, size: Self.size),
                                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.contentView = NSHostingView(rootView: SwitchFeedbackView(model: model))
        return panel
    }
}

private final class SwitchFeedbackPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
private final class SwitchFeedbackModel: ObservableObject {
    @Published var provider: Provider?
}

private struct SwitchFeedbackView: View {
    @ObservedObject var model: SwitchFeedbackModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if let provider = model.provider {
                HStack(spacing: 12) {
                    ProviderIcon(provider: provider, size: 34)
                        .id(provider.id)
                        .transition(reduceMotion ? .opacity : .scale(scale: 0.92).combined(with: .opacity))
                    .frame(width: 40, height: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(provider.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .id(provider.id)
                            .transition(.opacity)
                        Text("已切换").font(.subheadline).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: 220, alignment: .leading)
                }
                .padding(.vertical, 10)
                .padding(.leading, 12)
                .padding(.trailing, 20)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
