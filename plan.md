# Passo 待办事项

> 最后更新：2026-05-24 · 所有 M1–M8 代码已实现，以下为剩余 Bug、UX 改进与部署任务。

---

## 完成度总览

| 里程碑 | 状态 |
|---|---|
| M1 扫描引擎（AVFoundation + Vision + OCR） | ✅ |
| M2 真实条码渲染（Core Image） | ✅ |
| M3 PassKit 签名流水线 | ✅（客户端完成，签名节点待部署） |
| M4 智能提醒（UNUserNotificationCenter） | ✅ |
| M5 地图缩略图（MKMapSnapshotter） | ✅ |
| M6 滑动归档 + 相册 / 截图 / 共享扩展导入 | ✅ |
| M7 Pro 订阅（StoreKit 2） | ✅（客户端完成，App Store Connect 产品待创建） |
| M8 iCloud 同步（CloudKit） | ✅（客户端完成，CloudKit Dashboard 待配置） |

---

## 代码 Bug（P0 优先修复）

| # | 位置 | 描述 | 影响 |
|---|---|---|---|
| B1 | `TicketParser.swift:188-191` | `MM-dd` 格式日期始终使用当年年份。12 月购买明年 1 月的票，解析出的 eventDate 会是当年 1 月（已过期）。修复：若解析日期 < 今天 - 30 天，则年份加 1。 | 中 |
| B2 | `WalletView.swift:230` | 第二张卡片（compact 预览）没有 `onTapGesture`，点击无法进入详情。 | 低 |
| B3 | `RecognitionConfirmView.swift:488` / `PhotoImportView.swift:198` | 免费限额用 `allTickets.count >= 5`（历史总量），但 UI 文案说"每月 5 张"。两者不一致，需统一（要么改为月度计数，要么改文案为"最多 5 张"）。 | 低 |

---

## UX / 功能改进（P1）

| # | 位置 | 描述 |
|---|---|---|
| U1 | `WalletView.swift` | Tab bar 无今日票数角标；可用 `.badge(todayCount)` 在有票时显示数字。 |
| U2 | `ScanView.swift` | 确认保存后 ScanView 继续停留，需手动关闭；可在 `RecognitionConfirmView` 成功回调里加 `onSaved: () -> Void` 透传 `dismiss`。 |
| U3 | `ProUpgradeSheet.swift:168` | "省 53%" 硬编码；改为从 `product.price` 动态计算 `(1 - yearly / (monthly × 12)) × 100`。 |
| U4 | `PassDetailView.swift:16` | `let ticket: Ticket` 改为 `@Bindable var ticket: Ticket`，使 SwiftUI 能追踪字段级变更并按需重绘（当前依赖引用类型副作用，符合正确性但不符合 SwiftUI 惯例）。 |
| U5 | `project.yml` / `Info.plist` | 缺少 `NSLocationAlwaysAndWhenInUseUsageDescription`；位置提醒在后台触发时需要此 key，否则 iOS 会忽略 `UNLocationNotificationTrigger`。 |
| U6 | 无 | 缺少 `.storekit` 沙盒配置文件，Pro 升级流程无法在模拟器中测试。需在 Xcode → File → New → StoreKit Configuration 创建并挂载。 |

---

## 部署配置（上线前必做）

### Pass 签名节点

`SigningService` 指向的端点尚未部署：

| 节点 | URL | 说明 |
|---|---|---|
| 国内 | `https://sign.passo.cn/api/sign` | 任意后端；接收 JSON body，用 `.p12` 证书做 PKCS#7 签名后返回 `.pkpass` |
| 海外 | `https://passo-sign.workers.dev/api/sign` | Cloudflare Worker；证书以 KV Secret 存储 |

接口规范：
- `POST /api/sign`，`Content-Type: application/json`，Body 为 pass.json
- 返回 `Content-Type: application/vnd.apple.pkpass`，Body 为 zip 格式 `.pkpass` bundle
- bundle 必须包含：`pass.json`、`manifest.json`、`signature`、`icon.png`、`logo.png`

参考：[PassKit Package Format Reference](https://developer.apple.com/documentation/walletpasses/building_a_pass)

---

### CloudKit Dashboard

1. 登录 [CloudKit Console](https://icloud.developer.apple.com)
2. 创建 container `iCloud.com.passo.app`
3. 在 Xcode → Signing & Capabilities → iCloud 勾选该 container
4. 执行 `xcodegen generate` 使 entitlement 写入 `.xcodeproj`

---

### App Store Connect — StoreKit 产品

| Product ID | 类型 | 建议定价 |
|---|---|---|
| `com.passo.pro.monthly` | 自动续期订阅 | ¥12 / 月 |
| `com.passo.pro.yearly` | 自动续期订阅 | ¥68 / 年 |

创建后在 Xcode Scheme → StoreKit Configuration 挂载本地 `.storekit` 文件，用沙盒账号验证完整购买流程。

---

### Xcode 签名 & Capabilities

真机运行 / 上线前，在 Xcode → Signing & Capabilities 确认以下 capability 已启用：

- [x] Push Notifications（提醒）
- [x] In-App Purchase（Pro 订阅）
- [x] iCloud + CloudKit（同步）
- [x] App Groups：`group.com.passo.app`（Share Extension 共享容器）
- [x] Background Modes → Location updates（位置提醒后台触发）
