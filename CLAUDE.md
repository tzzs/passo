# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

Open `Passo.xcodeproj` in Xcode 16+, select an iOS 17+ simulator or device, and press ⌘R.

There are no external package dependencies, build scripts, or CI pipelines. All compilation happens inside Xcode. The app is portrait-only and does not support multiple scenes.

To run on a physical device, a valid Apple Developer signing identity must be set in the project's Signing & Capabilities tab.

## Architecture

**Entry point**: `PassoApp.swift` — wires the SwiftData `ModelContainer` for `Ticket` and presents `ContentView`.

**Tab structure** (`ContentView.swift`) — three tabs (`AppTab`):
- `WalletView` (票据) — event tickets, with an in-tab 即将 / 全部 segmented control. 全部 mode adds a search field + per-type filter chips. Excludes cards (`isCard`) and archived items.
- `CardWalletView` (卡包) — long-lived membership cards (`ticketType == .member`). Grid layout, no timeline.
- `SettingsView` (设置).
- Imports launch from a `+` menu (从相册导入 / 扫描条码 / 手动新建) in the Wallet/Card headers, presenting `PhotoImportView` (sheet), `ScanView` (fullScreenCover), or an empty-`Ticket` `RecognitionConfirmView`. `ContentView` threads `importPreferredType` so card-wallet imports default an unrecognized result to `.member`.
- `ArchiveView` (已归档) — unified archive for expired/used/manually-archived tickets AND cards, reachable from both the Wallet and Card tabs.

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

**Scan / import flow**:
1. `ScanView` — live `AVCaptureVideoPreviewLayer` preview (`CameraService`), torch toggle, Vision barcode metadata + throttled OCR, animated scan line, bottom result sheet. Also has an album-import entry.
2. `PhotoImportView` / `ScreenshotImportView` — pick or scan recent screenshots; `TicketParser.analyzeImage` runs barcode + OCR.
3. `RecognitionConfirmView` — editable field list confirming parsed data. `mode: .confirm` shows 添加到 Wallet + 仅保存到票夹 (free-quota + duplicate gated); `mode: .edit` shows a single 保存 for editing an already-saved ticket. Signing failures offer 仅保存 / 重试.

**Client pipeline is fully implemented** — `CameraService` (preview/torch/Vision), `TicketParser` (classify + field extraction; OCR text is newline-joined so `extractTitle` works), `PassBuilder` (pass.json with per-type colors, `transitType` for boarding passes, single legacy `barcode` dict), `SigningService` (POST pass.json → signed `.pkpass`, node failover), and `WalletPresenter` (`PKAddPassesViewController`). `PassDetailView` can re-generate a Wallet pass for a save-only ticket.

## Remaining Stubs / External Dependencies

The client is complete; what's left needs external resources (see `plan.md` 批次 4):

| Area | What's missing |
|---|---|
| Signing nodes (`SigningService`) | The two endpoints (`sign.passo.cn`, `passo-sign.workers.dev`) are placeholders — no server deployed yet |
| Team ID / Pass Type ID | `SigningService.teamIdentifier` reads an Info.plist key that Xcode doesn't auto-inject; needs build-setting config |
| `ProUpgradeSheet` | Upgrade UI is a placeholder; App Store Connect products not created |
| Share Extension embed | `PassoShareExtension` may not embed in the main app's PlugIns (verify `project.yml`) |
| iCloud sync | `ModelConfiguration` is fixed at `cloudKitDatabase: .none`; the settings toggle is currently inert |

## Signing Nodes

Pass signing requires a remote server. `NodePreference` (`SettingsView.swift`) lets the user choose between domestic and overseas (Cloudflare) nodes. The selection is persisted via `@AppStorage("signingNodePreference")`.

## Pro Gating

`@AppStorage("isPro")` is the single source of truth for Pro status, synced from `StoreService` (StoreKit 2). Free tier allows 5 imports/calendar-month — centralized in `StoreService.remainingFreeImports(isPro:tickets:)` / `isAtFreeImportLimit(...)`; all import entry points call it. The upgrade sheet is `ProUpgradeSheet` (currently a placeholder).

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