import SwiftUI
import SwiftData

// MARK: - Settings View

/// App settings in system Inset Grouped style.
/// Design reference: product spec §5.3 Settings Page
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var tickets: [Ticket]

    @AppStorage("signingNodePreference") private var nodePreference = NodePreference.auto
    @AppStorage("isPro") private var isPro = false
    @State private var showProSheet   = false
    @State private var showAboutSheet = false

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
            .sheet(isPresented: $showProSheet)   { ProUpgradeView() }
            .sheet(isPresented: $showAboutSheet) { AboutView() }
        }
    }

    // MARK: Sections

    private var subscriptionSection: some View {
        Section {
            ProStatusCard(isPro: isPro) {
                showProSheet = true
            }
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }

    private var importSection: some View {
        Section("导入") {
            Label("相机扫描", systemImage: "camera")
            Label("相册选取", systemImage: "photo.on.rectangle")
            Label("共享扩展", systemImage: "square.and.arrow.up")

            NavigationLink {
                Text("截图监听设置") // Placeholder
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
        Section("数据") {
            HStack {
                Label("已存票据", systemImage: "tray.full")
                Spacer()
                Text("\(tickets.count) 张")
                    .foregroundStyle(.secondary)
            }

            Toggle(isOn: .constant(false)) {
                Label("iCloud 同步", systemImage: "icloud")
            }
            .disabled(!isPro)

            Button(role: .destructive) {
                // TODO: clear expired tickets
            } label: {
                Label("清理已过期票据", systemImage: "trash")
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
                Text(isPro ? "无限导入 · LLM 分类 · iCloud 同步" : "每月 5 张 · 基础分类")
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

// MARK: - Node Preference

enum NodePreference: String, CaseIterable {
    case auto     = "auto"
    case domestic = "domestic"
    case overseas = "overseas"

    var displayName: String {
        switch self {
        case .auto:     return "自动"
        case .domestic: return "国内节点"
        case .overseas: return "海外节点 (Cloudflare)"
        }
    }
}

// MARK: - Placeholder Sheets

private struct ProUpgradeView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Text("Pro 订阅页面")
                .navigationTitle("升级 Pro")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("关闭") { dismiss() }
                    }
                }
        }
    }
}

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
                        Text("1.0.0 (1)")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("开发者")
                        Spacer()
                        Text("Passo")
                            .foregroundStyle(.secondary)
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
}
