# Passo 待办事项

> 最后更新：2026-05-26 · 代码层 M1–M8、18 项审计修复、W1–W4、push 转场抖动、HIG 44pt 触控目标、3D 翻转灰背景 bug 全部落地。**剩余事项以部署 / 配置为主。**

---

## 完成度总览（按模块）

| 模块 | 状态 | 备注 |
|---|---|---|
| 数据模型 (`Ticket.swift`) | ✅ 100% | 稳定，含 6 种 `TicketType` + per-type 默认过期规则 |
| 设计系统 + 组件库 | ✅ 100% | `AppSpacing` / `AppAnimation` / `GlassCardView` / `TicketCardView` (580 行，per-type 布局) |
| WalletView | ✅ 95% | 时间轴 + 滑动归档全实现；待修 4 个小 Bug（见下） |
| PassDetailView | ✅ 95% | `MKMapSnapshotter` 地图、Wallet 跳转、`@Bindable` 编辑全到位 |
| RecognitionConfirmView | ✅ 95% | `PassBuilder` + `SigningService` 已接通；只欠服务端节点上线 |
| ScanView | ✅ 95% | `AVCaptureVideoPreviewLayer` + 闪光灯 + Vision 条码全实装 |
| 条码渲染 | ✅ 100% | `CIFilter.qrCodeGenerator / code128BarcodeGenerator` 真实生成 |
| SettingsView | ✅ 90% | StoreKit 2 接通、签名节点切换、`.storekit` 沙盒；少量功能开关待定 |
| 智能提醒 (M4) | ✅ 100% | `UNUserNotificationCenter` + 位置触发后台模式 |
| 地图缩略图 (M5) | ✅ 100% | `MKMapSnapshotter` 缓存到 SwiftData |
| 滑动归档 + 多渠道导入 (M6) | ✅ 100% | 左删右标用；相册 / 截图 / Share Extension 三入口 |
| Pro 订阅 (M7) | ✅ 90% | `StoreService` (StoreKit 2) 客户端完成；App Store Connect 产品待创建 |
| iCloud 同步 (M8) | ✅ 90% | `Ticket` 的 CloudKit schema 已配；CloudKit Dashboard 待创建 container |

---

## 已修复 Bug 摘要（近期）

WalletView 时间轴重做引入：
- ✅ ~~W1 `countdownString` 缺"天"单位~~ → 加 `d / 86_400` 分支
- ✅ ~~W2 `upcomingTimeline` 命名错位~~ → 重命名 `allTimeline` + 抽 `isTimelineMode`
- ✅ ~~W3 "即将" tab 无操作栏~~ → 改 `actionBottomBar` 两 tab 通用
- ✅ ~~W4 "加到 Wallet" 磁贴错配~~ → 删第三磁贴，保留两个真实入口

转场 / 触控 / 视觉缺陷：
- ✅ Push 转场抖动 → `PassDetailView` 横向 padding 20→`AppSpacing.md`(16) + `.navigationBarHidden`→`.toolbar(.hidden, for: .navigationBar)`
- ✅ 3D 翻转卡片变灰 → `GlassCardView` 新增 `useStaticBackground` 参数跳过 `.ultraThinMaterial`
- ✅ HIG 44pt 触控目标 → ScanView 关闭/闪光灯、PassDetailView ellipsis 改用"36pt 视觉气泡 + 44pt hit area" 模式
- ✅ `GlassPillButton` 40→44pt（上一轮）
- ✅ 历史 B1–B3、U1–U6（更早归档于 git log）

---

## 部署配置（上线前必做）

### 1. Pass 签名节点

`SigningService` 指向以下端点，**尚未部署**：

| 节点 | URL | 实现要求 |
|---|---|---|
| 国内 | `https://sign.passo.cn/api/sign` | 任意后端；接收 JSON body，用 `.p12` 证书做 PKCS#7 签名，返回 `.pkpass` |
| 海外 | `https://passo-sign.workers.dev/api/sign` | Cloudflare Worker；证书以 KV Secret 存储 |

**接口规范**：
- `POST /api/sign`，`Content-Type: application/json`，Body 为 `pass.json`
- 返回 `Content-Type: application/vnd.apple.pkpass`，Body 为 zip 格式 `.pkpass` bundle
- bundle 必须包含：`pass.json`、`manifest.json`、`signature`、`icon.png`、`logo.png`

参考：[PassKit Package Format Reference](https://developer.apple.com/documentation/walletpasses/building_a_pass)

### 2. CloudKit Dashboard

1. 登录 [CloudKit Console](https://icloud.developer.apple.com)
2. 创建 container `iCloud.com.passo.app`
3. Xcode → Signing & Capabilities → iCloud 勾选该 container
4. 执行 `xcodegen generate` 让 entitlement 写入 `.xcodeproj`

### 3. App Store Connect — StoreKit 产品

| Product ID | 类型 | 建议定价 |
|---|---|---|
| `com.passo.pro.monthly` | 自动续期订阅 | ¥12 / 月 |
| `com.passo.pro.yearly` | 自动续期订阅 | ¥68 / 年 |

创建后在 Xcode Scheme → StoreKit Configuration 挂载本地 `Passo.storekit`，用沙盒账号验证完整购买流程。

### 4. Xcode 签名 & Capabilities

真机 / 上线前确认以下 capability 已勾选：

- [x] Push Notifications（提醒）
- [x] In-App Purchase（Pro 订阅）
- [x] iCloud + CloudKit（同步）
- [x] App Groups：`group.com.passo.app`（Share Extension 共享容器）
- [x] Background Modes → Location updates（位置提醒后台触发）

---

## 后续建议（低优先级，不阻塞上线）

| 建议 | 价值 | 触发时机 |
|---|---|---|
| 在 `AppTheme.swift` 添加 `AppSpacing.lg = 24` token | 让 `ProUpgradeSheet` 6 处、`PhotoImportView` 2 处、`RecognitionConfirmView` 2 处的"sheet 宽 padding"摆脱 magic number，统一引用 token | 下次设计师调整 sheet 间距时 |
| CI / pre-commit 加 `grep -rn "navigationBarHidden\|navigationBarTitle\|navigationBarItems"` 检查 | 自动挡住 iOS 16+ deprecated 的导航 API（这类 API 编译不报错但会引发 1 帧闪烁） | 配置 hooks 时一并加入 |
| 在 CLAUDE.md 注一条"以 `xcodebuild` 为真，忽略 cold-load LSP `Cannot find type` 虚警" | 减少未来会话里被 SourceKit 误报误导 | 下次编辑 CLAUDE.md 时 |
| 用慢动作模拟器（⌘T）做转场 QA 抽查 | 60fps 下 1-2 帧的闪烁人眼难察觉，慢速 ×5 后所有 transient bug 立刻可见 | 上线前最后一轮回归 |

---

## 工程经验沉淀（用于未来会话/审阅）

**Magic number vs design token**：横向 padding 出现非 token 值（如 20pt 偏离 `AppSpacing.md`=16pt）是 push 转场抖动的常见来源。扫"类似问题"时按风险分级：页面布局级 padding > Sheet 内部 padding > 组件内部装饰 padding。装饰间距（6/8/12pt 等）跨视图不会被对比，无需强求统一。

**SwiftUI deprecated API 的隐藏代价**：`.navigationBarHidden(true)` 编译不报错，但在 NavigationStack push 动画期间会出现 1 帧 nav bar 闪现。现代写法 `.toolbar(.hidden, for: .navigationBar)` 没有这个时序 bug。同类还有 `.navigationBarTitle` / `.navigationBarItems`。

**`.contentShape(Circle())` 扩 hit area**：SwiftUI 默认 hit shape 跟随渲染形状，所以一个 36pt 圆按钮的命中区只有 36pt。要在不放大视觉气泡的前提下达到 HIG 44pt，标准做法是 `.frame(36).background(...).clipShape(Circle()).frame(44).contentShape(Circle())`——外层 frame + contentShape 扩展命中区，内层视觉保持紧凑。这比给整个 Button 放大或塞透明 padding view 干净。

**`.ultraThinMaterial` + `rotation3DEffect` 变灰**：Material 效果依赖背后内容，离屏 buffer 没有"背后内容"，所以一旦视图被 rotation3D 推入离屏渲染（如卡片翻转），Material 会 fade to grey。解决方案：用 static fill 替代（见 `GlassCardView.useStaticBackground`）。该参数的注释是项目里少数"解释 WHY 而非 WHAT"的范例，值得保留。

**LSP cold-load 虚警 vs 真实编译错误**：单文件 SourceKit 在跨文件类型未索引完时会报 `Cannot find 'Ticket' in scope`、`No such module 'UIKit'` 等假错。这些是虚警——以 `xcodebuild` 的 `BUILD SUCCEEDED` 为真相源。判断方法：报错行号是否指向**你刚改的代码**；若指向未改的 `@Query`、`import` 等位置，几乎一定是虚警。

**Commit 边界取舍**：理想是"一 commit 一主题"。但同一文件同一波迭代里夹了多个独立 fix 时（如 padding 修复 + 3D flip grey + HIG hit area 都改了 PassDetailView），分 commit 会卡在 hunk-level staging，得不偿失。务实做法：合 commit + 详细 body 分段说明，让 `git log` 单行简洁、单 commit 展开仍可解析。
