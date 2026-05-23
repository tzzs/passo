# Passo 待办事项

## 功能开发

### M7 · Pro 订阅（StoreKit 2）

**目标**：接入 StoreKit 2，将 `@AppStorage("isPro")` 与真实的 In-App Purchase 状态同步。

**文件**：`Views/Settings/SettingsView.swift` → `ProUpgradeView`（当前为占位符 sheet）

#### 实现步骤

1. **配置 App Store Connect 产品**
   - 月订阅 `com.passo.pro.monthly`（建议售价 ¥12）
   - 年订阅 `com.passo.pro.yearly`（建议售价 ¥68）
   - 在 Xcode → Signing & Capabilities 添加 In-App Purchase capability

2. **新建 `Services/StoreService.swift`**

   ```swift
   import StoreKit

   @MainActor
   final class StoreService: ObservableObject {
       @Published var products: [Product] = []
       @Published var isPro = false

       static let productIDs = ["com.passo.pro.monthly", "com.passo.pro.yearly"]

       func load() async {
           products = (try? await Product.products(for: Self.productIDs)) ?? []
           await refreshEntitlement()
       }

       func purchase(_ product: Product) async throws {
           let result = try await product.purchase()
           if case .success = result { await refreshEntitlement() }
       }

       func refreshEntitlement() async {
           for await result in Transaction.currentEntitlements {
               if case .verified(let tx) = result, !tx.isExpired {
                   isPro = true
                   return
               }
           }
           isPro = false
       }

       func restore() async {
           try? await AppStore.sync()
           await refreshEntitlement()
       }
   }
   ```

3. **改写 `ProUpgradeView`**
   - `@StateObject private var store = StoreService()`
   - `.task { await store.load() }` 启动时加载产品
   - 展示月/年订阅价格卡片（从 `product.displayPrice` 读取，不硬编码）
   - 购买按钮调用 `store.purchase(product)`，加载状态用 `ProgressView`
   - 底部「恢复购买」调用 `store.restore()`
   - 处理 `StoreKitError` 并展示 Alert

4. **同步 `isPro` 到 `@AppStorage`**

   在 `ProUpgradeView` 的 `.onChange(of: store.isPro)` 里写入 `@AppStorage("isPro")`，保持 `PassoApp` 的 CloudKit 开关联动。

5. **Pro 功能门控验证**
   - iCloud 同步开关（`SettingsView` 已有 `.disabled(!isPro)`）
   - 导入数量限制：`@Query` 票据数 ≥ 5 时弹出升级提示（免费版限制）
   - LLM 分类开关（预留，当前无此功能）

#### 验证方式
在 Xcode → Product → Scheme → StoreKit Configuration 挂载 `.storekit` 配置文件，用沙盒账号走完整个购买流程，确认 `isPro` 变为 `true` 且 iCloud 同步生效。

---

## 部署配置（真机/生产必做）

### Pass 签名节点

当前 `SigningService` 指向的端点 `sign.passo.cn` / `passo-sign.workers.dev` 尚未部署。

**国内节点**（服务端，任意语言）
- 接收 `POST /api/sign`，Content-Type: `application/json`，Body 为 pass.json
- 用 Apple Pass Type Certificate（`.p12`）做 PKCS#7 签名
- 打包 icon.png、logo.png、pass.json、manifest.json、signature 为 `.pkpass`（zip 格式）
- 返回 Content-Type: `application/vnd.apple.pkpass`

**海外节点**（Cloudflare Worker）
- 相同接口，部署在 `passo-sign.workers.dev`
- 证书以 KV secret 存储，避免明文提交

参考：[PassKit Package Format Reference](https://developer.apple.com/documentation/walletpasses/building_a_pass)

### CloudKit Dashboard

1. 登录 [CloudKit Console](https://icloud.developer.apple.com)
2. 创建 container `iCloud.com.passo.app`
3. 在 Xcode → Signing & Capabilities → iCloud 勾选该 container
4. 重新 `xcodegen generate` 使 entitlement 生效

### 位置提醒（真机）

`UNLocationNotificationTrigger` 在模拟器无效。真机测试：
1. 在 `Info.plist` 确认 `NSLocationWhenInUseUsageDescription` 已存在（已配置）
2. 添加 `NSLocationAlwaysAndWhenInUseUsageDescription`（如需后台触发）
3. 在 `ReminderService.scheduleLocationReminder` 调用前先请求 `CLLocationManager` 的 `requestWhenInUseAuthorization()`

---

## 已知 Bug / 待修复

| 位置 | 描述 | 优先级 |
|---|---|---|
| `WalletPresenter.swift:56` | `addPassesViewControllerDidFinish` 用 `passes().isEmpty` 判断是否添加成功不够精准，应改为 `PKPassLibrary().contains(pass)` | 低 |
| `TicketParser.swift` | OCR 仅在扫描时传空字符串，未并行跑帧 OCR；需在 `CameraService` 的 `sampleBuffer` 回调里异步触发 `VNRecognizeTextRequest` | 中 |
| `PhotoImportView.swift` | 缩略图裁剪为正方形，票据纵向截图会被压缩；改为 `UIImage.preparingThumbnail(of:)` 保持宽高比 | 低 |

---

## 完成度总览

| 里程碑 | 状态 |
|---|---|
| M1 扫描引擎（AVFoundation + Vision + OCR） | ✅ |
| M2 真实条码渲染（Core Image） | ✅ |
| M3 PassKit 签名流水线 | ✅（客户端完成，签名节点待部署） |
| M4 智能提醒（UNUserNotificationCenter） | ✅ |
| M5 地图缩略图（MKMapSnapshotter） | ✅ |
| M6 滑动归档 + 相册导入 | ✅ |
| M7 Pro 订阅（StoreKit 2） | ⬜ 待实现 |
| M8 iCloud 同步（CloudKit） | ✅（客户端完成，Dashboard 待配置） |
