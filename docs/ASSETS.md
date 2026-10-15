# 第三方产品图标

声选使用产品原有图标帮助识别输入法。图标、商标及相关品牌权利归各产品权利人所有，**不属于本项目 MIT 许可证的授权范围**。图标用于指示兼容的第三方应用，不表示获得其背书或与其存在合作关系。

图标加载顺序：用户指定的应用路径、macOS 按 bundle identifier 查到的应用、系统及用户的 Applications / Input Methods 目录，最后是随包保存的品牌图标。发现本机应用时由 `NSWorkspace` 读取其当前图标；自定义应用也使用系统提供的图标。图标显示不发起网络请求。

下列资源于 2026-10-15 获取，并逐一检查了实际图像。官网页面中的图标可能随产品更新，已安装应用的图标优先。

| 资源 | 来源及归属 | 获取方式 |
| --- | --- | --- |
| `typeless.png` | [Typeless](https://www.typeless.com/)，Typeless 产品权利人 | 本机 Typeless 2.8.2（2.8.2.131）应用声明的 `Contents/Resources/icon.icns`，使用 macOS `sips` 转为 PNG。 |
| `chatterfly.png` | [Chatterfly](https://chatterfly.tencent.com/)，腾讯 | 本机 Chatterfly 1.0.7.13415 应用声明的 `Contents/Resources/chatterfly.icns`，使用 macOS `sips` 转为 PNG。 |
| `doubao.png` | [豆包输入法官网](https://shurufa.doubao.com/pc)，北京春田知韵科技有限公司及相关权利人 | 官网 HTML 声明的 [180 × 180 Apple touch icon](https://lf-speechfe-cdn.bytespeech.com/obj/speechfe-cdn/deploy/gaowujian/wave_site/241784/static/image/apple-touch-icon.682ddf1c.png)。 |
| `wetype.png` | [微信输入法官网](https://z.weixin.qq.com/)，腾讯 | 官网 HTML 声明的 [152 × 152 Apple touch icon](https://cdn.weread.qq.com/web/wetype/favicon/icon-152.png)。 |
| `spokenly.png` | [Spokenly 官网](https://spokenly.app/)，Spokenly 产品权利人 | 官网 HTML 声明的 [512 × 512 产品图标](https://spokenly.app/icons/icon_512x512.png)。对应 `spokenly.app` 的听写应用。 |
| `shandian.png` | [闪电说官网](https://shandianshuo.cn/)，闪电说产品权利人 | 官网 HTML 声明的 [180 × 180 Apple touch icon](https://shandianshuo.cn/apple-touch-icon.png?v=3)。 |

PNG 文件位于 `Sources/VoiceSwitch/Resources/ProviderIcons/`。远程 PNG 保留原始文件；ICNS 仅做格式转换，没有重新绘制、改色或加入装饰。SwiftPM 将目录复制到 `VoiceSwitch_VoiceSwitch.bundle`，`scripts/build-app.sh` 再把该资源包放入应用的 `Contents/Resources`。

维护图标时从对应官网或已安装的官方应用获取，保留直接资源链接及版本信息，并核对实际图像对应的产品。
