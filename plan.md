# Passo 待办事项

> 最后更新：2026-05-31（晚） · 已把 `origin/main` 的 17 个 commit 合入工作分支（含「票据 / 卡包 / 已归档」IA、`ArchiveView`、`CardWalletView`、richer timeline、in-place 导入菜单）。iPhone 17 Pro / iOS 26.5 模拟器构建通过（0 warning / 0 error），主导航、票据 timeline、卡包、归档入口、设置全部可达。**当前剩余事项包含上线配置、PassKit / iCloud 阻塞项，以及卡包 / 归档新流程的边界修复。CLAUDE.md "Key Stubs" 表已严重过期（5 项 stub 全部已实现），需随 P3-2 / P2-8 一并更新。**

---

## 开发执行计划（待用户确认）

执行顺序（用户确认）：**先做本地可闭环 → 体验补强 → 工程质量，上线配置 / 服务端依赖批次移到最后**（需 Apple Developer 后台 + 服务器，单独安排）。

### 批次 1 · 客户端可独立闭环（不依赖外部资源，~1 天）
1. **P0-3** `PassBuilder` 字段完整性：`barcode` legacy 字段单 dict、`boardingPass` 加 `transitType`、补 foreground/background/label/text colors
2. **P0-6 + P0-7** 归档语义整治：`archivedAt` 在右滑标记使用 / 手动归档时写入；过期项的"恢复"改为"编辑有效期"或禁用；`ArchiveView` 排序兜底
3. **P0-8** SwiftData 轻量迁移验证：用旧 store 在模拟器上做一次升级跑，必要时写 `SchemaMigrationPlan`
4. **P1-6 + P1-7 + P1-8** 卡 / 票分类收紧：`.member` 严格归卡；卡包 `+` 入口传 `importMode: .card` 让确认页默认到会员卡；卡包稳定二级排序

✅ 完成后 release-blocking 的客户端 bug 全部清零，剩下都是外部依赖。

### 批次 2 · 导入链路 / 计费 / 体验补强（~1 天）
5. **P1-1 + P1-2** OCR 全链路保留 `\n`，`ScreenshotScanResult` 携带 `ocrText / barcodeFormat / thumbnailData`，确认页不再重解析丢字段
6. **P1-3** `ImportQuotaService`（或 `StoreService.remainingFreeImports(context:)`）统一额度检查
7. **P1-4** 导入去重：保存前按 `barcodeValue + eventDate + venue` 查重
8. **P1-5** Share Extension 错误可观测：App Group 写失败显式提示
9. **P2-1 + P2-2** 详情页"编辑票据" + `+` 菜单加"手动新建"（复用确认页 UI）
10. **P2-3** 签名失败降级：失败时保留"仅保存"和"稍后重试"
11. **P2-4** Wallet 添加状态：关闭 `PKAddPassesViewController` 后延迟一次 `containsPass` 重检
12. **P2-5** 票据列表搜索 / 筛选（"全部"页加 search bar + 类型筛选）
13. **P2-7** 归档入口在卡包 tab 也可见

### 批次 3 · 测试 / 文档 / 工程质量（~半天）
14. **P2-6 + P3-1** 给关键控件加 `.accessibilityIdentifier`；补 `TicketParser` / `Ticket.defaultExpiry` / `PassBuilder` / `ImportQuotaService` 单元测试
15. **P2-8 + P3-2** 文档同步：
    - `CLAUDE.md` 删掉"Key Stubs"表（5 项全部已实现），改为列当前真正 stub 的项（签名节点、Pro 升级页内容）
    - `AGENTS.md`、`docs/review-2026-05-26.md` 同步票据 / 卡包 / 归档新 IA
16. **P3-3** 关键链路 `try?` 改为可诊断错误（保存 / OCR / 签名 / App Group I/O）
17. **P3-4** 设计 token 清理：页面级 spacing / radius 统一到 `AppSpacing`

### 批次 4 · 上线配置 / 服务端依赖（最后执行，需 Apple Developer 后台 + 服务器，~半天）
18. **P0-4** Team ID / Pass Type ID 配置化：`xcconfig` 或 `Info.plist` build setting 注入 `DEVELOPMENT_TEAM` / `PASS_TYPE_IDENTIFIER`，模拟器空值时给清晰错误
19. **P0-5** 签名节点部署：Cloudflare Worker 先行（KV 存证书），国内节点可后置；端到端跑通一次真 `.pkpass`
20. **P0-1** Share Extension 在主 App 的 PlugIns 嵌入：补 `project.yml` dependency + `xcodegen generate`，真机分享菜单验证
21. **P0-2** iCloud 同步策略二选一：要么把 `cloudKitDatabase: .none` 切到 `.privateCloudDatabase`+ 处理 schema 约束，要么 UI 暂时隐藏开关

### 完成判据
- 批次 1 完成：模拟器跑通归档 / 卡包 / Pass JSON 校验，旧 store 迁移无数据丢失
- 批次 2 完成：导入 6 张同条码截图只剩 1 张，免费配额无法绕开
- 批次 3 完成：CI 跑 UI Test + 单测全绿，`CLAUDE.md` / `AGENTS.md` 无过期描述
- 批次 4 完成（最后）：真机分享 → 主 App 落卡，签名节点回包 `.pkpass`，Wallet 接收成功

---

## 执行记录（2026-05-31 · 批次 1–3 已完成）

批次 1–3 共 17 项全部实现，模拟器构建 0 warning / 0 error，**20/20 测试通过**（15 单元 + 5 UI）。批次 4（上线配置 / 服务端）按计划保留待办。

| 批次 | 项 | 状态 | 关键改动 |
|---|---|---|---|
| 1 | P0-3 | ✅ | `PassBuilder`：`barcode` 单 dict + 空值跳过、`transitType`、per-type 颜色 |
| 1 | P0-6/P0-7 | ✅ | `Ticket.canRestore`（仅非过期可恢复）；右滑标记使用写 `archivedAt`；恢复手势/菜单按 `canRestore` 显隐 |
| 1 | P0-8 | ✅ | 旧 schema store 经新构建无损打开，实证轻量迁移成功（无需 `SchemaMigrationPlan`） |
| 1 | P1-6/7/8 | ✅ | `isCard` 仅认 `.member`；`ContentView.importPreferredType` 让卡包导入默认会员卡；`CardWalletView` 稳定二级排序 |
| 2 | P1-1 | ✅ | OCR 全链路改 `\n` 拼接 + `extractPattern` 加 `.dotMatchesLineSeparators`（P1-2 合并代码已实现） |
| 2 | P1-3 | ✅ | `StoreService.remainingFreeImports/isAtFreeImportLimit`（nonisolated static），两处内联检查归一 |
| 2 | P1-4 | ✅ | 确认页按 `barcodeValue+eventDate+venue` 去重 + "仍然保存/取消" |
| 2 | P1-5 | ✅ | ShareViewController App Group 写失败弹明确错误（不再静默打开主 App） |
| 2 | P2-1/P2-2 | ✅ | `RecognitionConfirmView.mode`（confirm/edit）；详情页"编辑票据"；`+` 菜单"手动新建" |
| 2 | P2-3 | ✅ | 签名失败弹 仅保存 / 重试 / 取消；详情页可对未签名票据"添加到 Wallet"重生成 |
| 2 | P2-4 | ✅ | `WalletPresenter` 关闭后延迟 0.4s 再查 `containsPass`，避免误判取消 |
| 2 | P2-5 | ✅ | 全部页搜索框（标题/场馆/座位/标签）+ 类型筛选 chips |
| 2 | P2-7 | ✅ | 卡包 tab 也有已归档入口 |
| 3 | P2-6/P3-1 | ✅ | 关键控件加 `accessibilityIdentifier`；新增 `PassoTests` 单测 target（15 单测）；UI 测试改用 id |
| 3 | P2-8/P3-2 | ✅ | `CLAUDE.md` 删过期 Key Stubs 表、`AGENTS.md` 同步三 tab IA + xcodegen 说明 |
| 3 | P3-3 | ✅ | `RecognitionConfirmView` 保存路径失败弹"保存失败"，不再静默丢数据（详情页次要修改仍 best-effort） |
| 3 | P3-4 | ✅ | sheet 级 `32→AppSpacing.xl`、`24→AppSpacing.lg`（等值，无视觉漂移；`20pt` 无对应 token 保留） |

**工程结构变更（需注意）**：原 `Passo.xcodeproj` 与 `project.yml` 已脱节（pbxproj 手改，含 yml 缺失的 `PassoUITests`）。本次把 `PassoTests` + `PassoUITests` + `Passo` scheme 的 test action 补进 `project.yml` 并执行 `xcodegen generate` 重新生成工程——已验证 entitlements / App Group / iCloud / CloudKit 全部保留，构建与测试全绿。**今后请以 `project.yml` 为准，改文件后跑 `xcodegen generate`。**

---

## 完成度总览（按模块）

| 模块 | 状态 | 备注 |
|---|---|---|
| 数据模型 (`Ticket.swift`) | ✅ 100% | 稳定，含 6 种 `TicketType` + per-type 默认过期规则 |
| 设计系统 + 组件库 | ✅ 100% | `AppSpacing` / `AppAnimation` / `GlassCardView` / `TicketCardView` (580 行，per-type 布局) |
| WalletView | ⚠️ 90% | 已改为票据 tab 内「即将 / 全部」分段 + 归档入口；归档时间和测试稳定性需补 |
| CardWalletView | ⚠️ 80% | 新增卡包 tab，展示会员 / 长期卡；卡片分类规则和卡片专用导入流程需验证 |
| ArchiveView | ⚠️ 80% | 新增统一归档页；过期项“恢复”语义和归档排序需修复 |
| PassDetailView | ✅ 90% | `MKMapSnapshotter` 地图、Wallet 跳转、备注编辑、手动归档已到位；缺完整票据字段编辑 |
| RecognitionConfirmView | ⚠️ 85% | `PassBuilder` + `SigningService` 客户端已接通；Pass JSON、Team ID、服务端签名需真机验证 |
| ScanView | ✅ 95% | `AVCaptureVideoPreviewLayer` + 闪光灯 + Vision 条码全实装 |
| 条码渲染 | ✅ 100% | `CIFilter.qrCodeGenerator / code128BarcodeGenerator` 真实生成 |
| SettingsView | ✅ 90% | StoreKit 2 接通、签名节点切换、`.storekit` 沙盒；少量功能开关待定 |
| 智能提醒 (M4) | ✅ 100% | `UNUserNotificationCenter` + 位置触发后台模式 |
| 地图缩略图 (M5) | ✅ 100% | `MKMapSnapshotter` 缓存到 SwiftData |
| 滑动归档 + 多渠道导入 (M6) | ⚠️ 85% | 左删右标用；相册 / 截图 / Share Extension 三入口存在，但 Share Extension 嵌入、OCR 数据流、归档元数据需修复 |
| Pro 订阅 (M7) | ✅ 90% | `StoreService` (StoreKit 2) 客户端完成；App Store Connect 产品待创建，配额逻辑需集中 |
| iCloud 同步 (M8) | ⚠️ 50% | UI 和 entitlements 已有；`ModelConfiguration` 仍固定 `cloudKitDatabase: .none`，开关当前不生效 |

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

## 2026-05-31 当前代码审查新增待办

### P0 — 新流程阻塞 / 数据正确性

| 编号 | 待办 | 影响 | 涉及文件 | 建议处理 |
|---|---|---|---|---|
| P0-6 | 修复归档页对“已过期”项目的恢复语义 | `isInArchive` 由 `isExpired` 计算得出，`restore()` 清掉 `isArchived/isUsed` 后过期项目仍留在归档中，用户看到“恢复”但没有效果 | `Passo/Views/Wallet/ArchiveView.swift`, `Passo/Views/Detail/PassDetailView.swift`, `Passo/Models/Ticket.swift` | 对自动过期项隐藏/禁用“恢复”，或提供“编辑有效期 / 重新激活”流程；手动归档和已使用项目才执行普通恢复 |
| P0-7 | 为“已使用 / 手动归档”写入归档时间 | 右滑标记使用只设置 `isUsed = true`，`ArchiveView` 排序回退 `importedAt`，旧票刚归档后不会排在顶部 | `Passo/Views/Wallet/WalletView.swift`, `Passo/Views/Detail/PassDetailView.swift`, `Passo/Views/Wallet/ArchiveView.swift`, `Passo/Models/Ticket.swift` | 右滑标记使用时设置 `archivedAt = Date()`；恢复时清空；必要时新增 `usedAt` 区分“使用时间”和“归档时间” |
| P0-8 | 验证新增 SwiftData 字段迁移 | `Ticket` 新增非 optional `isArchived` 和 optional `archivedAt`；现有用户本地 store 迁移未验证 | `Passo/Models/Ticket.swift`, `Passo/PassoApp.swift` | 用已有旧版本数据真机/模拟器升级验证；若失败，改用显式 `SchemaMigrationPlan` 或确保字段默认值可被轻量迁移接受 |

### P1 — 卡包 / 票据分类准确性

| 编号 | 待办 | 影响 | 涉及文件 | 建议处理 |
|---|---|---|---|---|
| P1-6 | 收紧 `isCard` 分类规则 | 当前 `.generic && eventDate == nil` 会把 OCR 不完整的普通二维码 / 活动票误放进卡包，用户可能在票据 tab 找不到 | `Passo/Models/Ticket.swift`, `TicketParser.swift`, `RecognitionConfirmView.swift` | 短期只把 `.member` 归为卡；中期增加显式 `isCardOverride` 或确认页里的“票据 / 卡片”切换 |
| P1-7 | 卡包导入需要卡片语境 | `CardWalletView` 的 `+` 入口复用相册/扫描，但确认页不会默认引导成会员卡，导入后可能仍进入票据或被错误分类 | `CardWalletView.swift`, `ContentView.swift`, `RecognitionConfirmView.swift`, `TicketParser.swift` | 从卡包入口传入 `preferredTicketType: .member` 或 `importMode: .card`，确认页优先显示卡片字段和长期有效逻辑 |
| P1-8 | 卡包排序需要稳定二级规则 | 当前只按 `isExpiringSoon` 布尔排序，同类项目顺序不稳定 | `Passo/Views/Wallet/CardWalletView.swift` | 在即将到期优先后按 `expiresAt ?? .distantFuture`，再按 `importedAt` 倒序排序 |

### P2 — UI / 测试稳定性

| 编号 | 待办 | 价值 | 涉及文件 | 建议处理 |
|---|---|---|---|---|
| P2-6 | 更新 UI Test 为稳定选择器 | `testArchiveFlow` 用 `scrollViews.firstMatch` 坐标滑动，容易滑到列表/空白；`testAllTimeline` 直接点 `全部` 也可能命中非分段控件 | `PassoUITests/PassoUITests.swift`, SwiftUI views | 给关键控件添加 `.accessibilityIdentifier`，测试用 identifier 查找 tab、segmented control、顶部卡片、归档入口 |
| P2-7 | 归档入口可发现性 | 归档入口只在票据 tab 且 `archivedCount > 0` 时出现，卡包用户归档卡片后要回票据 tab 找入口 | `WalletView.swift`, `CardWalletView.swift`, `ContentView.swift` | 在卡包 tab 也提供归档入口，或把归档做成设置/统一二级入口 |
| P2-8 | 修正文档中的旧 tab 架构 + `CLAUDE.md` Key Stubs 全部失效 | 当前 IA 已从「即将 / 全部 / 设置」变成「票据 / 卡包 / 设置」；`CLAUDE.md` 列出的 5 项 stub（相机预览、闪光灯、Vision、PassKit 签名、Wallet 跳转）实际全部已实现，新人按此修改会重复造轮子 | `CLAUDE.md`, `AGENTS.md`, `docs/review-2026-05-26.md`, `plan.md` | `CLAUDE.md` 删除 Key Stubs 表或改写为"当前真正未落地：签名节点、`ProUpgradeSheet` 内容"；其余文档同步票据 / 卡包 / 归档 IA |

---

## 2026-05-30 审查新增待办

### P0 — 上线阻塞 / 核心链路

| 编号 | 待办 | 影响 | 涉及文件 | 建议处理 |
|---|---|---|---|---|
| P0-1 | 修复 Share Extension 未嵌入主 App | 分享扩展 target 存在但可能不会随 App 安装 | `project.yml`, `Passo.xcodeproj/project.pbxproj` | 在 `project.yml` 给 `Passo` 添加 `PassoShareExtension` dependency/embed 配置，重新生成工程并在真机分享菜单验证 |
| P0-2 | 明确 iCloud 同步策略 | 当前设置页开关和 Pro 卖点不生效，影响用户信任 | `Passo/PassoApp.swift`, `Passo/Views/Settings/SettingsView.swift`, `Passo/Models/Ticket.swift` | 短期隐藏开关和文案；或按启动配置启用 CloudKit，并处理 SwiftData CloudKit schema 约束 |
| P0-3 | 修正 PassKit pass.json 关键字段 | Wallet 添加可能被签名服务或系统拒绝 | `Passo/Services/PassBuilder.swift` | `barcode` legacy 字段改为单个 dictionary；`boardingPass` 增加 `transitType`; 补 foreground/background/label/text colors |
| P0-4 | 可靠获取 Team ID / Pass Type ID | `teamIdentifier` 可能为空，导致签名失败 | `Passo/Services/SigningService.swift`, `project.yml` | 将 `DEVELOPMENT_TEAM`、`PASS_TYPE_IDENTIFIER`、`TEAM_IDENTIFIER` 配置化；模拟器给出清晰错误，真机验证真实 entitlements |
| P0-5 | 部署并验证签名节点 | 没有服务端就无法生成 `.pkpass` | `SigningService` 指向的两个 endpoint | 部署国内 / Cloudflare 节点，使用真实 pass certificate 做端到端签名测试 |

### P1 — 导入准确率 / 计费逻辑

| 编号 | 待办 | 影响 | 涉及文件 | 建议处理 |
|---|---|---|---|---|
| P1-1 | 统一 OCR 文本保留换行 | 标题、场馆、日期解析准确率下降 | `CameraService.swift`, `PhotoImportView.swift`, `ScreenshotImportView.swift`, `ShareViewController.swift`, `TicketParser.swift` | OCR lines 用 `"\n"` 拼接，或让 `TicketParser` 接收 `[String]` |
| P1-2 | 修复截图快速导入丢 OCR 信息 | 结果列表看似识别成功，确认页重新 parse 后字段丢失 | `Passo/Views/Settings/ScreenshotImportView.swift` | `ScreenshotScanResult` 保存 `ocrText`、`barcodeFormat`、`thumbnailData`，`makeTicket()` 使用完整数据 |
| P1-3 | 集中免费额度检查 | 多入口各自检查，逻辑重复且容易绕过 | `StoreService.swift`, `PhotoImportView.swift`, `RecognitionConfirmView.swift`, `ScreenshotImportView.swift` | 抽 `ImportQuotaService` 或 `StoreService.remainingFreeImports(context:)`，所有导入入口统一调用 |
| P1-4 | 导入去重 | 同一截图 / 条码可反复导入 | `TicketParser.swift`, 各导入入口 | 保存前按 `barcodeValue + eventDate + venue` 查重，重复时进入已有票据或提示覆盖 |
| P1-5 | Share Extension 错误可观测 | App Group / URL scheme 失败时静默难排查 | `ShareImportService.swift`, `ShareViewController.swift` | App Group ID 配置化；写入失败时展示明确错误；主 App 消费 payload 后记录来源 |

### P2 — 产品能力补充

| 编号 | 待办 | 价值 | 涉及文件 | 建议处理 |
|---|---|---|---|---|
| P2-1 | 增加完整编辑票据页 | 导入后字段识别错误时可修正 | `PassDetailView.swift`, `RecognitionConfirmView.swift` | 复用确认页字段编辑 UI，详情页菜单新增“编辑票据” |
| P2-2 | 增加手动新增票据 | 无截图 / 无条码场景仍可使用 | `WalletView.swift`, `ContentView.swift`, 新增 `ManualTicketEditorView.swift` | 从 `+` 菜单进入空 `Ticket` 编辑，保存到票夹 |
| P2-3 | 签名失败降级和重试 | 签名服务不可用时不阻断本地保存 | `RecognitionConfirmView.swift`, `PassDetailView.swift` | 签名失败后提供“仅保存”和“稍后重试生成 Wallet” |
| P2-4 | Wallet 状态同步优化 | `containsPass` 存在短暂时序问题 | `WalletPresenter.swift`, `PassDetailView.swift` | 关闭 `PKAddPassesViewController` 后延迟检查或在详情页显式刷新 |
| P2-5 | 票据列表搜索 / 筛选 | 票据数量增加后可用性提升 | `WalletView.swift` | 全部页增加搜索、类型筛选、已使用筛选 |

### P3 — 工程质量

| 编号 | 待办 | 价值 | 涉及文件 | 建议处理 |
|---|---|---|---|---|
| P3-1 | 补核心单元测试 | 降低解析、过期、Pass JSON 回归风险 | 新增 test target 或 XCTest files | 覆盖 `TicketParser`, `Ticket.defaultExpiry`, `PassBuilder`, 配额逻辑 |
| P3-2 | 更新过期文档 | 避免后续按错误架构改代码（与 P2-8 配对） | `CLAUDE.md`, `AGENTS.md`, `docs/review-2026-05-26.md`, `plan.md` | 同步当前 票据 / 卡包 / 归档 三 tab 架构、Share Extension 嵌入状态、StoreKit、iCloud 实际状态；`CLAUDE.md` Key Stubs 表整体重写 |
| P3-3 | 减少 `try?` 静默失败 | 关键链路失败时应可诊断 | Services 和导入视图 | 对保存、OCR、签名、App Group 读写加错误状态和用户提示 |
| P3-4 | 设计 token 清理 | 降低视觉漂移 | SwiftUI views | 页面级 spacing/radius 优先替换为 `AppSpacing`；装饰性小常量可保留 |

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
4. 决定是否启用 SwiftData CloudKit：若启用，需要把 `PassoApp.sharedContainer` 的 `cloudKitDatabase` 从 `.none` 切换为 `.privateCloudDatabase`
5. 执行 `xcodegen generate` 让 entitlement 写入 `.xcodeproj`

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
- [ ] Development Team 已配置，且 App / Share Extension 使用同一 Team
- [ ] Share Extension 已嵌入主 App 的 PlugIns 目录
- [ ] Pass Type ID `pass.com.passo.ticket` 已在开发者后台创建并与证书匹配

---

## 后续建议（低优先级，不阻塞上线）

| 建议 | 价值 | 触发时机 |
|---|---|---|
| 在 `AppTheme.swift` 添加 `AppSpacing.lg = 24` token | 让 `ProUpgradeSheet` 6 处、`PhotoImportView` 2 处、`RecognitionConfirmView` 2 处的"sheet 宽 padding"摆脱 magic number，统一引用 token | 下次设计师调整 sheet 间距时 |
| CI / pre-commit 加 `grep -rn "navigationBarHidden\|navigationBarTitle\|navigationBarItems"` 检查 | 自动挡住 iOS 16+ deprecated 的导航 API（这类 API 编译不报错但会引发 1 帧闪烁） | 配置 hooks 时一并加入 |
| 在 CLAUDE.md 注一条"以 `xcodebuild` 为真，忽略 cold-load LSP `Cannot find type` 虚警" | 减少未来会话里被 SourceKit 误报误导 | 下次编辑 CLAUDE.md 时 |
| 用慢动作模拟器（⌘T）做转场 QA 抽查 | 60fps 下 1-2 帧的闪烁人眼难察觉，慢速 ×5 后所有 transient bug 立刻可见 | 上线前最后一轮回归 |
| 将 `ScreenshotImportView` 从 `Views/Settings/` 移到 `Views/Scan/` 或 `Views/Import/` | 当前文件位置按设置页归类，和职责不一致 | 做导入链路重构时 |
| 配置化 App Group / signing endpoints | 方便 Debug、Staging、Production 多环境切换 | 处理 Share Extension 和签名节点时 |

---

## 工程经验沉淀（用于未来会话/审阅）

**Magic number vs design token**：横向 padding 出现非 token 值（如 20pt 偏离 `AppSpacing.md`=16pt）是 push 转场抖动的常见来源。扫"类似问题"时按风险分级：页面布局级 padding > Sheet 内部 padding > 组件内部装饰 padding。装饰间距（6/8/12pt 等）跨视图不会被对比，无需强求统一。

**SwiftUI deprecated API 的隐藏代价**：`.navigationBarHidden(true)` 编译不报错，但在 NavigationStack push 动画期间会出现 1 帧 nav bar 闪现。现代写法 `.toolbar(.hidden, for: .navigationBar)` 没有这个时序 bug。同类还有 `.navigationBarTitle` / `.navigationBarItems`。

**`.contentShape(Circle())` 扩 hit area**：SwiftUI 默认 hit shape 跟随渲染形状，所以一个 36pt 圆按钮的命中区只有 36pt。要在不放大视觉气泡的前提下达到 HIG 44pt，标准做法是 `.frame(36).background(...).clipShape(Circle()).frame(44).contentShape(Circle())`——外层 frame + contentShape 扩展命中区，内层视觉保持紧凑。这比给整个 Button 放大或塞透明 padding view 干净。

**`.ultraThinMaterial` + `rotation3DEffect` 变灰**：Material 效果依赖背后内容，离屏 buffer 没有"背后内容"，所以一旦视图被 rotation3D 推入离屏渲染（如卡片翻转），Material 会 fade to grey。解决方案：用 static fill 替代（见 `GlassCardView.useStaticBackground`）。该参数的注释是项目里少数"解释 WHY 而非 WHAT"的范例，值得保留。

**LSP cold-load 虚警 vs 真实编译错误**：单文件 SourceKit 在跨文件类型未索引完时会报 `Cannot find 'Ticket' in scope`、`No such module 'UIKit'` 等假错。这些是虚警——以 `xcodebuild` 的 `BUILD SUCCEEDED` 为真相源。判断方法：报错行号是否指向**你刚改的代码**；若指向未改的 `@Query`、`import` 等位置，几乎一定是虚警。

**Commit 边界取舍**：理想是"一 commit 一主题"。但同一文件同一波迭代里夹了多个独立 fix 时（如 padding 修复 + 3D flip grey + HIG hit area 都改了 PassDetailView），分 commit 会卡在 hunk-level staging，得不偿失。务实做法：合 commit + 详细 body 分段说明，让 `git log` 单行简洁、单 commit 展开仍可解析。
