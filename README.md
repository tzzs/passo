# Passo

Passo 是一个面向 iPhone 的票据钱包 App，用 SwiftUI、SwiftData、Vision、PassKit 和 StoreKit 2 构建。它把电影票、演出票、火车票、景区票、会员卡和通用票据统一收进本地票夹，并支持从相机、相册、截图和系统分享扩展导入票据。

## 功能概览

- 票夹首页：Apple Wallet 风格的票据卡片堆叠，支持“即将 / 全部”筛选、今日票据 badge、滑动标记已使用和删除。
- 多类型票据：`movie`、`concert`、`train`、`member`、`scenic`、`generic` 六种类型，每种类型有独立主题色和字段布局。
- 本地识别：使用 Vision 做条码检测和 OCR，`TicketParser` 负责类型判断与字段提取。
- 多渠道导入：相机扫描、相册导入、截图快速导入、Share Extension 分享导入。
- Wallet 集成：客户端生成 PassKit `pass.json`，再发送到远端签名节点获取 `.pkpass` 并调用系统 Wallet 添加界面。
- 提醒与清理：支持票据提醒、过期或已使用票据清理。
- Pro 能力：StoreKit 2 订阅状态写入 `@AppStorage("isPro")`，用于 iCloud 同步等能力门控。

## 项目结构

```text
Passo/
  Components/        # GlassCardView、TicketCardView 等复用组件
  Models/            # SwiftData Ticket 模型与 TicketType
  Services/          # 相机、识别、导入、签名、Wallet、StoreKit、提醒
  Theme/             # AppTheme、AppSpacing、AppAnimation、Color(hex:)
  Views/
    Detail/          # 票据详情与 Wallet 操作
    Scan/            # 扫描、相册导入、识别确认
    Settings/        # 设置、Pro、截图导入
    Wallet/          # 票夹首页
  ContentView.swift  # Tab 容器；扫描 tab 只作为触发器
  PassoApp.swift     # App 入口与 SwiftData ModelContainer

PassoShareExtension/
  ShareViewController.swift
```

## 架构说明

- App 入口是 `PassoApp.swift`，负责创建共享的 SwiftData `ModelContainer`，注入 `StoreService`，并处理 `passo://import` 分享扩展回调。
- 根视图是 `ContentView.swift`，包含票夹、扫描、设置三个 tab。扫描 tab 不绑定实际页面，点击后会立即切回票夹并以 `.fullScreenCover` 打开 `ScanView`。
- 数据模型集中在 `Ticket`。`TicketType` 通过 `ticketTypeRaw: String` 持久化，并通过 computed property 还原为枚举。
- 视觉主题由 `TicketType.theme` 驱动，卡片组件通过 `ticket.ticketType.theme` 获取渐变、强调色和辅助强调色。
- PassKit 生成流程是 `Ticket` -> `TicketSnapshot` -> `PassBuilder.buildPassJSON(...)` -> `SigningService.sign(...)` -> `WalletPresenter`。

## 运行环境

- macOS + Xcode 16 或更新版本
- iOS 17 或更新版本的模拟器 / 真机
- SwiftUI + SwiftData 项目，无外部包管理器依赖
- 真机运行 Wallet、相机、推送、iCloud、StoreKit 等能力时需要有效 Apple Developer 签名

## 本地运行

1. 用 Xcode 打开 `Passo.xcodeproj`。
2. 选择 `Passo` scheme。
3. 选择 iOS 17+ 模拟器或已签名真机。
4. 使用 `⌘R` 运行。

当前仓库约定为 Xcode-only：没有 CLI build/test 命令、没有包依赖、没有 CI、没有自动化测试目标。

## 必要配置

上线或真机完整验证前，需要确认以下配置：

- App Group：`group.com.passo.app`，用于 Share Extension 与主 App 交接导入 payload。
- URL Scheme：`passo://import`，用于 Share Extension 唤起主 App。
- Pass Type Identifier：`pass.com.passo.ticket`。
- Pass 签名节点：
  - 国内：`https://sign.passo.cn/api/sign`
  - 海外：`https://passo-sign.workers.dev/api/sign`
- StoreKit 产品：
  - `com.passo.pro.monthly`
  - `com.passo.pro.yearly`
- Capabilities：
  - Push Notifications
  - In-App Purchase
  - iCloud + CloudKit
  - App Groups
  - Background Modes / Location updates

## 设计与代码约定

- 间距、圆角和动画优先使用 `AppSpacing` 与 `AppAnimation`，避免直接散落 raw `CGFloat`。
- 颜色优先使用 `Color(hex: "#RRGGBB")`，类型主题从 `TicketType.theme` 派生。
- 通用玻璃卡片使用 `GlassCardView`。
- 票据卡片使用 `TicketCardView`，并按 `.full` 或 `.compact` 选择布局。
- 新增票据类型时，需要同步更新 `TicketType`、主题、解析规则、卡片布局和 PassKit 字段映射。

## 已知待补充

- 远端 Pass 签名服务需要部署并接入真实证书。
- CloudKit container 与 App Store Connect 订阅产品需要在开发者后台创建。
- Wallet 打开 / 跳转体验仍需结合真机验证。
- UI 自动化测试与 CLI CI 尚未建立。

## 提交规范

提交信息遵循 Conventional Commits 1.0.0：

```text
<type>[optional scope]: <description>
```

常用类型：`feat`、`fix`、`refactor`、`style`、`perf`、`docs`、`test`、`chore`。

常用 scope：`model`、`wallet`、`scan`、`detail`、`settings`、`theme`、`passkit`。

示例：

```text
docs: expand project README
feat(scan): add torch toggle
fix(passkit): preserve barcode format when signing pass
feat(passkit)!: replace stub signing
```
