import SwiftUI

@main
struct PassoWatchApp: App {
    @StateObject private var receiver = WatchConnectivityReceiver()

    var body: some Scene {
        WindowGroup {
            WatchTicketListView()
                .environmentObject(receiver)
        }
    }
}
