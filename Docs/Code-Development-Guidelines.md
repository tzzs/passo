# Passo 代码开发设计规范

本文档描述 Passo 当前代码的架构边界、开发约定和扩展规则。目标是让后续开发保持小范围、可验证、符合现有 SwiftUI / SwiftData / PassKit 结构。

## 项目边界

Passo 是单 Xcode 工程、单主 App target 加 Share Extension 的 iOS 项目。

当前约定：

- 开发入口是 `Passo.xcodeproj`。
- 运行目标是 iOS 17+。
- 主代码位于 `Passo/`。
- 分享扩展位于 `PassoShareExtension/`。
- 没有 SwiftPM 包、没有外部包管理器、没有 CLI build/test 约定。
- 主 App portrait-only、单 scene。

## 目录职责

```text
Passo/
  Components/        # 通用 SwiftUI 组件，不持有业务流程
  Models/            # SwiftData 模型、业务枚举和模型便利逻辑
  Services/          # 系统能力、导入、识别、签名、StoreKit、Wallet、提醒
  Theme/             # 主题、颜色、间距、动画 token
  Views/             # 页面级 SwiftUI View，按业务域分组
  ContentView.swift  # 根 tab 和分享导入入口
  PassoApp.swift     # App 生命周期、ModelContainer、全局服务注入

PassoShareExtension/
  ShareViewController.swift # 系统分享入口和 App Group handoff
```

职责规则：

- `Components/` 只放可复用 UI 组件，不直接发起持久化、网络或 StoreKit 购买。
- `Views/` 可以编排 UI 状态和调用服务，但不应实现复杂系统 API 细节。
- `Services/` 封装系统框架和异步流程，对 View 暴露小而明确的 API。
- `Models/` 保存持久化模型和与模型紧密相关的计算逻辑。
- `Theme/` 是视觉 token 的唯一来源。

## App 生命周期

`PassoApp.swift` 负责：

- 创建共享 `ModelContainer`。
- 注入 `StoreService.shared`。
- 刷新 StoreKit entitlement。
- 处理 `passo://import` URL。
- DEBUG 下 seed preview data。

当前 SwiftData 配置显式使用：

```swift
ModelConfiguration(
    groupContainer: .none,
    cloudKitDatabase: .none
)
```

不要在 View body 中重复创建 `ModelContainer`。SwiftData SQLite store 必须保持稳定的共享 container。

## 根导航约定

`ContentView` 使用 `AppTab` 管理：

- `.wallet`
- `.scan`
- `.settings`

扫描 tab 是 trigger-only：

- tab item 可以显示“扫描”。
- tab content 使用 `Color.clear`。
- 选中 `.scan` 后立即设置 `showScanSheet = true` 并把 `selectedTab` 设回 `.wallet`。
- 不要给扫描 tab 增加独立 destination view。

分享扩展导入流程：

1. Share Extension 写入 App Group payload。
2. Share Extension 打开 `passo://import`。
3. `PassoApp` 收到 URL 后发出 `.passoShareImport` 通知。
4. `ContentView` 调用 `ShareImportService.consumePendingPayload()`。
5. `TicketParser.parse(...)` 生成 `Ticket`。
6. 通过 `RecognitionConfirmView` 让用户确认。

## 数据模型规范

核心模型是 `Ticket`，定义在 `Passo/Models/Ticket.swift`。

`Ticket` 是唯一 SwiftData `@Model`：

- `id` 使用 `UUID`。
- `ticketTypeRaw` 持久化 `TicketType.rawValue`。
- `ticketType` 是 computed property，负责 raw value 与 enum 互转。
- `tagsJSON` 持久化 JSON 字符串，`tags` computed property 提供 `[String]` 接口。

模型设计规则：

- 新字段必须评估 SwiftData 迁移影响。
- 与票据类型强相关但所有票据共用的字段，可以继续放在 `Ticket` 上。
- 只属于某个复杂子域的大量字段，应先评估是否需要拆模型；当前项目仍保持单模型。
- 不要直接持久化 enum，继续使用 raw string 模式。
- 默认过期规则统一通过 `Ticket.defaultExpiry(for:eventDate:)` 管理。

新增票据类型必须同步更新：

- `TicketType` case
- `displayName`
- `emoji`
- `TicketTheme`
- `Ticket.preview(_:)`
- `TicketParser.classifyType`
- `TicketParser.extractFields`
- `TicketCardView.cardInfoGrid`
- `PassBuilder.passStyle`
- `PassBuilder.buildAuxiliary`

## 状态管理

使用规则：

- 页面临时 UI 状态使用 `@State`。
- 可观察服务使用 `@StateObject` 或 `@EnvironmentObject`。
- SwiftData 查询使用 `@Query`。
- 详情和确认页直接编辑 SwiftData 模型时使用 `@Bindable var ticket: Ticket`。
- Pro 和节点偏好使用 `@AppStorage`。

当前持久化偏好：

| Key | 用途 |
|---|---|
| `isPro` | Pro entitlement 单一门控来源 |
| `signingNodePreference` | Pass 签名节点偏好 |
| `iCloudSyncEnabled` | iCloud 同步开关显示与偏好 |

规则：

- 不要复制 `isPro` 到多个自定义状态源；StoreKit 刷新后应同步到 `UserDefaults`。
- `@AppStorage` key 必须集中复用现有字符串。
- 异步结果回写 UI 时必须回到 MainActor。

## 服务边界

### `CameraService`

职责：

- 管理 `AVCaptureSession`。
- 提供 `AVCaptureVideoPreviewLayer`。
- 实时检测条码。
- 节流 OCR 文本识别。
- 管理 torch。

规则：

- 相机 session 配置和运行放在专用 queue。
- 发布给 SwiftUI 的状态必须在 MainActor 更新。
- 相同条码通过 `lastDetectedValue` 去重；重新扫描必须调用 `resetDetection()`。
- 新增识别格式时同步更新 AVFoundation metadata types 和格式字符串映射。

### `TicketParser`

职责：

- 根据条码和 OCR 文本分类票据。
- 提取标题、地点、时间、座位、路线、会员、景点字段。
- 提供静态 OCR helper。

规则：

- 解析必须本地、确定性、不可抛错。
- 最坏情况返回 `.generic`。
- 解析失败不要阻断确认页，用户必须能手动修正。
- 正则提取应保持可读，复杂规则拆为 helper。
- `barcodeFormat` 的真实格式由调用方在检测后覆盖。

### `ShareImportService`

职责：

- 从 App Group 读取 pending payload。
- 读取缩略图。
- 消费后删除 payload 文件。

规则：

- Share Extension 和主 App 的 App Group ID 必须一致：`group.com.passo.app`。
- payload 被读取后必须清理，避免冷启动重复导入。
- 空条码且 OCR 文本不足时返回 nil。

### `PassBuilder`

职责：

- 将 `TicketSnapshot` 转成 PassKit `pass.json`。
- 根据票据类型选择 PassKit style。
- 映射 barcode format。

规则：

- View 不直接组装 PassKit JSON。
- PassKit 所需字段从 `TicketSnapshot` 获取，避免跨 actor 直接读 SwiftData model。
- 新票据类型必须明确映射到 `eventTicket`、`boardingPass` 或 `storeCard`。
- `manifest.json`、`signature` 和图片资产由远端签名节点负责补齐。

### `SigningService`

职责：

- 构建 pass JSON。
- 按节点偏好请求远端签名服务。
- 超时后自动尝试备用节点。

规则：

- 保持为 `actor`，避免并发状态污染。
- 网络错误当前统一按 timeout 处理以触发 fallback。
- UI 层展示 `SigningError.localizedDescription`。
- 不要把 Pass 证书或私钥放进客户端。

### `WalletPresenter`

职责：

- 包装 `PKAddPassesViewController`。
- 判断用户是否真的添加 pass。
- 提供打开系统 Wallet 的 helper。

规则：

- Simulator 可能没有 Wallet，必须优雅降级。
- 添加完成后用 `PKPassLibrary.containsPass` 判断，不要只看 dismiss。

### `StoreService`

职责：

- 加载 StoreKit 2 产品。
- 发起购买和恢复。
- 监听 transaction updates。
- 刷新 current entitlements。

规则：

- `StoreService` 是 `@MainActor` singleton。
- 购买结果必须区分 success、cancelled、pending 和 error。
- entitlement 刷新后同步 `isPro` 到 `UserDefaults`。

## UI 开发规则

- 使用 `AppSpacing`、`AppAnimation` 和 `TicketType.theme`。
- 页面级 View 可以较长，但新增复杂块时优先拆 private subview / helper。
- 图标按钮优先使用 SF Symbols。
- 44pt 命中区域是底线。
- 删除、清理等 destructive 操作必须使用 confirmation dialog。
- 异步操作必须暴露 loading、success 或 error 状态。
- 不要在业务 View 中散落网络请求细节。

## 并发规则

- 与 SwiftUI 绑定的 ObservableObject 优先标注 `@MainActor`。
- 相机、OCR、条码生成等重工作应放到 background queue 或 detached task。
- 跨 actor 使用 SwiftData model 前，先创建 `TicketSnapshot`。
- 不要把 `Ticket` 直接传入远端签名 actor 作为长期依赖。
- UI 更新必须回 MainActor。

## 错误处理规则

当前产品允许“识别不完美，但流程不中断”：

- OCR / 解析失败：生成可编辑的 `.generic` 票据。
- 相机权限失败：显示权限说明和打开设置。
- 签名失败：展示明确 alert。
- Wallet 不可用：返回空容器或禁用入口。
- 地图 geocode 失败：显示无位置或 loading fallback，不阻塞详情页。
- StoreKit pending：显示“购买待确认”。

不要用 `fatalError` 处理用户可恢复错误。当前 `fatalError` 仅用于 app 启动时 `ModelContainer` 无法创建。

## PassKit 开发规则

客户端只负责：

- 生成 `pass.json`
- 选择 barcode 格式
- 附带时间、地点、字段和背面信息
- 请求远端签名服务
- 展示系统添加界面

服务端负责：

- 生成 bundle
- 写入 `manifest.json`
- 使用证书签名
- 返回 `.pkpass`
- 管理证书、私钥和资源文件

任何证书、私钥、`.p12`、签名密码都不得进入 iOS app 仓库或客户端 bundle。

## Share Extension 开发规则

Share Extension 应保持轻量：

- 接收 image 或 URL。
- 对 image 做 Vision 条码和 OCR。
- 写入 App Group payload。
- 打开主 App。
- 不在 extension 中做 SwiftData 持久化。
- 不在 extension 中展示复杂编辑 UI。

主 App 是最终确认和持久化入口。

## 命名与组织

Swift 文件组织：

- 顶部 imports。
- `// MARK:` 分区。
- public-facing 主类型在前。
- private subviews、helpers 和 actions 按页面结构排列。

命名规则：

- View 文件使用 `XxxView.swift`。
- Service 文件使用 `XxxService.swift`，系统 wrapper 可用领域名，如 `WalletPresenter`。
- enum case 使用 lowerCamelCase。
- 布尔值使用 `is`、`has`、`show`、`should` 前缀。
- 异步动作函数使用动词，如 `load`、`sign`、`restore`、`scheduleReminder`。

## 新功能开发流程

新增功能时按以下顺序设计：

1. 明确入口页面和用户流程。
2. 判断是否需要改 `Ticket` 模型。
3. 如果需要持久化，先评估迁移和默认值。
4. 把系统能力封装进 `Services/`。
5. 用现有组件搭 UI。
6. 给异步和失败状态留出 UI。
7. 在 README 或 Docs 中更新开发约定。

## 新票据类型开发清单

新增 `TicketType` 前后检查：

- `TicketType` 新 case。
- `displayName` 和 `emoji`。
- `TicketTheme` 颜色。
- `Ticket.preview(_:)` 示例数据。
- `TicketParser` 分类关键词。
- `TicketParser` 字段提取。
- `TicketCardView` full / compact 呈现。
- `PassBuilder` style 和 auxiliary fields。
- README / UI 规范同步更新。

## 验证建议

当前仓库没有维护 CLI 构建或测试命令。代码改动应通过 Xcode 验证：

- Xcode 16+ 打开 `Passo.xcodeproj`。
- 选择 iOS 17+ simulator 或签名真机。
- 主 App 能启动并显示 seed 数据。
- 扫描页能处理相机权限状态。
- 相册 / 截图 / 分享导入能进入确认页。
- 详情页卡片翻转、提醒、地图 fallback 不崩溃。
- Wallet 添加必须在真机上验证。

文档-only 改动至少检查：

- Markdown 链接有效。
- 文件路径和类型名与当前代码一致。
- 不记录尚未实现的能力为已完成能力。

## 提交规范

提交信息遵循 Conventional Commits 1.0.0：

```text
<type>[optional scope]: <description>
```

推荐 scope：

- `docs`
- `wallet`
- `scan`
- `detail`
- `settings`
- `model`
- `theme`
- `passkit`

示例：

```text
docs: add UI and development guidelines
feat(scan): support Aztec barcode detection
fix(passkit): map EAN8 barcode format
refactor(wallet): split timeline row view
```
