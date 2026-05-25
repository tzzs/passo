# Passo 待办事项

> 最后更新：2026-05-26 · 代码层 M1–M8 与 18 项审计修复全部落地。剩余事项以**部署 / 配置**为主，外加最近 WalletView 重做引入的少量 Bug。

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

## 代码 Bug（P0–P1，本轮 WalletView 重做引入）

| # | 位置 | 描述 | 影响 |
|---|---|---|---|
| W1 | `WalletView.swift:516` `countdownString` | 缺"天"单位 → 一周后的票显示 "168h 0m" | P0 倒计时显示崩坏 |
| W2 | `WalletView.swift:280-296` 命名错位 | `upcomingTimeline` / `// MARK: Timeline (即将 tab)` 实际用在 `.all` 分支 | P2 仅误导维护者 |
| W3 | `WalletView.swift:90` 底部栏覆盖 | "即将" tab 既不显示空态 CTA 也不显示 timeline bar，缺统一扫码入口 | P1 待与设计确认 |
| W4 | `WalletView.swift` `entryTile` | "加到 Wallet" 磁贴 action 复用 `onScanTapped`，与图标承诺不符 | P1 用户困惑 |

历史 Bug（B1–B3、U1–U6）已全部修复，归档于 git log。

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

## 工作区状态（截至更新时）

未提交改动：

```
M Passo/PassoApp.swift                          (+16  DEBUG 预览 seed)
M Passo/Views/Detail/PassDetailView.swift       (±55)
M Passo/Views/Scan/RecognitionConfirmView.swift (±2)
M Passo/Views/Scan/ScanView.swift               (+41)
M Passo/Views/Wallet/WalletView.swift           (+405 时间轴重做)
?? PassoShareExtension/Info.plist               (新文件)
```

建议优先：(a) 修 W1 倒计时，(b) 决定 W3/W4 取舍，(c) 一次提交落盘。
