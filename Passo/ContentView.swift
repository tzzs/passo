import SwiftUI
import SwiftData

// MARK: - Tab Definition

enum AppTab: Int, CaseIterable {
    case tickets  = 0  // 票据（即将/全部 + 归档入口）
    case cards    = 1  // 卡包（会员/长期卡）
    case settings = 2  // 设置

    var title: String {
        switch self {
        case .tickets:  return "票据"
        case .cards:    return "卡包"
        case .settings: return "设置"
        }
    }

    var icon: String {
        switch self {
        case .tickets:  return "ticket"
        case .cards:    return "creditcard"
        case .settings: return "gearshape"
        }
    }
}

// MARK: - Content View

struct ContentView: View {
    @State private var selectedTab:      AppTab = .tickets
    @State private var showScanSheet     = false  // ScanView fullScreenCover
    @State private var showPhotoImport   = false  // PhotoImportView sheet
    @State private var shareImportTicket: Ticket?

    // Badge: today's active ticket count shown on the 即将 tab
    @Query private var allTickets: [Ticket]
    private var todayBadgeCount: Int {
        allTickets.filter { $0.isToday && !$0.isCard && !$0.isInArchive }.count
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            WalletView(
                onScanTapped:  { showScanSheet = true },
                onPhotoTapped: { showPhotoImport = true }
            )
            .tabItem { Label(AppTab.tickets.title, systemImage: AppTab.tickets.icon) }
            .badge(todayBadgeCount > 0 ? todayBadgeCount : 0)
            .tag(AppTab.tickets)

            CardWalletView(
                onScanTapped:  { showScanSheet = true },
                onPhotoTapped: { showPhotoImport = true }
            )
            .tabItem { Label(AppTab.cards.title, systemImage: AppTab.cards.icon) }
            .tag(AppTab.cards)

            SettingsView()
                .tabItem { Label(AppTab.settings.title, systemImage: AppTab.settings.icon) }
                .tag(AppTab.settings)
        }
        .fullScreenCover(isPresented: $showScanSheet) {
            ScanView()
        }
        .sheet(isPresented: $showPhotoImport) {
            PhotoImportView()
        }
        // Share-extension import path — ticket arrives via passo:// URL or NSNotification
        .sheet(item: $shareImportTicket) { ticket in
            RecognitionConfirmView(ticket: ticket)
        }
        .onReceive(NotificationCenter.default.publisher(for: .passoShareImport)) { _ in
            handleShareImport()
        }
        .onAppear {
            // Handle import if app was cold-launched via passo:// URL scheme
            handleShareImport()
        }
    }

    private func handleShareImport() {
        guard let payload = ShareImportService.consumePendingPayload() else { return }
        let ticket = TicketParser.parse(barcodeValue: payload.barcodeValue, ocrText: payload.ocrText)
        ticket.barcodeFormat = payload.barcodeFormat
        ticket.thumbnailData = payload.thumbnailData
        ticket.sourceApp = "共享扩展"
        shareImportTicket = ticket
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Ticket.self, inMemory: true)
}
