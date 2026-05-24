import SwiftUI
import SwiftData

// MARK: - Tab Definition

enum AppTab: Int, CaseIterable {
    case wallet  = 0
    case scan    = 1
    case settings = 2

    var title: String {
        switch self {
        case .wallet:   return "票夹"
        case .scan:     return "扫描"
        case .settings: return "设置"
        }
    }

    var icon: String {
        switch self {
        case .wallet:   return "wallet.pass"
        case .scan:     return "qrcode.viewfinder"
        case .settings: return "gearshape"
        }
    }
}

// MARK: - Content View

struct ContentView: View {
    @State private var selectedTab: AppTab = .wallet
    @State private var showScanSheet = false
    @State private var shareImportTicket: Ticket?

    // U1: today's active ticket count for tab badge
    @Query private var allTickets: [Ticket]
    private var todayBadgeCount: Int {
        allTickets.filter { $0.isToday && !$0.isUsed }.count
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            WalletView(onScanTapped: { showScanSheet = true })
                .tabItem {
                    Label(AppTab.wallet.title, systemImage: AppTab.wallet.icon)
                }
                .badge(todayBadgeCount > 0 ? todayBadgeCount : 0)
                .tag(AppTab.wallet)

            // Scan tab acts as a trigger, not a destination view.
            // Tapping it presents the scan sheet from any tab.
            Color.clear
                .tabItem {
                    Label(AppTab.scan.title, systemImage: AppTab.scan.icon)
                }
                .tag(AppTab.scan)

            SettingsView()
                .tabItem {
                    Label(AppTab.settings.title, systemImage: AppTab.settings.icon)
                }
                .tag(AppTab.settings)
        }
        .onChange(of: selectedTab) { _, newTab in
            if newTab == .scan {
                showScanSheet = true
                selectedTab = .wallet
            }
        }
        .fullScreenCover(isPresented: $showScanSheet) {
            ScanView()
        }
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
