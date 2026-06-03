import SwiftUI

// MARK: - Onboarding

/// First-launch introduction shown once (gated by @AppStorage("hasSeenOnboarding")
/// in ContentView). Explains the three import paths and the Wallet capability so
/// new users understand what Passo does before they hit an empty 票据 list.
struct OnboardingView: View {
    /// Called when the user finishes or skips. The caller flips the persisted flag.
    let onFinish: () -> Void

    @State private var current = 0

    private let pages: [Page] = [
        Page(
            icon: "ticket.fill",
            title: "欢迎使用 Passo",
            subtitle: "把电影、演唱会、高铁票和会员卡集中收纳在一处，随时取用。"
        ),
        Page(
            icon: "plus.viewfinder",
            title: "三种方式导入",
            subtitle: "从相册截图识别、扫描条码，或手动新建——一张票几秒入库。"
        ),
        Page(
            icon: "wallet.pass.fill",
            title: "加入 Apple Wallet",
            subtitle: "把票据签名后添加到系统钱包，到场时锁屏即可亮码进场。"
        )
    ]

    private var isLastPage: Bool { current == pages.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("跳过") { onFinish() }
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .padding(AppSpacing.md)
            }

            TabView(selection: $current) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    pageView(page).tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .animation(.easeInOut, value: current)

            Button {
                if isLastPage {
                    onFinish()
                } else {
                    withAnimation { current += 1 }
                }
            } label: {
                Text(isLastPage ? "开始使用" : "下一步")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.md)
            }
            .buttonStyle(.borderedProminent)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusButton, style: .continuous))
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.xl)
            .accessibilityIdentifier("onboardingPrimaryButton")
        }
    }

    private func pageView(_ page: Page) -> some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()
            Image(systemName: page.icon)
                .font(.system(size: 76, weight: .light))
                .foregroundStyle(.tint)
                .frame(height: 96)
            VStack(spacing: AppSpacing.sm) {
                Text(page.title)
                    .font(.system(size: 26, weight: .bold))
                    .multilineTextAlignment(.center)
                Text(page.subtitle)
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
            }
            Spacer()
            Spacer()
        }
    }

    private struct Page {
        let icon: String
        let title: String
        let subtitle: String
    }
}

#Preview {
    OnboardingView(onFinish: {})
}
