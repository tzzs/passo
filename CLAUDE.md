# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

Open `Passo.xcodeproj` in Xcode 16+, select an iOS 17+ simulator or device, and press ⌘R.

There are no external package dependencies, build scripts, or CI pipelines. All compilation happens inside Xcode. The app is portrait-only and does not support multiple scenes.

To run on a physical device, a valid Apple Developer signing identity must be set in the project's Signing & Capabilities tab.

## Architecture

**Entry point**: `PassoApp.swift` — wires the SwiftData `ModelContainer` for `Ticket` and presents `ContentView`.

**Tab structure** (`ContentView.swift`):
- `WalletView` (票夹) — home screen, always the active destination
- Scan tab — a *trigger*, not a destination: tapping it sets `selectedTab` back to `.wallet` and presents `ScanView` as a `fullScreenCover`. There is no view bound to the scan tab itself.
- `SettingsView` (设置)

**Data model** (`Models/Ticket.swift`):
- Single SwiftData `@Model` class `Ticket`. `TicketType` is persisted as its `rawValue` string via `ticketTypeRaw`; the computed `ticketType` property re-hydrates it.
- Default expiry rules per type live in `Ticket.defaultExpiry(for:eventDate:)`.

**Theme system** (`Theme/AppTheme.swift`):
- `TicketType` → `TicketTheme` — each ticket type has a `backgroundStart/End` gradient and `accent/accentSecondary` colors.
- `AppSpacing` and `AppAnimation` are the project-wide design token namespaces. Always prefer these over raw `CGFloat` literals.
- `Color(hex:)` extension is defined here.

**Component library** (`Components/`):
- `GlassCardView` — base glassmorphism container (`.ultraThinMaterial` + highlight stroke + multi-layer shadow). Accepts `isDark` and an optional `glowColor` for the colored shadow.
- `TicketCardView` — primary ticket card; renders in `.full` (with barcode) or `.compact` (without barcode) size. Drives its theme from `ticket.ticketType.theme`.
- `GlassPillButton`, `GlassSegmentedControl`, `TicketTypeBadge` — shared UI atoms.

**Scan flow**:
1. `ScanView` — camera region (currently a placeholder gradient; production needs `AVCaptureVideoPreviewLayer`) + animated scan line + bottom result sheet.
2. `RecognitionConfirmView` — editable field list where the user confirms OCR-extracted data before saving. Calls `addToWallet()` which stubs PassKit signing.

## Key Stubs (not yet implemented)

| Location | What's missing |
|---|---|
| `ScanView` camera region | `UIViewRepresentable` wrapping `AVCaptureVideoPreviewLayer` |
| `ScanView` flash button | `AVCaptureDevice` torch toggle |
| `ScanView` detection | Vision framework barcode/QR reading |
| `RecognitionConfirmView.addToWallet()` | PassKit `.pkpass` generation + server-side certificate signing |
| `PassDetailView` open Wallet button | `passTypeIdentifier://` URL scheme |

## Signing Nodes

Pass signing requires a remote server. `NodePreference` (`SettingsView.swift`) lets the user choose between domestic and overseas (Cloudflare) nodes. The selection is persisted via `@AppStorage("signingNodePreference")`.

## Pro Gating

`@AppStorage("isPro")` is the single source of truth for Pro status. Features gated behind it: iCloud sync, unlimited imports, LLM classification. The upgrade sheet is `ProUpgradeView` (currently a placeholder).

## Git Commit Messages

This project follows [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/).

**Format**: `<type>[optional scope]: <description>`

**Types**:
- `feat` — new feature
- `fix` — bug fix
- `refactor` — code change that neither fixes a bug nor adds a feature
- `style` — formatting, whitespace (no logic change)
- `perf` — performance improvement
- `docs` — documentation only
- `test` — adding or fixing tests
- `chore` — build process, tooling, dependency updates

**Scope** (optional, use the affected layer): `model`, `wallet`, `scan`, `detail`, `settings`, `theme`, `passkit`

**Breaking changes**: append `!` after the type/scope, e.g. `feat(model)!: rename barcodeFormat field`.

Examples:
```
feat(scan): integrate AVCaptureVideoPreviewLayer for live camera
fix(wallet): restore top card offset after incomplete swipe
refactor(theme): extract TicketTheme into separate file
feat(passkit)!: replace stub signing with server-side PKPass generation
```