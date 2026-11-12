<p align="right">简体中文 · <a href="README.en.md">English</a></p>

<div align="center">

<img src="docs/assets/icon-256.png" width="112" alt="Maclean 应用图标"/>

# Maclean

**关掉屏幕，或者，安心擦干净它。**

让显示器立刻休眠，或者进入全黑的清洁模式擦屏幕。不锁屏、不让 Mac 睡眠、不联网。

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-black?style=flat-square)
![Universal](https://img.shields.io/badge/arch-universal-555?style=flat-square)
[![License: MIT](https://img.shields.io/badge/license-MIT-2563EB?style=flat-square)](LICENSE)
[![Latest release](https://img.shields.io/github/v/release/EathonEvans/maclean?label=release&style=flat-square)](https://github.com/EathonEvans/maclean/releases)

[下载](https://github.com/EathonEvans/maclean/releases) · [产品主页](https://eathonevans.github.io/maclean/) · [问题反馈](https://github.com/EathonEvans/maclean/issues)

</div>

---

## 功能

Maclean 常驻菜单栏，只有两个动作。

**显示器休眠**：关闭所有显示器。不锁屏、不睡眠，后台任务照常跑，碰一下鼠标或键盘就亮回来。离开座位想挡一下屏幕，或者晚上不想让屏幕亮着，用这个。

**清洁模式**：所有显示器变纯黑，同时屏蔽键盘输入，擦屏幕、擦键盘时随便碰都不会误触。退出方式是把鼠标停在屏幕中央的提示卡片上，停 1.5 秒即可；移开重新计时，卡片上能看到进度。

设置里只有两个选项：登录时启动，悬停退出时长（0.5–5 秒）。

和锁屏、手动关显示器的区别：

|                     | 擦的时候                                       | 恢复                                     |
| ------------------- | ---------------------------------------------- | ---------------------------------------- |
| 锁屏（⌃⌘Q）         | 屏幕不全黑，擦键盘时按键会输进密码框           | 要输密码                                 |
| 只关显示器          | 碰到鼠标或键盘就亮                             | 即时                                     |
| 常见清洁类 App      | 类似                                           | 靠快捷键或密码退出，部分收费、带广告     |
| Maclean             | 屏幕全黑，键盘被屏蔽                           | 鼠标停中央卡片 1.5 秒                    |

几个细节：

- 多显示器每块屏独立黑屏，任意一块屏上悬停都能退出；清洁中插拔显示器、改分辨率会自动同步。
- 单次清洁最长 10 分钟自动退出，异常情况会安全退出并恢复键盘，不存在退不出去的黑屏。
- 显示器休眠失败会明确报错，不会静默。
- 清洁模式没有快捷键退出，因为键盘正在被屏蔽，留快捷键反而容易误触。

## 安装

从 [Releases](https://github.com/EathonEvans/maclean/releases) 下载 DMG 或 PKG，建议装到 `/Applications`。要求 macOS 14 以上，Intel 和 Apple Silicon 都支持。

没有 Apple 签名和公证，首次打开会被 Gatekeeper 拦一下：

- macOS 15 及以上：双击 Maclean，然后到 系统设置 → 隐私与安全性 点「仍要打开」。
- macOS 14：右键 Maclean → 打开 → 再点「打开」。

也可以用终端移除隔离属性：

```bash
xattr -dr com.apple.quarantine /Applications/maclean.app
```

## 辅助功能权限

只有清洁模式需要，显示器休眠不需要任何权限。第一次点「清洁模式」会引导你去 系统设置 → 隐私与安全性 → 辅助功能，勾选 Maclean 后回来再点一次就行。

不给权限的话清洁模式不会启动，会提示错误。

## 隐私

不联网、不登录、没有统计和广告。清洁模式下键盘按键被直接丢弃，不读取内容；鼠标位置只用来判断有没有停在退出卡片上。日志走 macOS 系统日志，不含按键内容，也没有本地日志文件。

## 常见问题

<details>
<summary><strong>显示器休眠会锁屏吗？</strong></summary>

不会。只关屏幕，不锁屏、不睡眠，恢复时也不用输密码。如果要离开电脑，请另外锁屏（⌃⌘Q）。
</details>

<details>
<summary><strong>清洁模式里键盘没反应，怎么退出？</strong></summary>

鼠标停在屏幕中央的卡片上 1.5 秒。键盘此时被屏蔽，所以没有快捷键退出；鼠标用不了的话，10 分钟后会自动退出。
</details>

<details>
<summary><strong>会读取我的键盘输入吗？</strong></summary>

不会。按键在清洁模式下被直接丢弃，程序拿不到字符内容。
</details>

<details>
<summary><strong>怎么卸载？</strong></summary>

退出 Maclean，把 `/Applications/maclean.app` 丢进废纸篓。开过登录时启动的话，先在 系统设置 → 通用 → 登录项 里移除。
</details>

<details>
<summary><strong>为什么不上架 App Store？</strong></summary>

键盘屏蔽和显示器休眠跟商店的沙盒规则冲突，所以用 DMG / PKG 独立分发。
</details>

## 支持开发者

Maclean 免费开源。觉得好用的话，可以请作者喝杯咖啡，或者点个 Star。

<p align="center">
  <img src="docs/assets/donate-wechat.png" width="200" alt="微信赞赏码"/>
  &nbsp;&nbsp;&nbsp;&nbsp;
  <img src="docs/assets/donate-alipay.png" width="200" alt="支付宝收款码"/>
</p>
<p align="center"><sub>微信（左） · 支付宝（右）</sub></p>

## 许可证

[MIT](LICENSE) © 2026 EathonEvans
