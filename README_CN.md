# Passo

[English](README.md) | 简体中文

Passo 是一个面向 iPhone 的票据钱包 App，用 SwiftUI、SwiftData、Vision、PassKit 和 StoreKit 2 构建。它把活动票据和长期会员卡统一收进本地票夹，并支持从相机、相册、截图、手动新建和系统分享扩展导入。

## 功能概览

- 票据 tab：Apple Wallet 风格的活动票据卡片堆叠，支持“即将 / 全部”筛选、搜索、类型筛选、今日票据 badge、滑动标记已使用和删除。
- 卡包 tab：面向会员卡的独立卡包，使用堆叠卡片展示，提供卡片语境导入、到期提醒和统一归档入口。
- 已归档：统一收纳过期、已使用、手动归档的票据和卡片，并可从票据和卡包两个 tab 进入。
- 多类型票据：`movie`、`concert`、`train`、`member`、`scenic`、`generic` 六种类型，每种类型有独立主题色和字段布局。
- 本地识别：使用 Vision 做条码检测和 OCR，`TicketParser` 负责类型判断与字段提取。
- 多渠道导入：相机扫描、相册导入、截图快速导入、手动新建、Share Extension 分享导入。
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
    Wallet/          # 票据、卡包、归档视图
  ContentView.swift  # Tab 容器与导入弹层协调
  PassoApp.swift     # App 入口与 SwiftData ModelContainer

PassoShareExtension/
  ShareViewController.swift

PassoTests/          # 覆盖模型、解析、配额、卡片配色和 PassKit JSON 行为的单元测试
PassoUITests/        # 基于 accessibility identifier 的 UI 冒烟测试
Docs/                # UI 与开发规范
```

## 架构说明

- App 入口是 `PassoApp.swift`，负责创建共享的 SwiftData `ModelContainer`，注入 `StoreService`，并处理 `passo://import` 分享扩展回调。
- 根视图是 `ContentView.swift`，包含票据、卡包、设置三个 tab。`+` 菜单负责展示相册导入、相机扫描或空白 `RecognitionConfirmView` 手动新建流程。
- `WalletView.swift` 只展示活动票据（`!isCard && !isInArchive`），并负责“即将 / 全部”的分段体验。
- `CardWalletView.swift` 只展示长期会员卡（`ticketType == .member`），形成独立卡包。
- `ArchiveView.swift` 被票据和卡包共用，统一展示过期、已使用和手动归档项目。
- 数据模型集中在 `Ticket`。`TicketType` 通过 `ticketTypeRaw: String` 持久化，并通过 computed property 还原为枚举。
- `Ticket.isCard`、`Ticket.isInArchive`、`Ticket.canRestore`、`Ticket.isExpiringSoon` 驱动票夹分桶、归档和恢复行为。
- 视觉主题由 `TicketType.theme` 驱动，卡片组件通过 `ticket.ticketType.theme` 获取渐变、强调色和辅助强调色。
- PassKit 生成流程是 `Ticket` -> `TicketSnapshot` -> `PassBuilder.buildPassJSON(...)` -> `SigningService.sign(...)` -> `WalletPresenter`。

## 运行环境

- macOS + Xcode 16 或更新版本
- iOS 17 或更新版本的模拟器 / 真机
- SwiftUI + SwiftData 项目，无外部包管理器依赖
- 如需从 `project.yml` 重新生成 `Passo.xcodeproj`，需要安装 XcodeGen
- 真机运行 Wallet、相机、推送、iCloud、StoreKit 等能力时需要有效 Apple Developer 签名

## 本地运行

1. 用 Xcode 打开 `Passo.xcodeproj`。
2. 选择 `Passo` scheme。
3. 选择 iOS 17+ 模拟器或已签名真机。
4. 使用 `⌘R` 运行。

日常开发以仓库内的 `Passo.xcodeproj` 为准。项目也由 `project.yml` 描述；当修改 target membership 或工程元数据时，请同步更新 `project.yml`，运行 `xcodegen generate`，并在提交前审查生成后的 `Passo.xcodeproj`。

命令行验证可尽量贴近 CI：

```sh
plutil -lint Passo/Info.plist PassoShareExtension/Info.plist Passo/Passo.entitlements PassoShareExtension/PassoShareExtension.entitlements
xcodebuild -list -project Passo.xcodeproj
xcodebuild -quiet build -project Passo.xcodeproj -scheme Passo -configuration Debug -destination "generic/platform=iOS Simulator" CODE_SIGNING_ALLOWED=NO
xcodebuild -quiet build -project Passo.xcodeproj -scheme PassoShareExtension -configuration Debug -destination "generic/platform=iOS Simulator" CODE_SIGNING_ALLOWED=NO
```

`PassoTests` 和 `PassoUITests` 已接入 `Passo` scheme，可在 Xcode 本地运行。当前 CI 会校验工程元数据，并在不签名的情况下构建主 App 与 Share Extension。

## 必要配置

上线或真机完整验证前，需要确认以下配置：

- Development Team：真机构建前需要为主 App 和扩展 target 配置 `DEVELOPMENT_TEAM`。
- App Group：`group.com.passo.app`，用于 Share Extension 与主 App 交接导入 payload。
- URL Scheme：`passo://import`，用于 Share Extension 唤起主 App。
- Pass Type Identifier：`pass.com.passo.ticket`。
- Pass 签名节点：
  - 国内：`https://sign.passo.cn/api/sign`
  - 海外：`https://passo-sign.workers.dev/api/sign`
- StoreKit 产品：
  - `com.passo.pro.monthly`
  - `com.passo.pro.yearly`
- iCloud 同步：entitlements 和用户开关已存在，但 `ModelConfiguration` 当前仍使用 `cloudKitDatabase: .none`；设置页开关还不是实时 CloudKit 开关。
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
- 复用视觉组件放在 `Passo/Components/`，系统集成和异步流程放在 `Passo/Services/`，页面级组合放在 `Passo/Views/`。
- 票据数据跨 actor / 并发边界前先创建 `TicketSnapshot`。
- 会影响 UI 的异步结果需要回到 `MainActor`。

## 已知待补充

- 远端 Pass 签名服务需要部署并接入真实证书。
- CloudKit container 与 App Store Connect 订阅产品需要在开发者后台创建。
- Wallet 打开 / 跳转体验仍需结合真机验证。
- Share Extension 嵌入、iCloud 同步行为、Pass 签名链路仍需在真机端到端验证。
- App Store Connect 产品创建后，需要替换 `ProUpgradeSheet` 的占位内容。

## PR 检查清单

- 摘要说明用户可见行为变化和配置影响。
- 写清楚实际执行过的验证；未运行的检查需要说明原因。
- UI 可见改动附截图或录屏。
- tab 架构、导入流程、Capabilities、签名行为变化时同步更新文档。

## 提交规范

提交信息遵循 Conventional Commits 1.0.0：

```text
<type>[optional scope]: <description>
```

常用类型：`feat`、`fix`、`refactor`、`style`、`perf`、`docs`、`test`、`chore`。

常用 scope：`model`、`wallet`、`scan`、`detail`、`settings`、`theme`、`passkit`、`docs`。

示例：

```text
docs: expand project README
feat(scan): add torch toggle
fix(passkit): preserve barcode format when signing pass
feat(passkit)!: replace stub signing
```
