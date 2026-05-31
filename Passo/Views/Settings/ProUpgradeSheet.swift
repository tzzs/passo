import SwiftUI
import StoreKit

// MARK: - Pro Upgrade Sheet

/// Reusable upgrade prompt shown when a free-tier user hits the 5-ticket import limit.
/// Must be presented with StoreService in the environment:
///   `.sheet { ProUpgradeSheet().environmentObject(StoreService.shared) }`
struct ProUpgradeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: StoreService
    @AppStorage("isPro") private var isPro = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    heroSection
                    limitBanner
                    featureList
                    productCards
                    errorLabel
                    restoreButton
                    legalText
                }
                .padding(.bottom, 32)
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

    // MARK: Sections

    private var heroSection: some View {
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
    }

    private var limitBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.orange)
            Text("免费版每月最多导入 5 张票据，升级 Pro 解锁无限导入")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 24)
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 14) {
            featureRow("infinity",       "无限票据导入",     "免费版每月限 5 张")
            featureRow("icloud.fill",    "iCloud 跨设备同步", "多台设备实时同步票据")
            featureRow("bolt.fill",      "优先扫描通道",     "更快的识别速度")
        }
        .padding(.horizontal, 24)
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

    @ViewBuilder
    private var productCards: some View {
        if store.isLoading {
            ProgressView("加载中…")
        } else if store.products.isEmpty {
            Text("暂时无法加载订阅产品，请检查网络")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        } else {
            let monthly = store.products.first { $0.id.contains("monthly") }
            let yearly  = store.products.first { $0.id.contains("yearly") }
            // Compute savings % dynamically so it stays accurate if prices change
            let yearlySavingsLabel: String? = {
                guard let m = monthly, let y = yearly, m.price > 0 else { return nil }
                let annualEquiv = m.price * 12
                let ratio = y.price / annualEquiv
                let pct = NSDecimalNumber(decimal: (1 - ratio) * 100).intValue
                return pct > 0 ? "省 \(pct)%" : nil
            }()

            VStack(spacing: 12) {
                ForEach(store.products, id: \.id) { product in
                    let savings = product.id.contains("yearly") ? yearlySavingsLabel : nil
                    UpgradeProductCard(product: product, savingsLabel: savings) {
                        Task { await store.purchase(product) }
                    }
                }
            }
            .padding(.horizontal, 24)
        }
    }

    @ViewBuilder
    private var errorLabel: some View {
        if let err = store.purchaseError {
            Text(err)
                .font(.system(size: 13))
                .foregroundStyle(.red)
                .padding(.horizontal, 24)
        }
    }

    private var restoreButton: some View {
        Button {
            Task { await store.restore() }
        } label: {
            Text("恢复购买")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
    }

    private var legalText: some View {
        Text("订阅将自动续期，可随时在 App Store 订阅管理中取消")
            .font(.system(size: 11))
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
    }
}

// MARK: - Upgrade Product Card

struct UpgradeProductCard: View {
    let product: Product
    let savingsLabel: String?
    let onPurchase: () -> Void

    var isYearly: Bool { product.id.contains("yearly") }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(isYearly ? "年度订阅" : "月度订阅")
                        .font(.system(size: 16, weight: .semibold))
                    if let label = savingsLabel {
                        Text(label)
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
                    .padding(.vertical, 12)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusTag))
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .padding(AppSpacing.md)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusButton))
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.radiusButton)
                .strokeBorder(
                    isYearly ? Color(hex: "#E94560").opacity(0.4) : Color.clear,
                    lineWidth: 1.5
                )
        )
    }
}
