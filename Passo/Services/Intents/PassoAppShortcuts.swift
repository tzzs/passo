import AppIntents

// MARK: - App Shortcuts

/// Auto-discovered by the system: registers Passo's App Intents with Siri,
/// Spotlight, and the Shortcuts app, along with the spoken/typed phrases that
/// invoke them. No Info.plist entry or extra target is required.
struct PassoAppShortcuts: AppShortcutsProvider {

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: NextTicketIntent(),
            phrases: [
                "我的下一张 \(.applicationName) 票",
                "下一张 \(.applicationName) 票",
                "\(.applicationName) 下一张票",
                "查看 \(.applicationName) 下一张票",
                "Next ticket in \(.applicationName)",
                "My next \(.applicationName) ticket",
                "What's my next ticket in \(.applicationName)"
            ],
            shortTitle: "下一张票",
            systemImageName: "ticket.fill"
        )
    }
}
