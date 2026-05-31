# Passo

English | [简体中文](README_CN.md)

Passo is an iPhone ticket wallet app built with SwiftUI, SwiftData, Vision, PassKit, and StoreKit 2. It brings movie tickets, concert tickets, train tickets, scenic-area tickets, membership cards, and generic passes into one local wallet, with import flows from camera scan, photo library, screenshots, and the system Share Extension.

## Feature Overview

- Wallet home: Apple Wallet-style ticket stack with Upcoming / All filters, today's ticket badge, swipe-to-mark-used, and swipe-to-delete.
- Multiple ticket types: `movie`, `concert`, `train`, `member`, `scenic`, and `generic`, each with its own theme and field layout.
- Local recognition: Vision handles barcode detection and OCR, while `TicketParser` classifies ticket type and extracts fields.
- Multiple import channels: camera scan, photo import, screenshot quick import, and Share Extension import.
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
    Wallet/          # Wallet home
  ContentView.swift  # Tab container; the scan tab is a trigger only
  PassoApp.swift     # App entry and SwiftData ModelContainer

PassoShareExtension/
  ShareViewController.swift
```

## Architecture

- `PassoApp.swift` is the app entry point. It creates the shared SwiftData `ModelContainer`, injects `StoreService`, and handles `passo://import` callbacks from the Share Extension.
- `ContentView.swift` is the root view with three tabs: wallet, scan, and settings. The scan tab has no destination view; tapping it immediately switches back to the wallet tab and opens `ScanView` as a `.fullScreenCover`.
- The data model is centered on `Ticket`. `TicketType` is persisted through `ticketTypeRaw: String` and rehydrated through a computed property.
- Visual themes are driven by `TicketType.theme`; card components read `ticket.ticketType.theme` for gradients and accent colors.
- The PassKit flow is `Ticket` -> `TicketSnapshot` -> `PassBuilder.buildPassJSON(...)` -> `SigningService.sign(...)` -> `WalletPresenter`.

## Requirements

- macOS with Xcode 16 or later
- iOS 17 or later simulator / device
- SwiftUI + SwiftData project with no external package manager dependency
- A valid Apple Developer signing identity for full device validation of Wallet, camera, push notifications, iCloud, and StoreKit capabilities

## Local Development

1. Open `Passo.xcodeproj` in Xcode.
2. Select the `Passo` scheme.
3. Select an iOS 17+ simulator or signed physical device.
4. Run with `⌘R`.

This repository currently maintains an Xcode-only workflow: there is no supported CLI build/test command, package dependency workflow, CI setup, or automated test target.

## Required Configuration

Before release or full physical-device validation, confirm these settings:

- App Group: `group.com.passo.app`, used for handoff between the Share Extension and the main app.
- URL Scheme: `passo://import`, used by the Share Extension to open the main app.
- Pass Type Identifier: `pass.com.passo.ticket`.
- Pass signing nodes:
  - Domestic: `https://sign.passo.cn/api/sign`
  - Overseas: `https://passo-sign.workers.dev/api/sign`
- StoreKit products:
  - `com.passo.pro.monthly`
  - `com.passo.pro.yearly`
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

## Known Follow-Ups

- Deploy the remote Pass signing service and connect real certificates.
- Create the CloudKit container and App Store Connect subscription products in Apple developer services.
- Validate Wallet open / handoff behavior on a physical device.
- Add UI automation tests and CLI CI if the project starts maintaining a command-line workflow.

## Commit Messages

Commit messages follow Conventional Commits 1.0.0:

```text
<type>[optional scope]: <description>
```

Common types: `feat`, `fix`, `refactor`, `style`, `perf`, `docs`, `test`, `chore`.

Common scopes: `model`, `wallet`, `scan`, `detail`, `settings`, `theme`, `passkit`.

Examples:

```text
docs: expand project README
feat(scan): add torch toggle
fix(passkit): preserve barcode format when signing pass
feat(passkit)!: replace stub signing
```
