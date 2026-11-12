<p align="right">简体中文 · <a href="README.en.md">English</a></p>

<div align="center">

<img src="docs/assets/icon-256.png" width="112" alt="Maclean 应用图标"/>

# Maclean

**关掉屏幕，或者，安心擦干净它。**

一个只做两件事的 macOS 菜单栏工具：让显示器休眠，或进入纯黑清洁模式。
不锁屏、不睡眠、不联网、不读取你的按键内容。

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-black?style=flat-square)
![Universal](https://img.shields.io/badge/arch-universal-555?style=flat-square)
[![License: MIT](https://img.shields.io/badge/license-MIT-2563EB?style=flat-square)](LICENSE)
[![Latest release](https://img.shields.io/github/v/release/EathonEvans/maclean?label=release&style=flat-square)](https://github.com/EathonEvans/maclean/releases)

[下载](https://github.com/EathonEvans/maclean/releases) · [产品主页](https://eathonevans.github.io/maclean/) · [问题反馈](https://github.com/EathonEvans/maclean/issues)

</div>

---

Maclean 常驻菜单栏，只有两个动作：**显示器休眠**和**清洁模式**。

它不接管系统设置，不要求登录账号，也不在后台做别的事。两个功能都不复杂，但每一个都按“要长期用”的标准做了安全兜底。

## 为什么用它

- **擦屏幕、擦键盘时不怕误触**：清洁模式屏蔽普通键盘输入，所有显示器变纯黑，不需要先锁屏再解锁。
- **退出方式看得见**：屏幕中央常驻一张提示卡片，把鼠标停上去 1.5 秒即可退出。卡片本身就是热区，不用猜位置。
- **为“退不出去”做了兜底**：EventTap 持续失效会自动安全退出，单次清洁最长 10 分钟，主线程还有看门狗。即使出错，也有多层兜底把你送回桌面。
- **显示器休眠不是锁屏，也不是睡眠**：只关闭显示器，不打断正在运行的任务，不要求重新认证，不改动系统睡眠设置。
- **完全离线**：不联网、不登录、不做统计；键盘按键在事件回调里直接丢弃，不读取字符内容。

## 功能

### 显示器休眠

点一下菜单栏里的「显示器休眠」，所有显示器立即关闭。

- 只关显示器：不锁屏、不让 Mac 整机睡眠、不要求重新认证、不修改系统睡眠设置。
- 不持有阻止显示器休眠的电源断言，底层调用系统 `pmset displaysleepnow`。
- 唤醒方式和平时一样：移动鼠标、按键盘或按电源键（取决于你的设备与系统设置）。
- 执行失败会给出明确错误，不会静默失败。

> **注意**：显示器休眠不等于锁屏。如果你要离开电脑，请另外锁定屏幕（默认快捷键 `⌃⌘Q`）。

### 清洁模式

从菜单栏选择「清洁模式」，所有活动显示器立刻变成纯黑全屏，普通键盘输入被临时屏蔽。

- **普通键盘全屏蔽**：过滤 `keyDown`、`keyUp`、`flagsChanged`，清洁时不会响应普通按键，也不读取按键内容。
- **看得见的退出方式**：每块屏幕中央常驻一张半透明卡片，显示圆环进度、「悬停 1.5 秒即可退出」和「已禁用键盘」。
- **悬停退出**：把鼠标移到卡片上并停留设定时长即可退出；默认 1.5 秒，可在设置中调整为 0.5–5 秒。
- **离开即重置**：鼠标离开卡片立即归零；从一块屏移到另一块屏会重新计时。
- **任意一块屏都能退出**：任意显示器完成悬停，所有屏幕一起退出。
- **安全兜底**：单次清洁最长 10 分钟自动退出；EventTap 持续失效会自动安全退出；退出后键盘立即恢复。
- **多显示器**：每块屏幕独立黑屏窗口与热区；插拔显示器、分辨率变化实时同步；镜像模式自动去重。

> **怎么退出？** 把鼠标移到屏幕中央的提示卡片上，停留 1.5 秒（可调）。卡片就是热区。清洁模式刻意不提供键盘快捷键退出——此时键盘正在被屏蔽；如果鼠标不可用，最多等 10 分钟会自动退出。

### 设置

- **登录时启动**：可选，使用系统 `SMAppService`，可在「系统设置 → 通用 → 登录项」中管理。
- **退出悬停时长**：0.5–5 秒，默认 1.5 秒。
- 其他选项刻意保持为零。

## 安装

### 系统要求

- macOS 14 Sonoma 或更高版本
- Intel 或 Apple Silicon（通用二进制）
- 安装包约 2 MB

### 下载安装

从 [Releases](https://github.com/EathonEvans/maclean/releases) 下载最新版本：

- **DMG**：打开后把 Maclean 拖进「应用程序」。
- **PKG**：按安装器提示安装到 `/Applications`。

建议安装到 `/Applications`：登录时启动（`SMAppService`）和权限记忆都更稳定。

### 首次打开

Maclean 没有使用 Apple Developer ID 签名，也未做公证，首次打开会被 Gatekeeper 拦截。请按你的 macOS 版本操作：

**macOS 15 及更高版本**

1. 双击 Maclean，出现「Apple 无法验证此 App 是否包含恶意软件」。
2. 打开 **系统设置 → 隐私与安全性**，在「安全性」区域点 **仍要打开**。
3. 按提示输入密码并确认；如果应用没有自动启动，再双击一次 Maclean。

**macOS 14**

1. 在 Finder 中右键（或按住 Control 点击）Maclean。
2. 选择「打开」，在弹窗中再次点「打开」。

如果你确认文件来源可信，也可以用终端移除隔离属性：

```bash
xattr -dr com.apple.quarantine /Applications/maclean.app
```

> 未公证意味着下载新版本后，可能再次触发上述确认。这是 Gatekeeper 对未公证应用的正常行为。

## 首次使用清洁模式：辅助功能权限

显示器休眠不需要任何权限。**只有清洁模式的键盘屏蔽需要「辅助功能」权限**，且只在你第一次点击「清洁模式」时才会提示授权。

1. 打开 Maclean，点「清洁模式」。
2. 弹窗提示需要权限时，点「打开系统设置」。
3. 在 **隐私与安全性 → 辅助功能** 中勾选 Maclean。
4. 回到 Maclean，再次点击「清洁模式」。

如果列表里 Maclean 已经勾选、但应用仍提示缺权限（常见于重新构建或更换签名后），选中 Maclean 点「−」移除，然后重新点击「清洁模式」并按提示授权。

**权限被拒绝时会发生什么？** 清洁模式不会进入：应用会回滚并提示错误，不会只留一块黑屏骗你。

## 隐私

Maclean 不联网、不需要账号，也不包含统计、广告或自动更新。

- **键盘**：只在清洁模式中过滤按键事件，不读取、不记录、不上传字符内容。
- **鼠标**：仅在清洁模式中用于判断热区；不写入应用自有的轨迹文件，不上传。
- **网络**：应用不发起任何网络请求。
- **日志**：使用 macOS 统一日志（subsystem `com.ethon.maclean`），不含键盘内容。清洁期间为排查热区 / 多屏问题，会每 3 秒记录一条鼠标位置与热区判定的诊断日志；没有本地日志文件。

你可以自己检查：

```bash
log show --predicate 'subsystem == "com.ethon.maclean"' --last 30m --style compact
```

## 已知限制

- 不承诺拦截 Secure Input、系统安全界面、硬件功能键，以及部分系统保留快捷键；这是普通非沙盒 App 的能力边界。
- 清洁模式没有键盘快捷键退出通道（设计如此）；鼠标不可用时依赖 10 分钟上限自动退出。
- 单次清洁最长 10 分钟，到时自动退出。
- EventTap 被系统持续禁用时会安全退出清洁模式，因此极端情况下清洁可能提前结束。
- 显示器休眠依赖系统 `pmset`；若系统策略限制，会提示失败而不会静默。
- 仅支持 macOS 14+；未使用 Apple Developer ID 签名、未公证、未上架 Mac App Store。
- 应用界面目前仅提供中文。

## 从源码构建

### 环境要求

- macOS 14+
- Xcode（含命令行工具）
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)：`brew install xcodegen`

### 构建

```bash
git clone https://github.com/EathonEvans/maclean.git
cd maclean

./scripts/make-dev-cert.sh   # 首次构建：创建本地自签名证书 maclean-dev
make assets                  # 可选：从 assets/logo.svg 重新生成图标
make build                   # 编译，产物为 build/maclean.app
make test                    # 运行单元测试
make run                     # 构建并启动
make package                 # 生成 dist/ 下的 DMG 与 PKG
```

工程文件由 `project.yml` 通过 XcodeGen 生成，`maclean.xcodeproj/` 不纳入版本管理。要使用 Xcode 开发：

```bash
make generate
open maclean.xcodeproj
```

### 为什么需要自签名证书？

`project.yml` 固定使用名为 `maclean-dev` 的本地自签名证书，而不是 ad-hoc 签名。原因是 macOS 的「辅助功能」授权与代码签名绑定：ad-hoc 签名每次重新构建指纹都会变化，导致每次都要重新授权；固定证书可以让授权在多次构建之间保持有效。

`scripts/make-dev-cert.sh` 会：

1. 用 `openssl` 生成一张 10 年期的本地代码签名证书；
2. 将证书导入登录钥匙串；
3. 将证书设为本地信任根。

证书仅用于本机开发签名，不会上传，也不代表 Apple 开发者身份。如果不运行该脚本，`make build` 会因找不到 `maclean-dev` 证书而失败。

> 重建签名或更换证书后，旧的辅助功能授权可能失效；按上文「辅助功能权限」的步骤移除并重新添加即可。

### 构建配置

| 项目              | 值                          |
| ----------------- | --------------------------- |
| Deployment Target | macOS 14.0                  |
| Swift             | 5.0                         |
| 产物架构          | Universal（x86_64 + arm64） |
| 第三方运行时依赖  | 无                          |

<details>
<summary><strong>项目结构</strong></summary>

```text
maclean/
├── maclean/
│   ├── App/                    # 应用生命周期、依赖容器
│   ├── Core/
│   │   ├── Display/            # 显示器标识与变化监听
│   │   ├── Input/              # CGEventTap 键盘过滤
│   │   └── Utilities/          # 常量、日志、错误、弹窗
│   ├── Features/
│   │   ├── Cleaning/           # 清洁模式状态机、窗口、HUD、热区
│   │   ├── DisplaySleep/       # 显示器休眠
│   │   ├── MenuBar/            # 菜单栏面板
│   │   └── Settings/           # 设置
│   └── Resources/              # 图标资源
├── Tests/                      # 38 个单元测试
├── scripts/                    # 图标生成、证书、打包
├── assets/                     # 品牌 SVG
├── docs/                       # GitHub Pages 产品页与图片
├── project.yml                 # XcodeGen 工程定义
└── Makefile
```

</details>

## 实现要点

SwiftUI（菜单栏面板 / 设置 / HUD）+ AppKit（全屏窗口 / 状态项）+ CoreGraphics（事件 / 显示器），无第三方运行时依赖。

几个值得读的设计：

- **EventTap 专用线程**：键盘过滤在独立线程创建，主线程最多等待 2 秒；超时即回滚，避免主线程被系统调用卡死。见 [`KeyboardEventMonitor.swift`](maclean/Core/Input/KeyboardEventMonitor.swift)。
- **事务式进入 / 退出**：先准备窗口和监听，再统一展示；任一步失败回滚，所有退出路径走同一个幂等方法。见 [`CleaningManager.swift`](maclean/Features/Cleaning/CleaningManager.swift)。
- **热区 = HUD**：提示卡片和热区使用同一套几何公式，看见的就是能悬停的。见 [`DisplayHotspot.swift`](maclean/Features/Cleaning/DisplayHotspot.swift)。
- **单调时钟计时**：悬停进度按真实经过时间计算，不受主线程卡顿影响；边缘带滞后防止抖动重置。见 [`MousePositionMonitor.swift`](maclean/Features/Cleaning/MousePositionMonitor.swift)。
- **多显示器**：以 `CGDirectDisplayID` 为 key，每块屏独立窗口和热区，热插拔 / 唤醒后重建。见 [`CleaningWindowManager.swift`](maclean/Features/Cleaning/CleaningWindowManager.swift)。
- **图标自动化**：一份 SVG 生成 AppIcon、菜单栏模板图标和菜单项图标。见 [`scripts/generate-assets.swift`](scripts/generate-assets.swift)。

## 常见问题

<details>
<summary><strong>会锁屏或让 Mac 睡眠吗？</strong></summary>

不会。显示器休眠只调用 `pmset displaysleepnow` 关闭显示器，不锁屏、不整机睡眠、不改系统设置。
</details>

<details>
<summary><strong>清洁模式的键盘屏蔽会一直生效吗？</strong></summary>

不会。退出清洁模式时先停止事件监听，键盘立即恢复；应用崩溃时系统会回收事件 tap，EventTap 失效时应用会主动停止并安全退出。单次清洁还有 10 分钟上限。
</details>

<details>
<summary><strong>为什么没有快捷键退出？</strong></summary>

因为清洁模式的目的就是屏蔽键盘，任何逃生快捷键都必须被特殊放行，反而增加误触风险。退出方式统一为悬停中央卡片；鼠标不可用时等待 10 分钟自动退出。
</details>

<details>
<summary><strong>为什么需要辅助功能权限？会读取我的按键吗？</strong></summary>

只用于在清洁模式中过滤键盘按下 / 松开事件。事件在回调里直接丢弃，不读取字符内容、不落盘、不上传。显示器休眠和其余功能不需要该权限。
</details>

<details>
<summary><strong>支持多显示器和热插拔吗？</strong></summary>

支持。每块显示器独立黑屏窗口和热区；清洁过程中插入 / 拔出显示器、修改分辨率或排列会实时同步；镜像模式只保留一块，避免重复。
</details>

<details>
<summary><strong>如何卸载？</strong></summary>

退出 Maclean，将 `/Applications/maclean.app` 移到废纸篓即可。如果开启过登录时启动，先在「设置 → 通用」关闭，或在「系统设置 → 通用 → 登录项」中移除。辅助功能里的条目可在「系统设置 → 隐私与安全性 → 辅助功能」中删除。
</details>

<details>
<summary><strong>为什么不在 Mac App Store 上架？</strong></summary>

全局键盘过滤（CGEventTap）与显示器休眠（`pmset`）与 App Sandbox / 商店审核模型并不契合，因此目前以独立分发的 DMG / PKG 提供。
</details>

<details>
<summary><strong>支持 macOS 13 吗？</strong></summary>

目前最低支持 macOS 14。更早版本未测试，欢迎提交兼容性 PR。
</details>

## 参与贡献

欢迎 issue 和 PR。比较大的改动建议先开 issue 说明场景和方案。

- 构建和测试命令见上文；提交前请至少跑一次 `make test`。
- 项目刻意保持零第三方运行时依赖；新增依赖前请先讨论。
- 清洁模式的状态只能由 `CleaningManager` 统一管理，其他模块只上报事件。
- 不要记录、上传任何键盘内容。

## 支持开发者

Maclean 使用 MIT 协议开源，免费使用，无订阅、无广告。如果它帮你省了时间，欢迎请作者喝杯咖啡，或点个 ⭐ Star。

<p align="center">
  <img src="docs/assets/donate-wechat.png" width="180" alt="微信赞赏码"/>
  &nbsp;&nbsp;&nbsp;&nbsp;
  <img src="docs/assets/donate-alipay.png" width="180" alt="支付宝收款码"/>
</p>

## 许可证

[MIT](LICENSE) © 2026 EathonEvans

Maclean 按「现状」提供，不附带任何明示或暗示的担保。显示器休眠不会锁定你的 Mac；离开电脑前请自行锁屏。
