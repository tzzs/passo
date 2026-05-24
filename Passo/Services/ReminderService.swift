import UserNotifications
import CoreLocation
import Foundation

// MARK: - Reminder Service

/// Schedules and cancels local notifications for Ticket events.
/// Accepts TicketSnapshot (Sendable) to safely cross actor boundaries in Swift 6.
enum ReminderService {

    // MARK: - Public API

    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .authorized { return true }
        return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    // MARK: - Location Authorization

    private static func requestLocationAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            let delegate = LocationAuthDelegate(continuation: continuation)
            // Store delegate so it isn't deallocated before callback fires
            LocationAuthDelegate.activeDelegate = delegate
            let manager = CLLocationManager()
            manager.delegate = delegate
            let status = manager.authorizationStatus
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                LocationAuthDelegate.activeDelegate = nil
                continuation.resume(returning: true)
            case .notDetermined:
                manager.requestWhenInUseAuthorization()
                // delegate fires didChangeAuthorization
            default:
                LocationAuthDelegate.activeDelegate = nil
                continuation.resume(returning: false)
            }
        }
    }

    @discardableResult
    static func scheduleReminder(snapshot: TicketSnapshot, ticketID: UUID) async -> Date? {
        guard !snapshot.isUsed else { return nil }
        guard await requestAuthorization() else { return nil }
        guard let fireDate = reminderDate(for: snapshot) else { return nil }
        guard fireDate > Date() else { return nil }

        let content = UNMutableNotificationContent()
        content.title = snapshot.title.isEmpty ? "票据提醒" : snapshot.title
        content.subtitle = snapshot.venue
        content.body = notificationBody(for: snapshot, fireDate: fireDate)
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: ticketID.uuidString,
            content: content,
            trigger: trigger
        )

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [ticketID.uuidString])
        try? await center.add(request)
        return fireDate
    }

    static func scheduleLocationReminder(snapshot: TicketSnapshot, ticketID: UUID) async {
        guard let lat = snapshot.latitude, let lon = snapshot.longitude else { return }
        guard await requestAuthorization() else { return }
        guard await requestLocationAuthorization() else { return }

        let content = UNMutableNotificationContent()
        content.title = snapshot.title.isEmpty ? "附近有你的票据" : snapshot.title
        content.subtitle = snapshot.venue
        content.body = "你已到达场馆附近，点击查看票据"
        content.sound = .default

        let region = CLCircularRegion(
            center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            radius: 200,
            identifier: "location-\(ticketID.uuidString)"
        )
        region.notifyOnEntry = true
        region.notifyOnExit  = false

        let trigger = UNLocationNotificationTrigger(region: region, repeats: false)
        let request = UNNotificationRequest(
            identifier: "location-\(ticketID.uuidString)",
            content: content,
            trigger: trigger
        )

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["location-\(ticketID.uuidString)"])
        try? await center.add(request)
    }

    static func cancelReminder(ticketID: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [ticketID.uuidString, "location-\(ticketID.uuidString)"]
        )
    }

    // MARK: - Lead Time Rules (per spec §4.4)

    static func reminderDate(for snapshot: TicketSnapshot) -> Date? {
        switch snapshot.ticketType {
        case .movie:
            guard let date = snapshot.eventDate else { return nil }
            return Calendar.current.date(byAdding: .minute, value: -30, to: date)
        case .concert:
            guard let date = snapshot.eventDate else { return nil }
            return Calendar.current.date(byAdding: .hour, value: -2, to: date)
        case .train:
            guard let date = snapshot.eventDate else { return nil }
            return Calendar.current.date(byAdding: .minute, value: -30, to: date)
        case .scenic:
            guard let date = snapshot.eventDate else { return nil }
            return Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: date)
        case .member:
            guard let exp = snapshot.expiresAt else { return nil }
            return Calendar.current.date(byAdding: .day, value: -7, to: exp)
        case .generic:
            let base = snapshot.eventDate ?? snapshot.expiresAt
            guard let base else { return nil }
            return Calendar.current.date(byAdding: .hour, value: -24, to: base)
        }
    }

    // MARK: - Helpers

    private static func notificationBody(for snapshot: TicketSnapshot, fireDate: Date) -> String {
        switch snapshot.ticketType {
        case .movie:
            return "30 分钟后开始放映，记得提前入场"
        case .concert:
            let time = snapshot.eventTime.isEmpty ? "" : "（\(snapshot.eventTime) 开演）"
            return "演出\(time)2 小时后开始，建议现在出发"
        case .train:
            let route = [snapshot.routeOrigin, snapshot.routeDestination]
                .filter { !$0.isEmpty }.joined(separator: " → ")
            return route.isEmpty ? "30 分钟后检票，请做好准备" : "\(route) · 30 分钟后检票"
        case .scenic:
            return snapshot.admissionWindow.isEmpty
                ? "今天是你的游览日，别忘带上票据"
                : "入场时段：\(snapshot.admissionWindow)"
        case .member:
            return "会员卡即将到期，请及时续费"
        case .generic:
            return "票据即将到期"
        }
    }
}

// MARK: - Location Auth Delegate

// Helper that bridges CLLocationManagerDelegate callback into async/await.
// Retained via a static slot so it isn't deallocated before the delegate fires.
private final class LocationAuthDelegate: NSObject, CLLocationManagerDelegate {

    nonisolated(unsafe) static var activeDelegate: LocationAuthDelegate?

    private let continuation: CheckedContinuation<Bool, Never>
    private var resumed = false

    init(continuation: CheckedContinuation<Bool, Never>) {
        self.continuation = continuation
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard !resumed else { return }
        resumed = true
        Self.activeDelegate = nil
        let granted = manager.authorizationStatus == .authorizedWhenInUse
                   || manager.authorizationStatus == .authorizedAlways
        continuation.resume(returning: granted)
    }
}
