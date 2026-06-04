# Passo

English | [简体中文](README_CN.md)

Passo is an iPhone ticket wallet app built with SwiftUI, SwiftData, Vision, PassKit, and StoreKit 2. It keeps event tickets and long-lived membership cards in one local wallet, with import flows from camera scan, photo library, screenshots, manual entry, and the system Share Extension.

## Feature Overview

- Tickets tab: Apple Wallet-style ticket stack for event tickets, with Upcoming / All filters, search, type filters, today's ticket badge, swipe-to-mark-used, and swipe-to-delete.
- Cards tab: dedicated membership-card wallet with stacked card presentation, card-focused import entry points, expiry highlighting, and access to the shared archive.
- Archive: unified archive for expired, used, and manually archived tickets and cards, reachable from both Tickets and Cards.
- Multiple ticket types: `movie`, `concert`, `train`, `member`, `scenic`, and `generic`, each with its own theme and field layout.
- Local recognition: Vision handles barcode detection and OCR, while `TicketParser` classifies ticket type and extracts fields.
- Multiple import channels: camera scan, photo import, screenshot quick import, manual entry, and Share Extension import.
- Wallet integration: the client builds PassKit `pass.json`, sends it to a remote signing node, receives a `.pkpass`, and presents the system Wallet add-pass flow.
- Reminders and cleanup: supports ticket reminders and cleanup for expired or used tickets.
- Pro features: StoreKit 2 entitlement state is stored in `@AppStorage("isPro")` and used to gate capabilities such as iCloud sync.

## Project Structure

```text
Passo/
  Components/        # Reusable views such as GlassCardView and TicketCardView
  Models/            # SwiftData Ticket model and TicketType
  Services/          # Camera, recognition, import, signing, Wallet, StoreKit, reminders
  Theme/             # AppTheme, AppSpacing, AppAnimation, Color(hex:)
  Views/
    Detail/          # Ticket detail and Wallet actions
    Scan/            # Scanner, photo import, recognition confirmation
    Settings/        # Settings, Pro, screenshot import
    Wallet/          # Tickets, cards, and archive views
  ContentView.swift  # Tab container and import presentation coordinator
  PassoApp.swift     # App entry and SwiftData ModelContainer

PassoShareExtension/
  ShareViewController.swift

PassoTests/          # Unit tests for model, parser, quota, palette, and PassKit JSON behavior
PassoUITests/        # UI smoke tests using accessibility identifiers
Docs/                # UI and development guidelines
```

## Architecture

- `PassoApp.swift` is the app entry point. It creates the shared SwiftData `ModelContainer`, injects `StoreService`, and handles `passo://import` callbacks from the Share Extension.
- `ContentView.swift` is the root view with three tabs: Tickets, Cards, and Settings. The `+` menus present photo import, camera scan, or a blank `RecognitionConfirmView` for manual entry.
- `WalletView.swift` shows event tickets only (`!isCard && !isInArchive`) and owns the Upcoming / All segmented experience.
- `CardWalletView.swift` shows long-lived membership cards (`ticketType == .member`) in a dedicated card wallet.
- `ArchiveView.swift` is shared by ticket and card flows and groups expired, used, and manually archived items.
- The data model is centered on `Ticket`. `TicketType` is persisted through `ticketTypeRaw: String` and rehydrated through a computed property.
- `Ticket.isCard`, `Ticket.isInArchive`, `Ticket.canRestore`, and `Ticket.isExpiringSoon` drive wallet bucketing and restore behavior.
- Visual themes are driven by `TicketType.theme`; card components read `ticket.ticketType.theme` for gradients and accent colors.
- The PassKit flow is `Ticket` -> `TicketSnapshot` -> `PassBuilder.buildPassJSON(...)` -> `SigningService.sign(...)` -> `WalletPresenter`.

## Requirements

- macOS with Xcode 16 or later
- iOS 17 or later simulator / device
- SwiftUI + SwiftData project with no external package manager dependency
- XcodeGen if you need to regenerate `Passo.xcodeproj` from `project.yml`
- A valid Apple Developer signing identity for full device validation of Wallet, camera, push notifications, iCloud, and StoreKit capabilities

## Local Development

1. Open `Passo.xcodeproj` in Xcode.
2. Select the `Passo` scheme.
3. Select an iOS 17+ simulator or signed physical device.
4. Run with `⌘R`.

The checked-in Xcode project is the source used for normal development. The project is also described by `project.yml`; when changing target membership or project metadata, update `project.yml`, run `xcodegen generate`, and review the generated `Passo.xcodeproj` before committing.

For command-line validation, mirror CI as closely as possible:

```sh
plutil -lint Passo/Info.plist PassoShareExtension/Info.plist Passo/Passo.entitlements PassoShareExtension/PassoShareExtension.entitlements
xcodebuild -list -project Passo.xcodeproj
xcodebuild -quiet build -project Passo.xcodeproj -scheme Passo -configuration Debug -destination "generic/platform=iOS Simulator" CODE_SIGNING_ALLOWED=NO
xcodebuild -quiet build -project Passo.xcodeproj -scheme PassoShareExtension -configuration Debug -destination "generic/platform=iOS Simulator" CODE_SIGNING_ALLOWED=NO
```

`PassoTests` and `PassoUITests` are wired into the `Passo` scheme for local Xcode test runs. CI currently validates project metadata and builds the app plus Share Extension without signing.

## Required Configuration

Before release or full physical-device validation, confirm these settings:

- Development Team: set `DEVELOPMENT_TEAM` for app and extension targets before device builds.
- App Group: `group.com.passo.app`, used for handoff between the Share Extension and the main app.
- URL Scheme: `passo://import`, used by the Share Extension to open the main app.
- Pass Type Identifier: `pass.com.passo.ticket`.
- Pass signing nodes:
  - Domestic: `https://sign.passo.cn/api/sign`
  - Overseas: `https://passo-sign.workers.dev/api/sign`
- StoreKit products:
  - `com.passo.pro.monthly`
  - `com.passo.pro.yearly`
- iCloud sync: entitlements and UI preference exist, but `ModelConfiguration` currently uses `cloudKitDatabase: .none`; the user-facing toggle is not a live CloudKit switch yet.
- Capabilities:
  - Push Notifications
  - In-App Purchase
  - iCloud + CloudKit
  - App Groups
  - Background Modes / Location updates

## Design And Code Conventions

- Prefer `AppSpacing` and `AppAnimation` for spacing, corner radius, and animation values instead of scattering raw `CGFloat` values.
- Prefer `Color(hex: "#RRGGBB")`; ticket themes should be derived from `TicketType.theme`.
- Use `GlassCardView` for shared glass-style card surfaces.
- Use `TicketCardView` for ticket cards, choosing `.full` or `.compact` layout as needed.
- When adding a ticket type, update `TicketType`, themes, parser rules, card layout, and PassKit field mapping together.
- Keep reusable visual components in `Passo/Components/`, app/system integrations in `Passo/Services/`, and page-level composition in `Passo/Views/`.
- Create a `TicketSnapshot` before moving ticket data across actor or concurrency boundaries.
- UI-affecting async results should return to `MainActor`.

## Known Follow-Ups

- Deploy the remote Pass signing service and connect real certificates.
- Create the CloudKit container and App Store Connect subscription products in Apple developer services.
- Validate Wallet open / handoff behavior on a physical device.
- Verify Share Extension embedding, iCloud sync behavior, and pass signing end to end on a physical device.
- Replace placeholder Pro upgrade content once App Store Connect products exist.

## Pull Request Checklist

- Summarize user-facing behavior changes and any configuration impact.
- Mention the exact validation performed, or explain why a check was not run.
- Include screenshots or screen recordings for visible UI changes.
- Keep docs in sync when tab structure, import flow, capabilities, or signing behavior changes.

## Commit Messages

Commit messages follow Conventional Commits 1.0.0:

```text
<type>[optional scope]: <description>
```

Common types: `feat`, `fix`, `refactor`, `style`, `perf`, `docs`, `test`, `chore`.

Common scopes: `model`, `wallet`, `scan`, `detail`, `settings`, `theme`, `passkit`, `docs`.

Examples:

```text
docs: expand project README
feat(scan): add torch toggle
fix(passkit): preserve barcode format when signing pass
feat(passkit)!: replace stub signing
```
