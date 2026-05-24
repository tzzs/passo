import SwiftUI
import SwiftData

@main
struct PassoApp: App {
    @AppStorage("isPro")             private var isPro = false
    @AppStorage("iCloudSyncEnabled") private var iCloudSyncEnabled = true

    private let store = StoreService.shared

    // Singleton container — SwiftData's SQLite store must not be reopened on every body evaluation.
    // cloudKitDatabase: .none prevents SwiftData from auto-enabling CloudKit via entitlements,
    // which would require every attribute to be Optional.
    private static let sharedContainer: ModelContainer = {
        let config = ModelConfiguration(
            groupContainer: .none,
            cloudKitDatabase: .none
        )
        do {
            return try ModelContainer(for: Ticket.self, configurations: config)
        } catch {
            fatalError("SwiftData: cannot create ModelContainer – \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .task { await store.refreshEntitlements() }
                .onOpenURL { url in
                    // passo://import — triggered by Share Extension hand-off
                    guard url.scheme == "passo", url.host == "import" else { return }
                    NotificationCenter.default.post(name: .passoShareImport, object: nil)
                }
        }
        .modelContainer(PassoApp.sharedContainer)
    }
}
