import SwiftUI
import SwiftData

// MARK: - Tab Definition

enum AppTab: Int, CaseIterable {
    case upcoming = 0  // 即将
    case all      = 1  // 全部
    case settings = 2  // 设置

    var title: String {
        switch self {
        case .upcoming: return "即将"
        case .all:      return "全部"
        case .settings: return "设置"
        }
    }

    var icon: String {
        switch self {
        case .upcoming: return "calendar"
        case .all:      return "list.bullet.rectangle.portrait"
        case .settings: return "gearshape"
        }
    }
}

// MARK: - Content View

struct ContentView: View {
    @State private var selectedTab:      AppTab = .upcoming
    @State private var showScanSheet     = false  // ScanView fullScreenCover
    @State private var showPhotoImport   = false  // PhotoImportView sheet
    @State private var shareImportTicket: Ticket?

    // Badge: today's active ticket count shown on the 即将 tab
    @Query private var allTickets: [Ticket]
    private var todayBadgeCount: Int {
        allTickets.filter { $0.isToday && !$0.isUsed }.count
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            WalletView(
                filter: .upcoming,
                onScanTapped:  { showScanSheet = true },
                onPhotoTapped: { showPhotoImport = true }
            )
            .tabItem { Label(AppTab.upcoming.title, systemImage: AppTab.upcoming.icon) }
            .badge(todayBadgeCount > 0 ? todayBadgeCount : 0)
            .tag(AppTab.upcoming)

            WalletView(
                filter: .all,
                onScanTapped:  { showScanSheet = true },
                onPhotoTapped: { showPhotoImport = true }
            )
            .tabItem { Label(AppTab.all.title, systemImage: AppTab.all.icon) }
            .tag(AppTab.all)

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
        ticket.thumbnailData = payload.thumbnailData
        ticket.sourceApp = "共享扩展"
        shareImportTicket = ticket
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Ticket.self, inMemory: true)
}
