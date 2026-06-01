import SwiftUI
import SwiftData

// MARK: - Settings View

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var tickets: [Ticket]

    @AppStorage("signingNodePreference") private var nodePreference = NodePreference.auto
    @AppStorage("isPro")              private var isPro = false
    @AppStorage("iCloudSyncEnabled")  private var iCloudSyncEnabled = true

    @State private var showProSheet           = false
    @State private var showAboutSheet         = false
    @State private var showPhotoImport        = false
    @State private var showScan               = false
    @State private var showClearConfirm       = false
    @State private var showShareExtensionTip  = false

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
            .sheet(isPresented: $showProSheet)    { ProUpgradeSheet().environmentObject(StoreService.shared) }
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
            ProStatusCard(
                isPro: isPro,
                remaining: isPro ? 0 : StoreService.remainingFreeImports(isPro: false, tickets: tickets),
                limit: StoreService.freeMonthlyImportLimit
            ) { showProSheet = true }
        }
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

            HStack {
                Label("共享扩展", systemImage: "square.and.arrow.up")
                    .foregroundStyle(.primary)
                Spacer()
                Text("系统级")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(uiColor: .tertiarySystemBackground))
                    .clipShape(Capsule())
            }
            .contentShape(Rectangle())
            .onTapGesture { showShareExtensionTip = true }
            .alert("如何使用共享扩展", isPresented: $showShareExtensionTip) {
                Button("好的") {}
            } message: {
                Text("在任意 App 中找到要导入的票据截图，点击「分享」，然后选择「Passo」即可自动识别。首次使用前需在分享菜单中点「更多」启用 Passo。")
            }

            NavigationLink {
                ScreenshotImportView()
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
                    Text("v\(appVersionString)")
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

    // MARK: - Helpers

    private var appVersionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build   = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
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
    /// Imports left this month (only meaningful when `!isPro`).
    let remaining: Int
    let limit: Int
    let onUpgrade: () -> Void

    private var isDepleted: Bool { !isPro && remaining <= 0 }
    /// Fraction of quota *remaining* — full bar means plenty left.
    private var progress: Double {
        guard limit > 0 else { return 0 }
        return Double(max(0, min(limit, remaining))) / Double(limit)
    }
    /// Bar color tracks how much is left: plenty → brand green, almost out → amber, depleted → red.
    private var meterColor: Color {
        switch remaining {
        case 0:  return Color(hex: "#E94560")
        case 1:  return Color(hex: "#FF9500")
        default: return Color(hex: "#34C759")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppSpacing.radiusButton)
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
                    Text(isPro ? "无限导入 · iCloud 同步" : (isDepleted ? "本月额度已用完" : "基础功能"))
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if !isPro {
                    Button(action: onUpgrade) {
                        Text("升级")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.black)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.borderless)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
            }

            if !isPro {
                usageMeter
            }
        }
        .padding(.vertical, AppSpacing.xs)
    }

    private var usageMeter: some View {
        VStack(spacing: AppSpacing.xs) {
            HStack {
                Text("本月额度")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(isDepleted ? "已达上限" : "还可导入 \(remaining) 张")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isDepleted ? Color(hex: "#E94560") : .primary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(uiColor: .tertiarySystemFill))
                    Capsule()
                        .fill(meterColor)
                        .frame(width: max(geo.size.width * progress, progress > 0 ? 8 : 0))
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - About View

private struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private var appVersionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build   = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

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
                        Text(appVersionString).foregroundStyle(.secondary)
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
