# 兼容性记录

核查日期：2026-10-15。

Voice Switch 把 Fn 的一次按下与松开，转发为当前应用的语音输入快捷键；Fn + Shift 调用单独配置的翻译快捷键。语音应用保持运行，切换时改变路由目标。

接入条件是：原应用允许设置不含 Fn 的独有全局快捷键，并接受系统合成键盘事件。语音输入需要支持单击切换录音；翻译设置需要对应原应用实际提供的翻译动作。下面区分官方说明、本机检查和实际使用验证。

## 内置模板

| 应用 | 已取得的依据 | 接入建议 | 实际 Fn 链路 |
| --- | --- | --- | --- |
| Typeless | 本机 2.8.1 最多接受 3 个键，修饰键也计数；官方支持分别修改 Dictate 和 Translate，翻译由主语音快捷键结束 | 本机已设置 Dictate `⌃⌥1`、Translate `⌃⌘1`，并同步到 Voice Switch；Ask anything 为 `⌥⌘1`，已释放所有 Fn 绑定 | 已完成设置核对和常驻切换；真实 Fn 听写及翻译上屏待用户验收 |
| Chatterfly | 本机 1.0.7.13415，语音输入和 AI 指令使用独立修饰键组合 | 语音输入 `⌃⌥⇧`；指令模式 `⌥⇧⌘`；翻译未接入 | 2026-10-15 用户实际点按 Fn 开始、结束并成功输入文字，确认由 Chatterfly 处理 |
| 豆包输入法 | 官网提供 macOS 语音输入；本机未安装，未核实当前版本快捷键与翻译设置 | 在原应用中确认语音单击切换、独立快捷键和翻译动作，测试后接入 | 待测试 |
| 微信输入法 | 已确认官方产品入口；本机未安装，未核实当前版本语音快捷键与翻译设置 | 选择实际的微信输入法应用，分别核对语音和翻译设置 | 待测试 |
| Spokenly | 官方支持每个 mode 的独立快捷键、toggle 激活方式，以及通过 AI Instructions 配置翻译；本机未安装 | 为语音和翻译 mode 设置独立快捷键，语音使用 toggle | 待测试 |
| 闪电说 | 官方说明快捷键按用户配置变化，短按为「直接说」，长按为「帮我说」；本机未安装 | 确认短按切换行为；单独核实翻译动作及快捷键 | 待测试 |

列表中的默认快捷键是建议值。请在原应用中真正设置相同组合，并完成测试后标记已接入。Voice Switch 不会读取或修改第三方应用的私有快捷键配置。

## 翻译的含义

翻译是可选的独立映射。填写翻译快捷键之前，应先在原应用确认该快捷键确实会进入所需的翻译功能。

- Typeless 官方文档说明：按翻译快捷键开始，按主语音快捷键结束；Voice Switch 的 Fn + Shift 与 Fn 可分别映射这两个动作。
- Spokenly 使用 mode 和 AI Instructions 组织翻译行为，可给该 mode 单独配置快捷键。
- Chatterfly 的 AI 指令入口本身不能证明它等于独立翻译模式，需要在当前版本中验证具体动作。
- 其他模板的翻译能力保留为待确认状态，按当前版本的设置和实际结果记录。

Voice Switch 转发快捷键，翻译目标语言、模式和结果由原应用管理。

## 共享词库兼容性

共享词库保存标准写法和备注。TXT 与 CSV 只导出标准写法；JSON 备份保留备注。提供给输入法的 CSV 使用 UTF-8、单列、无表头，每行一个词。含逗号或引号的词按 CSV 规则引用。

| 应用 | 已确认的词库入口或格式 | Voice Switch 当前对接 |
| --- | --- | --- |
| Typeless | [官方说明](https://www.typeless.com/help/quickstart/history-and-dictionary)提供 Dictionary → New word → Import CSV；本机 2.8.1 界面文案要求单列、每行一个词，文件最大 5 MB | 生成单列 CSV、在 Finder 定位文件并打开应用，由用户在词库中完成导入 |
| Chatterfly | 本机 1.0.7.13415 的个人词库 → 添加新词包含「导入 CSV」；应用文案要求单列、每行一个词，包含导入预览 | 生成单列 CSV、定位文件并打开设置，由用户在词库中完成导入；不支持直接读取其本机数据库词条 |
| Spokenly | [Dictionary](https://spokenly.app/docs/custom-dictionary)按识别模型设置；ElevenLabs Scribe 的 Keyterms 使用逗号分隔，实时识别应用前 50 个词 | 导出词表供用户按模型要求填写；当前没有自动写入模型设置 |
| 闪电说 | [官方指南](https://shandianshuo.cn/docs)支持将人名、产品名和术语的标准写法加入词典；尚未核实批量导入格式 | 可导出通用词表，按当前版本词典界面添加 |
| 豆包输入法、微信输入法、自定义应用 | 尚未核实当前版本的词库导入格式 | 可导出通用词表，先确认原应用接受的格式 |

「准备导入」表示文件已生成。词库是否被接受、是否超出容量，以及最终导入数量，以原应用的预览和结果为准。当前没有后台双向同步；主词库的编辑、删除不会自动改变原应用已有词条。Voice Switch 不写入第三方应用的私有词库数据库。

2026-10-15 本机验收：将 Voice Switch 生成的 CSV 交给 Chatterfly 1.0.7.13415，原生预览显示「共扫描到 6 条词汇，其中有效词汇 1 条」，并正确显示新增词语 `Voice Switch`。其他 5 条已存在于原词库。测试在预览阶段取消，未重复写入已有词条。

本机 Chatterfly 1.0.7.13415 的 `ybdict.sqlite` 中，`ybdict_terms.text` 保存的是编码或加密后的表示，与词库界面显示的明文不一致。行数一致只能证明存在记录，不能证明词条内容可用。当前没有可用的明文读取适配，Voice Switch 不直接导入该数据库。已有词条需要通过兼容的词表文件导入，或在共享词库中手动维护；CSV 导入 Chatterfly 的入口与格式已单独确认。

标准词汇与纠错替换是两类设置。Spokenly 的 [Word Replacements](https://spokenly.app/docs/word-replacements)需要「原文本 → 替换文本」，并提供 [官方 CLI](https://spokenly.app/docs/macos/cli)和 JSON 备份；单独一个标准词不能自动推导出正确的替换规则。Voice Switch 当前仅管理标准词汇，备注不会作为替换规则发送。

## 本机确认的应用身份

| 应用 | 路径 | Bundle ID |
| --- | --- | --- |
| Typeless | `/Applications/Typeless.app` | `now.typeless.desktop` |
| Chatterfly | `/Library/Input Methods/Chatterfly.app` | `com.tencent.inputmethod.chatterfly` |
| Chatterfly 设置 | `/Library/Input Methods/Chatterfly.app/Contents/ChatterflyPreference.app` | `com.tencent.ChatterflyPreference` |

其他模板的应用名称和标识用于查找候选应用。找不到时，使用应用选择面板定位真实 `.app`。微信聊天客户端与微信输入法是不同应用。

## Chatterfly 的特殊点

本机版本的快捷键设置包含以下提示：

- 「快捷键需要小于等于3个」
- 「暂不支持，推荐使用Fn/⌘/⌥/⌃/⇧的组合键」
- 「该按键不支持双击」

因此语音模板采用三个纯修饰键 `⌃⌥⇧`。是否接受该组合、是否响应合成事件，以原应用中的实际设置和触发结果为准。

纯修饰键快捷键需要避开其他快捷键的前缀。默认使用 `⌃⌥⇧`，让其他应用的 `⌃⌥⌘` 加数字，以及切换应用的 `⌃⌥⌘Space` 保持独立。翻译映射同样需要避免前缀冲突。

本机 Chatterfly 在没有列入当前启用的系统输入源时，仍运行全局语音功能。切换键盘输入源不能据此保证释放 Fn，接入步骤需要清理语音输入和 AI 指令等全部原生 Fn 绑定。

## 自定义应用

通过「添加应用」选择 `.app`，设置名称、内部快捷键和备注。新工具、开源语音应用也使用相同流程。应用需要完成自身账号、模型、麦克风权限和上屏权限设置。

建议按以下顺序验收：

1. 直接按原应用的内部语音快捷键，确认按一下开始、再按一下结束，并且文字进入目标输入框。
2. 需要翻译时，直接测试原应用的翻译快捷键和结束方式。
3. 使用 Voice Switch 的快捷键测试，确认合成事件能触发原应用。测试会延迟发送快捷键，便于切换到空白文字输入框；如开始录音，在原应用中结束。
4. 开启 One Fn，测试 Fn 开始和结束、Fn + Shift 翻译，以及文字上屏的位置。
5. 切换到另一已接入应用，确认只有当前路由目标响应。
6. 测试平时使用的 Fn + Delete 等组合键。

## 运行边界

- 所有正在运行的语音应用都需要移除原生 Fn 绑定，包含 Fn + Shift、翻译、语音指令等附加功能。
- macOS 自身的 Fn 动作与听写快捷键也需要避开 Fn。
- 当前路由目标由 Voice Switch 管理；原应用实际是否开始录音，需要看原应用的状态。
- 切换前先结束当前录音。Voice Switch 的按键指示仅表示 Fn 按下，当前没有跨应用的统一录音状态控制。
- 外接键盘的 Fn 若只在键盘固件内部工作，macOS 无法将它提供给 Voice Switch。
- 安全输入、权限变更以及第三方应用升级可能影响快捷键事件。以当前输入框里的实际结果为准。
- Fn 松开时发送一次完整快捷键；原应用的单击模式决定录音如何切换。
- 当前本机尚未完成授权后的完整 Fn 录音、Fn + Shift 翻译及文字上屏验收。

## 官方依据

- [Typeless：修改快捷键](https://www.typeless.com/help/quickstart/settings)
- [Typeless：Translate 开始与结束方式](https://www.typeless.com/help/quickstart/translate)
- [Chatterfly 官网](https://chatterfly.tencent.com/)
- [豆包输入法官网](https://srf.doubao.com/pc)
- [微信输入法官网](https://z.weixin.qq.com/)
- [Spokenly：Modes、翻译与激活方式](https://spokenly.app/docs/modes)
- [Spokenly：官方 deeplinks](https://spokenly.app/docs/macos/deeplinks) 提供录音控制 URL，当前 Voice Switch 统一使用快捷键接入。
- [闪电说：入门与快捷键语义](https://shandianshuo.cn/docs)
