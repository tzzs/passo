import SwiftUI
import SwiftData

@main
struct PassoApp: App {
    @AppStorage("isPro")             private var isPro = false
    @AppStorage("iCloudSyncEnabled") private var iCloudSyncEnabled = true

    private let store = StoreService.shared

    // Singleton container — SwiftData's SQLite store must not be reopened on every body evaluation.
    static let sharedContainer: ModelContainer = makeContainer()

    /// CloudKit container identifier declared in `Passo.entitlements`.
    static let cloudKitContainerID = "iCloud.com.passo.app"

    /// App Group identifier — the SwiftData store lives here so extensions
    /// (Widget, Share) read the same database as the app.
    static let appGroupID = "group.com.passo.app"

    /// Builds the SwiftData container, enabling CloudKit mirroring only when the
    /// user is Pro AND has the iCloud sync toggle on. The decision is made once at
    /// launch — SwiftData cannot hot-swap a container's CloudKit backing at runtime,
    /// which is why Settings shows a "takes effect after restart" note.
    static func makeContainer() -> ModelContainer {
        // Read straight from UserDefaults — @AppStorage isn't reachable from this
        // static context. Mirror the @AppStorage defaults: sync on, Pro off.
        let syncEnabled = UserDefaults.standard.object(forKey: "iCloudSyncEnabled") as? Bool ?? true
        let isPro       = UserDefaults.standard.bool(forKey: "isPro")
        let useCloudKit = syncEnabled && isPro

        let cloudDatabase: ModelConfiguration.CloudKitDatabase = useCloudKit
            ? .private(cloudKitContainerID)
            : .none
        let config = ModelConfiguration(groupContainer: .identifier(appGroupID), cloudKitDatabase: cloudDatabase)

        do {
            return try ModelContainer(for: Ticket.self, configurations: config)
        } catch {
            // CloudKit can fail to initialize (no signed-in iCloud account, Simulator
            // without iCloud, schema mismatch). Rather than crash and lock the user
            // out of their tickets, fall back to a local-only store.
            if useCloudKit,
               let local = try? ModelContainer(
                   for: Ticket.self,
                   configurations: ModelConfiguration(groupContainer: .identifier(appGroupID), cloudKitDatabase: .none)
               ) {
                return local
            }
            fatalError("SwiftData: cannot create ModelContainer – \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .task { await store.refreshEntitlements() }
                .task {
                    #if DEBUG
                    seedPreviewDataIfNeeded()
                    #endif
                }
                .onOpenURL { url in
                    // passo://import — triggered by Share Extension hand-off
                    guard url.scheme == "passo", url.host == "import" else { return }
                    NotificationCenter.default.post(name: .passoShareImport, object: nil)
                }
        }
        .modelContainer(PassoApp.sharedContainer)
    }

    #if DEBUG
    private func seedPreviewDataIfNeeded() {
        let ctx = PassoApp.sharedContainer.mainContext
        // Base preview fixtures only on a fresh store.
        if (try? ctx.fetchCount(FetchDescriptor<Ticket>())) == 0 {
            for type in TicketType.allCases {
                ctx.insert(Ticket.preview(type))
            }
        }
        // UI-test hook: guarantee a deterministic expired ticket so the renewal
        // flow can be exercised regardless of prior simulator state.
        if ProcessInfo.processInfo.arguments.contains("-uitest-seed-expired") {
            let marker = "已过期电影票"
            let existing = (try? ctx.fetchCount(
                FetchDescriptor<Ticket>(predicate: #Predicate { $0.title == marker })
            )) ?? 0
            if existing == 0 {
                let expired = Ticket.preview(.movie)
                expired.title = marker
                expired.eventDate = Date(timeIntervalSinceNow: -2 * 86_400)
                expired.expiresAt = Date(timeIntervalSinceNow: -86_400)
                ctx.insert(expired)
            }
        }
        try? ctx.save()
    }
    #endif
}
