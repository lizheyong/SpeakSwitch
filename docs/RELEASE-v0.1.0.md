# 声选 · SpeakSwitch v0.1.0

首个公开预览版。一个 Fn，自由切换语音输入法。

语音工具的体验、价格和免费额度都在变化。声选让各应用保持运行，将 Fn 交给当前选择的应用；换工具时保留熟悉的操作。

- Fn 点按开始、再次结束；Shift + Fn 触发已接入的翻译。
- 菜单栏选择，或用 Control + Option + Command + Space 循环切换，并显示切换提示。
- 原生 macOS 界面、真实应用图标、四步接入助手及权限引导。
- 本机共享词表，支持 TXT / CSV 导入导出和 JSON 备份；支持导入的应用由用户手动交接词表。
- 按输入法查看启动次数与估算使用时长。

## 下载与上手

下载附件 `SpeakSwitch-arm64.zip`，解压后将 `声选.app` 放到 Applications 文件夹，跟随助手选择输入法、开启权限、配置专属快捷键并试用 Fn。

需要 macOS 13+，此安装包面向 Apple Silicon。Intel Mac 可以从源码构建。此预览版使用本地 ad-hoc 签名，未使用 Developer ID 签名、未经 Apple 公证；仅在信任源码及下载来源后运行，打开方式见 [Apple 官方说明](https://support.apple.com/zh-cn/102445)。附件 `SHA256SUMS.txt` 用于核对下载文件。

## 兼容性与验证

已记录 Typeless 2.8.2、Chatterfly 1.0.7.13415、微信输入法 2.2.3 (657) 的真实 Fn 开始、结束和文字上屏；翻译仅 Typeless 已实测。豆包、Spokenly、闪电说提供接入模板，尚未实测。也可以添加支持可配置全局快捷键的其他应用。

当前代码通过 61 项测试，更名后的助手与设置界面已完成本机检查，发布包解压后的程序与本机安装版本一致。三款输入法的真人语音结果来自各自的功能构建，尚未在此发布包逐项重测。查看 [完整兼容性记录](https://github.com/lizheyong/SpeakSwitch/blob/main/docs/COMPATIBILITY.md)。

切换前先结束录音；所有常驻语音应用与系统听写都需要释放 Fn。共享词表为手动导入导出，没有后台双向同步。使用时长根据 Fn 开始、结束操作估算，无法验证原应用实际录音状态。

声选不录音、不记录其他应用中的键入内容、不调用语音模型。项目代码采用 MIT，第三方图标与商标归各自权利人所有。

[使用说明](https://github.com/lizheyong/SpeakSwitch#readme) · [反馈问题](https://github.com/lizheyong/SpeakSwitch/issues)
