import SwiftUI
import SwiftData

@main
struct PassoApp: App {
    @AppStorage("isPro") private var isPro = false

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(appContainer)
    }

    /// Use CloudKit-backed store for Pro users; local-only store for free tier.
    /// SwiftData + CloudKit requires the iCloud + CloudKit capability in Xcode
    /// Signing & Capabilities, and NSUbiquitousContainers in Info.plist.
    private var appContainer: ModelContainer {
        let schema = Schema([Ticket.self])

        // CloudKit sync: enabled for Pro users when the capability is provisioned.
        // Falls back to local store if CloudKit is unavailable (simulator, no entitlement).
        if isPro, let container = try? ModelContainer(
            for: schema,
            configurations: ModelConfiguration(
                schema: schema,
                cloudKitDatabase: .automatic
            )
        ) {
            return container
        }

        // Free tier or CloudKit unavailable → local store
        return try! ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema)
        )
    }
}
