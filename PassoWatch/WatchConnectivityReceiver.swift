import Foundation
import WatchConnectivity

/// Receives ticket snapshots pushed from the iPhone over WatchConnectivity and
/// publishes them to the SwiftUI layer.
///
/// The phone sends `[TicketDTO]` via `updateApplicationContext` (latest state
/// wins, coalesced by the system) and may also use `transferUserInfo` (queued,
/// guaranteed delivery). Both arrive here and update `tickets`. The most recent
/// payload is cached in `UserDefaults` so the list survives an app relaunch
/// before the phone has a chance to re-send.
@MainActor
final class WatchConnectivityReceiver: NSObject, ObservableObject {

    @Published private(set) var tickets: [TicketDTO] = []

    private let cacheKey = "cachedTicketDTOs"

    override init() {
        super.init()
        loadCache()
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    // MARK: Payload handling

    /// The wire payload stores the encoded DTO array under this key.
    static let payloadKey = "tickets"

    private func apply(_ context: [String: Any]) {
        guard let data = context[Self.payloadKey] as? Data else { return }
        guard let decoded = try? JSONDecoder().decode([TicketDTO].self, from: data) else { return }
        tickets = decoded
        UserDefaults.standard.set(data, forKey: cacheKey)
    }

    private func loadCache() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let decoded = try? JSONDecoder().decode([TicketDTO].self, from: data) else { return }
        tickets = decoded
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityReceiver: WCSessionDelegate {
    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {
        // On activation, surface whatever application context the phone last set.
        let context = session.receivedApplicationContext
        Task { @MainActor in self.apply(context) }
    }

    nonisolated func session(_ session: WCSession,
                             didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in self.apply(applicationContext) }
    }

    nonisolated func session(_ session: WCSession,
                             didReceiveUserInfo userInfo: [String: Any]) {
        Task { @MainActor in self.apply(userInfo) }
    }
}
