# Voice Switch

**一个 Fn，切换你正在用的语音输入法。**

Voice Switch 是 macOS 菜单栏应用。选中 Typeless、Chatterfly 或其他语音工具后，继续用同一个 Fn 键说话。应用保持运行，点击菜单栏即可切换，也可以按 `⌃⌥⌘Space` 在已接入的应用之间循环选择。

| 按键 | 行为 |
| --- | --- |
| `Fn` | 按一下开始语音输入，再按一下结束 |
| `Fn + Shift` | 触发当前应用已配置的翻译快捷键 |
| `⌃⌥⌘Space` | 切换到下一个已接入的应用 |

原应用继续负责录音、识别、翻译、文字整理和上屏，也继续使用自己的账号与额度。Voice Switch 负责把按键转发成当前应用独有的内部快捷键。

## 工作方式

```text
Fn 松开          → 当前应用的语音输入快捷键 → 原应用开始或结束录音
Fn + Shift 松开  → 当前应用的翻译快捷键     → 原应用执行翻译
```

每个应用完成一次快捷键设置后，日常只需选择当前应用。切换时更新按键路由；尚未启动的目标应用会启动一次，其他语音应用可以继续驻留。

Voice Switch 使用原生 SwiftUI、AppKit 和 Core Graphics，无第三方依赖。内置 Typeless、Chatterfly、豆包输入法、微信输入法、Spokenly、闪电说的接入模板，也可以选择自己的 `.app` 添加工具。模板表示预置名称、查找位置和快捷键建议，具体兼容状态见 [兼容性记录](docs/COMPATIBILITY.md)。

## 构建与安装

应用支持 macOS 13 或更新版本。编译需要 Xcode 或 Command Line Tools；测试使用 Swift Testing，需要 Swift 6 和 macOS 14 或更新版本。

```sh
./scripts/test.sh
./scripts/build-app.sh --install
open "$HOME/Applications/Voice Switch.app"
```

构建脚本生成 `dist/Voice Switch.app` 和 ZIP 压缩包；`--install` 将应用安装到 `~/Applications/Voice Switch.app`。只构建时运行：

```sh
swift build --build-system native
./scripts/build-app.sh
```

给完整 `.app` 授权并从固定安装位置启动，更便于 macOS 识别应用权限。

源码支持在 Apple Silicon 和 Intel Mac 上本机编译。当前本地构建为 arm64，构建脚本产物采用构建机器的架构。产物用于本地运行，未经过 Developer ID 签名与 Apple 公证。GitHub Actions 会运行测试、构建并上传应用压缩包。

## 首次接入

1. 在系统设置 → 隐私与安全性中，给 **Voice Switch** 开启「辅助功能」和「输入监控」。按系统提示重新打开应用。
2. 在系统设置 → 键盘中，把「按下 🌐 / Fn 键以」设为「不执行任何操作」。同时移除系统听写对 Fn 的占用；可以关闭听写，或为听写设置不含 Fn 的快捷键。
3. 打开每个会运行的语音应用，移除其**所有含 Fn 的原生快捷键**，包括 Fn + Shift、翻译、AI 指令等其他功能。为语音输入设置独有的内部快捷键，原应用提供触发方式选项时选择「按一下开始，再按一下结束」。
4. 在 Voice Switch 的接入面板填写相同的语音输入快捷键。Chatterfly 建议使用纯修饰键 `⌃⌥⇧`；其他应用可使用界面提供的组合键建议。
5. 需要翻译时，在原应用中设置一个独立的翻译快捷键，并填写到 Voice Switch 的可选翻译设置。先在原应用确认它确实触发翻译。
6. 测试原应用响应后完成接入，选中它并开启 One Fn。在空白文字输入框内测试 Fn 开始与结束，以及 Fn + Shift 翻译。

请完成所有正在运行的语音应用的 Fn 设置，即使某个应用还没有加入 Voice Switch。其他应用保留原生 Fn 监听时，仍可能同时触发。

纯修饰键快捷键需要避开其他快捷键的前缀。例如 Chatterfly 使用 `⌃⌥⇧`，其他应用使用 `⌃⌥⌘` 加数字，避免按下组合键的前半段就触发另一个应用。

添加新工具时，选择真正负责语音输入的 `.app`，按照同样步骤设置。系统输入法通常在 `/Library/Input Methods` 或 `~/Library/Input Methods`。它需要支持可配置的全局快捷键，并能接收系统合成键盘事件。

## 按键行为

松开 Fn 时，Voice Switch 发送一次完整的快捷键按下与松开。原应用按自己的切换规则开始或结束录音，按住 Fn 不会变成持续按住目标快捷键。

Fn 与 Shift 组成独立翻译手势，调用用户配置的翻译快捷键。Voice Switch 不会为原应用增加翻译能力，也不会把 AI 指令自动当作翻译。Typeless 的官方用法是 Fn + Shift 开始翻译，再按主语音快捷键 Fn 结束；其他应用需要按自己的行为验收。

Fn + Delete 等其他组合键交给系统处理。关闭 One Fn 后，原应用的内部快捷键设置保留，可以直接使用这些快捷键。

切换应用前先结束当前录音。各语音应用的录音状态接口不同，Voice Switch 当前仅管理按键路由；界面的按键指示表示 Fn 按下，录音是否进行以原应用为准。

## 共享词库

在「共享词库」维护一份本机主词库，保存常用词和可选备注。可以搜索、编辑、删除词条，也可以导入已有词表。重复词合并时保留本机已有内容。

已有词条可以通过 TXT、单列 CSV 或 Voice Switch 的 JSON 备份导入。Chatterfly 1.0.7.13415 的本机数据库保存的是编码或加密后的词条表示，不能直接将 SQLite 字段作为明文词语读取。当前请使用已有的兼容词表文件，或在共享词库中维护标准写法，再通过 CSV 交给原应用。

| 格式 | 用途 |
| --- | --- |
| TXT | 每行一个词，导入和导出通用词表 |
| CSV | 无表头、单列、每行一个词，导入和导出词表 |
| JSON | Voice Switch 完整备份格式，保留词条与备注，可重新导入 |

Typeless 和 Chatterfly 提供「准备导入」按钮：Voice Switch 生成兼容的单列 CSV，在 Finder 中定位文件，并打开对应应用或设置。随后在原应用的词库中选择「导入 CSV」，检查预览并确认。Typeless 的入口是 Dictionary → New word → Import CSV；Chatterfly 的入口是个人词库 → 添加新词 → 导入 CSV。

共享词库的修改需要再次导入到原应用。当前没有后台双向同步，Voice Switch 中删除词条也不会删除原应用的词条。备注保留在本机主词库和 JSON 备份中；语音应用的纠错替换规则由原应用管理。其他应用可使用导出的词表，具体格式与能力见 [词库兼容性](docs/COMPATIBILITY.md#共享词库兼容性)。

## 当前验证范围

已检查本机 Typeless 2.8.1 与 Chatterfly 1.0.7.13415 的应用身份，确认 Chatterfly 的快捷键设置入口，并核对部分厂商的语音和翻译文档。辅助功能、输入监控授权后的 Fn → 录音 → 上屏，以及 Fn + Shift 翻译链路尚未完成本机验收。

30 项测试通过，覆盖 Fn / Shift + Fn、普通组合键透传、切换时取消手势、监听中断、快捷键冲突与配置序列化，以及词表格式、去重和备份合并身份。原生事件构造检查覆盖左右 Shift 恢复、纯修饰键及 Caps Lock。已完成 arm64 应用构建、ad-hoc 签名校验及主界面运行检查。

共享词库已完成文件导入、持久化与重载检查。Chatterfly 的真实导入预览成功扫描生成的 6 条词汇，去重后正确显示 1 条新增词汇；测试停在预览阶段。词库读取失败后的原文件保留，以及 JSON 备份合并后的词条身份，也已验证。

这些检查不能证明第三方应用会接收合成快捷键，也不能证明录音、翻译及文字上屏成功。界面中的当前选择表示按键路由目标。

## 数据与权限

Voice Switch 在本机处理快捷键事件，不录音，不记录键入内容，不调用网络服务。应用配置、主动添加或导入的词条，以及准备交给原应用的词表，保存在：

```text
~/Library/Application Support/Voice Switch/configuration.json
~/Library/Application Support/Voice Switch/vocabulary.json
~/Library/Application Support/Voice Switch/Exports/
```

「辅助功能」用于转发快捷键，「输入监控」用于识别 Fn 与组合键。语音应用自行管理麦克风权限、语音数据和网络请求；点击官网入口会通过浏览器打开对应网站。

## English

Voice Switch is a native macOS menu bar app that routes **one Fn key** to the selected dictation app. Tap Fn to start and tap again to stop; Fn + Shift triggers the app's separately configured translation shortcut. Apps stay running, so switching only changes the routing target.

One-time setup: grant Accessibility and Input Monitoring, remove **all native Fn bindings** from every running dictation app, assign unique internal shortcuts, and test each integration. Configure toggle mode where the app offers it. Chatterfly uses a modifier-only combination of up to three keys. Translation requires an actual translation action in the target app.

The shared vocabulary keeps terms and notes locally. Import or export TXT and headerless single-column CSV, or use JSON for a complete backup. Chatterfly's local dictionary stores encoded or encrypted values, so direct database import is unavailable. The Typeless and Chatterfly handoff prepares a CSV file and opens the vendor app; complete the import in its dictionary UI. Changes are applied manually, without background two-way synchronization.

Requires macOS 13+. Build with `./scripts/build-app.sh`, or add `--install` to install into `~/Applications`. Source supports native Apple Silicon and Intel builds; the current local build is arm64. Builds are not Developer ID signed or notarized. See [compatibility notes](docs/COMPATIBILITY.md) for evidence and testing limits.

## License

[MIT](LICENSE) © Voice Switch contributors.
