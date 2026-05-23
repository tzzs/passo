import SwiftUI
import SwiftData

@main
struct PassoApp: App {
    @AppStorage("isPro")             private var isPro = false
    @AppStorage("iCloudSyncEnabled") private var iCloudSyncEnabled = true

    private let store = StoreService.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .task { await store.refreshEntitlements() }
        }
        .modelContainer(appContainer)
    }

    /// CloudKit-backed store when Pro + iCloud sync enabled; local-only otherwise.
    /// Switching requires an app restart (ModelContainer cannot change at runtime).
    private var appContainer: ModelContainer {
        let schema = Schema([Ticket.self])

        if isPro && iCloudSyncEnabled,
           let container = try? ModelContainer(
            for: schema,
            configurations: ModelConfiguration(
                schema: schema,
                cloudKitDatabase: .automatic
            )
           ) {
            return container
        }

        return try! ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema)
        )
    }
}
