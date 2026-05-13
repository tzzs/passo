import SwiftUI
import SwiftData

@main
struct PassoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: Ticket.self)
    }
}
