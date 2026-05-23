import SwiftUI
import SwiftData
import StoreKit

// MARK: - Settings View

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var tickets: [Ticket]

    @AppStorage("signingNodePreference") private var nodePreference = NodePreference.auto
    @AppStorage("isPro")              private var isPro = false
    @AppStorage("iCloudSyncEnabled")  private var iCloudSyncEnabled = true

    @State private var showProSheet      = false
    @State private var showAboutSheet    = false
    @State private var showPhotoImport   = false
    @State private var showScan          = false
    @State private var showClearConfirm  = false

    var body: some View {
        NavigationStack {
            List {
                subscriptionSection
                importSection
                signingNodeSection
                dataSection
                aboutSection
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showProSheet)    { ProUpgradeView().environmentObject(StoreService.shared) }
            .sheet(isPresented: $showAboutSheet)  { AboutView() }
            .sheet(isPresented: $showPhotoImport) { PhotoImportView() }
            .fullScreenCover(isPresented: $showScan) {
                // ScanView needs modelContext — it's provided by the environment
                ScanView()
            }
            .confirmationDialog(
                "清理已过期票据",
                isPresented: $showClearConfirm,
                titleVisibility: .visible
            ) {
                Button("确认清理", role: .destructive) { clearExpiredTickets() }
                Button("取消", role: .cancel) {}
            } message: {
                let count = tickets.filter { $0.isExpired || $0.isUsed }.count
                Text("将删除 \(count) 张已过期或已使用的票据，此操作不可撤销")
            }
        }
    }

    // MARK: - Sections

    private var subscriptionSection: some View {
        Section {
            ProStatusCard(isPro: isPro) { showProSheet = true }
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }

    private var importSection: some View {
        Section("导入") {
            Button {
                showScan = true
            } label: {
                Label("相机扫描", systemImage: "camera")
                    .foregroundStyle(.primary)
            }

            Button {
                showPhotoImport = true
            } label: {
                Label("相册选取", systemImage: "photo.on.rectangle")
                    .foregroundStyle(.primary)
            }

            Label("共享扩展", systemImage: "square.and.arrow.up")
                .foregroundStyle(.secondary)

            NavigationLink {
                Text("截图监听设置")
            } label: {
                Label("截图快速导入", systemImage: "rectangle.dashed.badge.record")
            }
        }
    }

    private var signingNodeSection: some View {
        Section {
            Picker("签名节点", selection: $nodePreference) {
                ForEach(NodePreference.allCases, id: \.self) { pref in
                    Text(pref.displayName).tag(pref)
                }
            }
        } header: {
            Text("Pass 签名")
        } footer: {
            Text("「自动」根据网络位置选择国内或 Cloudflare 节点")
                .font(.caption)
        }
    }

    private var dataSection: some View {
        Section {
            HStack {
                Label("已存票据", systemImage: "tray.full")
                Spacer()
                Text("\(tickets.count) 张")
                    .foregroundStyle(.secondary)
            }

            Toggle(isOn: $iCloudSyncEnabled) {
                Label("iCloud 同步", systemImage: "icloud")
            }
            .disabled(!isPro)

            Button(role: .destructive) {
                showClearConfirm = true
            } label: {
                let count = tickets.filter { $0.isExpired || $0.isUsed }.count
                Label("清理过期票据（\(count) 张）", systemImage: "trash")
            }
            .disabled(tickets.filter { $0.isExpired || $0.isUsed }.isEmpty)
        } header: {
            Text("数据")
        } footer: {
            if isPro {
                Text("iCloud 同步更改将在重启 App 后生效")
                    .font(.caption)
            }
        }
    }

    private var aboutSection: some View {
        Section {
            Button { showAboutSheet = true } label: {
                HStack {
                    Label("关于 Passo", systemImage: "info.circle")
                    Spacer()
                    Text("v1.0.0")
                        .foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(.primary)

            Link(destination: URL(string: "https://passo.app/privacy")!) {
                Label("隐私政策", systemImage: "hand.raised")
            }

            Link(destination: URL(string: "https://passo.app/terms")!) {
                Label("用户协议", systemImage: "doc.text")
            }
        }
    }

    // MARK: - Actions

    private func clearExpiredTickets() {
        let toDelete = tickets.filter { $0.isExpired || $0.isUsed }
        toDelete.forEach { ticket in
            ReminderService.cancelReminder(ticketID: ticket.id)
            modelContext.delete(ticket)
        }
        try? modelContext.save()
    }
}

// MARK: - Pro Status Card

private struct ProStatusCard: View {
    let isPro: Bool
    let onUpgrade: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: isPro
                                ? [Color(hex: "#1A1A2E"), Color(hex: "#E94560")]
                                : [Color(uiColor: .secondarySystemBackground), Color(uiColor: .tertiarySystemBackground)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                Image(systemName: isPro ? "crown.fill" : "crown")
                    .font(.system(size: 22))
                    .foregroundStyle(isPro ? Color(hex: "#FFE66D") : .secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(isPro ? "Passo Pro" : "免费版")
                    .font(.system(size: 16, weight: .semibold))
                Text(isPro ? "无限导入 · iCloud 同步" : "每月 5 张 · 基础功能")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !isPro {
                Button(action: onUpgrade) {
                    Text("升级")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.black)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(AppSpacing.md)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
    }
}

// MARK: - Pro Upgrade View (M7 StoreKit 2)

private struct ProUpgradeView: View {
    @Environment(\.dismiss)      private var dismiss
    @EnvironmentObject private var store: StoreService

    @AppStorage("isPro") private var isPro = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Hero
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(
                                    colors: [Color(hex: "#1A1A2E"), Color(hex: "#E94560")],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ))
                                .frame(width: 80, height: 80)
                            Image(systemName: "crown.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(Color(hex: "#FFE66D"))
                        }
                        Text("Passo Pro")
                            .font(.system(size: 28, weight: .bold))
                        Text("解锁无限导入与 iCloud 跨设备同步")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 24)

                    // Feature list
                    VStack(alignment: .leading, spacing: 14) {
                        featureRow("infinity", "无限票据导入", "免费版每月限 5 张")
                        featureRow("icloud.fill", "iCloud 跨设备同步", "多台设备实时同步票据")
                        featureRow("bolt.fill", "优先扫描通道", "更快的识别速度")
                    }
                    .padding(.horizontal, 24)

                    // Product cards
                    if store.isLoading {
                        ProgressView("加载中…")
                    } else if store.products.isEmpty {
                        Text("暂时无法加载订阅产品，请检查网络")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(store.products, id: \.id) { product in
                                ProductCard(product: product) {
                                    Task { await store.purchase(product) }
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                    }

                    if let err = store.purchaseError {
                        Text(err)
                            .font(.system(size: 13))
                            .foregroundStyle(.red)
                            .padding(.horizontal, 24)
                    }

                    // Restore
                    Button {
                        Task { await store.restore() }
                    } label: {
                        Text("恢复购买")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }

                    Text("订阅将自动续期，可随时在 App Store 订阅管理中取消")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 32)
                }
            }
            .navigationTitle("升级 Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .task { await store.load() }
            .onChange(of: store.isPro) { _, pro in
                if pro { isPro = true; dismiss() }
            }
        }
    }

    private func featureRow(_ icon: String, _ title: String, _ subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(Color(hex: "#E94560"))
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 15, weight: .medium))
                Text(subtitle).font(.system(size: 13)).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

private struct ProductCard: View {
    let product: Product
    let onPurchase: () -> Void

    var isYearly: Bool { product.id.contains("yearly") }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(isYearly ? "年度订阅" : "月度订阅")
                        .font(.system(size: 16, weight: .semibold))
                    if isYearly {
                        Text("省 53%")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color(hex: "#E94560"))
                            .clipShape(Capsule())
                    }
                }
                Text(product.displayPrice + (isYearly ? " / 年" : " / 月"))
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: onPurchase) {
                Text("订阅")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    isYearly ? Color(hex: "#E94560").opacity(0.4) : Color.clear,
                    lineWidth: 1.5
                )
        )
    }
}

// MARK: - About View

private struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "wallet.pass.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(Color(hex: "#E94560"))
                            Text("Passo")
                                .font(.system(size: 24, weight: .bold))
                            Text("智能票据管家")
                                .font(.system(size: 15))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 20)
                        Spacer()
                    }
                }
                .listRowBackground(Color.clear)

                Section("版本") {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0 (1)").foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("开发者")
                        Spacer()
                        Text("Passo").foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("关于")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: Ticket.self, inMemory: true)
        .environmentObject(StoreService.shared)
}
