# Passo UI 设计规范

本文档描述 Passo 当前代码中已经落地的 UI 语言、组件模式和交互约定。后续新增页面、重构组件或接入新票据类型时，应优先遵循这里的规则，再考虑新增设计 token 或组件。

## 设计定位

Passo 的界面应接近系统 Wallet 的直接、可信和低干扰体验，同时保留票据类型带来的情绪化色彩。界面重点是快速识别下一张可用票据、确认条码是否可扫、完成导入和添加到 Wallet，而不是做重装饰或营销式表达。

核心体验原则：

- 票据优先：主要屏幕的视觉中心应始终是票据卡片或识别结果。
- 类型有色彩，结构保持一致：不同票据类型通过主题色和字段布局区分，导航、按钮和信息层级保持稳定。
- 黑暗模式更具沉浸感，浅色模式更系统化：深色页面使用票据主题渐变和玻璃材质；浅色页面优先使用系统背景色。
- 操作路径短：扫描、相册导入、确认、添加 Wallet 应保持单步可见或贴近当前上下文。

## 主题系统

主题源头是 `TicketType.theme`，定义在 `Passo/Theme/AppTheme.swift`。

每个 `TicketType` 必须提供：

- `backgroundStart`
- `backgroundEnd`
- `accent`
- `accentSecondary`

当前类型与语义：

| 类型 | 展示名 | 用途 |
|---|---|---|
| `movie` | 电影 | 电影票、影院核销码 |
| `concert` | 演出 | 演唱会、音乐节、剧院演出 |
| `train` | 高铁 | 火车 / 高铁出行票据 |
| `member` | 会员 | 会员卡、积分卡、储值卡 |
| `scenic` | 景点 | 景区、博物馆、公园预约票 |
| `generic` | 通用 | 无法明确分类的票据 |

使用规则：

- 卡片、扫描框、详情页头图和高亮状态都应从 `ticket.ticketType.theme` 派生颜色。
- 不要在业务视图里重新定义票据类型颜色。
- 新增票据类型时，必须同步补充主题、展示名、图标语义、解析规则、卡片布局和 PassKit 字段映射。
- `Color(hex: "#RRGGBB")` 是项目内十六进制颜色入口；避免散落自定义 `Color(red:green:blue:)`。

## 设计 Token

统一使用 `AppSpacing` 和 `AppAnimation`：

```swift
AppSpacing.xs
AppSpacing.sm
AppSpacing.md
AppSpacing.lg
AppSpacing.xl
AppSpacing.radiusCard
AppSpacing.radiusButton
AppSpacing.radiusTag

AppAnimation.themeChange
AppAnimation.cardFlip
AppAnimation.cardAppear
AppAnimation.scanPulse
```

使用规则：

- 页面横向内边距默认使用 `AppSpacing.md`。
- 卡片圆角默认使用 `AppSpacing.radiusCard`。
- 按钮圆角默认使用 `AppSpacing.radiusButton` 或具体系统形状，如 `Circle()` / `Capsule()`。
- 标签和小型状态块使用 `AppSpacing.radiusTag` 或 6-10pt 的局部圆角。
- 主题变化必须使用 `AppAnimation.themeChange`，卡片翻转使用 `AppAnimation.cardFlip`，扫描线使用 `AppAnimation.scanPulse`。

## 字体与信息层级

当前代码使用系统字体，不引入外部字体。

推荐层级：

| 场景 | 字号 / 权重 |
|---|---|
| 首页品牌标题 | 34 bold |
| 票据标题 full card | 24 bold |
| 票据标题 compact card | 18 bold |
| 页面导航标题 | 17 semibold |
| 主按钮文字 | 16 semibold / medium |
| 字段值 | 15-18 semibold |
| 字段标签 / 辅助说明 | 11-13 regular / medium |
| 条码原文 | 10 monospaced |

文本规则：

- 票据标题单行显示，必要时使用 `minimumScaleFactor(0.8)`。
- 条码、人为编号、原始码值使用 monospaced 字体并保持字距。
- 辅助信息使用透明度降低权重，而不是新增强颜色。
- 页面文案优先使用中文，因为当前 App UI 文案主要是中文。

## 核心组件

### `GlassCardView`

用途：玻璃拟态容器，承载票据卡片和详情背面内容。

视觉构成：

- `.ultraThinMaterial` 或静态透明背景
- 1pt 高光描边
- 顶部 1pt 高光线
- 多层阴影
- 可选 `glowColor`

使用规则：

- 常规页面使用默认材质背景。
- 当宿主视图使用 `rotation3DEffect` 时，使用 `useStaticBackground: true`，避免离屏渲染导致材质发灰。
- 不要在 `GlassCardView` 外再套一层装饰性卡片。

### `GlassPillButton`

用途：顶部返回、扫描、相册、更多等图标按钮。

规则：

- 视觉圆形按钮尺寸为 44x44，满足 iOS 命中目标。
- 使用 SF Symbols 图标，不使用文字按钮替代明确的图标命令。
- 深色模式使用白色半透明背景，浅色模式使用黑色低透明背景。

### `GlassSegmentedControl`

用途：首页筛选，如“即将 / 全部”。

规则：

- 仅用于少量互斥状态。
- 选中态通过背景高亮、阴影和透明度表达。
- 选项文字保持短标签，不承载解释文案。

### `TicketTypeBadge`

用途：票据类型和 emoji 标识。

规则：

- 显示 `TicketType.displayName` 和 `TicketType.emoji`。
- 前景色和描边使用当前类型 `accent`。
- 用于卡片头部和识别确认类型选择。

### `TicketCardView`

用途：票据展示的核心组件。

尺寸：

- `.full`：完整卡片，包含头部、类型字段、撕票分割线和条码区。
- `.compact`：预览卡片，不展示条码，适合票堆第二张、确认页预览等。

布局规则：

- full card 必须展示 `TicketTypeBadge`、标题和可用倒计时。
- 可用票据使用主题 glow；已使用票据降低饱和度与透明度。
- 条码区使用白底，保证可扫性优先于沉浸视觉。
- 条码占位必须稳定，不因异步生成造成明显布局跳动。

类型布局：

- 电影 / 通用：标准字段网格，优先展示时间、影厅 / 类型、座位 / 编号。
- 演出：区域、座位、时间，附加标签 chips。
- 高铁：出发地、目的地、历时线、车厢和座位。
- 会员：等级、积分和权益标签。
- 景点：入场时间、票种、数量和入园时段提示。

## 页面规范

### 根导航

`ContentView` 使用三个 tab：

- 票夹
- 扫描
- 设置

扫描 tab 是触发器，不是目的地。点击扫描 tab 后必须切回票夹并以 full-screen cover 展示 `ScanView`。不要为扫描 tab 绑定独立空页面。

### 票夹首页

`WalletView` 是默认首页。

结构：

- 顶部品牌标题 `Passo`
- 右侧相册导入和扫描图标按钮
- 筛选控件
- 下一张提示或倒计时
- 票据堆叠 / 时间线
- 底部导入操作栏

规则：

- 深色模式背景使用当前第一张票据的主题渐变。
- 浅色模式背景使用 `systemGroupedBackground`。
- “即将”模式显示票据堆叠，顶部票据支持左右滑动操作。
- “全部”模式显示时间线，已使用票据沉到底部。
- 空状态必须提供明确导入入口。

### 扫描页

`ScanView` 是全屏相机体验。

结构：

- 黑色沉浸背景
- 顶部关闭与闪光灯按钮
- 52% 屏高相机区域
- 扫描角标和扫描线
- 检测成功后展示结果 sheet

规则：

- 扫描强调色随识别出的 `TicketType.theme.accent` 更新。
- 未授权相机时显示权限说明和打开设置按钮。
- 检测结果提供“添加到 Wallet”和编辑入口。
- 重新扫描必须清空上次检测值，允许相同条码再次触发。

### 识别确认页

`RecognitionConfirmView` 用于编辑 OCR 结果并触发 Wallet 添加。

规则：

- 顶部展示 compact 票据预览。
- 字段编辑放在系统背景卡片内。
- 类型选择横向 chips，选中态使用对应类型主题色。
- 自定义字段最多两个槽位，对应 `extraField1` 和 `extraField2`。
- 签名或 Wallet 添加失败必须用明确错误反馈，不吞掉失败状态。

### 详情页

`PassDetailView` 是沉浸式详情。

规则：

- 顶部使用票据主题渐变。
- 主卡片可 3D 翻转，正面展示票据，背面展示备注、原始条码和来源。
- 地图缩略图只在有位置或可地理编码时启用。
- 提醒开关使用当前票据主题色。
- Wallet 打开按钮仅在 `isAddedToWallet` 为真时启用。

### 设置页

设置页使用系统 `List` 样式，适合密集配置。

规则：

- 订阅状态使用顶部状态卡片。
- 导入入口集中在“导入” section。
- 签名节点使用 `Picker`。
- 数据清理使用 destructive button 和 confirmation dialog。
- Pro 门控功能应禁用并保留可见说明，不应完全隐藏。

## 交互规范

- 可点击图标按钮最小命中区域为 44x44。
- 重要状态变化使用 `withAnimation` 和既有 token。
- 票据滑动操作要有阈值，不能轻触误触发。
- 删除、清理等不可逆操作必须二次确认。
- Wallet 添加、签名、购买、恢复购买等异步流程必须有 loading 或错误状态。
- 触觉反馈用于扫描成功、卡片翻转、关键确认等少数场景，不泛用。

## 无障碍与本地化

当前代码还没有系统化 accessibility identifier。新增 UI 时应补充：

- 主要按钮的 `accessibilityLabel`
- UI 测试稳定节点的 `accessibilityIdentifier`
- 图标-only 按钮必须有可读含义
- 票据标题、时间、地点、条码状态应能被 VoiceOver 读出

本地化规则：

- App 当前以中文 UI 为主。
- 面向开发者的 README / Docs 可以中英双版本；App 内文案新增时先保持中文一致性。
- 日期展示优先使用系统 `formatted(...)`，避免手写格式导致地区不一致。

## 新 UI 的验收清单

新增或改动 UI 前后检查：

- 是否使用 `AppSpacing` / `AppAnimation`。
- 是否从 `TicketType.theme` 派生票据色彩。
- 是否复用 `GlassCardView`、`TicketCardView`、`GlassPillButton` 等既有组件。
- 深色和浅色模式是否都可读。
- 长标题、无地点、无时间、无条码、已使用状态是否稳定。
- 图标按钮是否有 44pt 命中区域。
- 删除或清理是否有确认。
- 异步失败是否可见。
- 是否影响扫描 tab 触发器约定。
