# AGENTS.md

Repository guidance for agents and coding assistants working on Passo.

## Build & Run

- Xcode-only: open `Passo.xcodeproj` in Xcode 16+, select an iOS 17+ simulator/device, then press `⌘R`.
- No supported CLI build/test command, package dependency workflow, or CI pipeline.
- Portrait-only, single scene.
- Physical device runs require a valid Apple Developer signing identity in Signing & Capabilities.

## Architecture

- **Entry**: `PassoApp.swift` creates the shared SwiftData `ModelContainer` for `Ticket`, injects `StoreService.shared`, handles `passo://import`, and shows `ContentView`.
- **Tabs** (`ContentView.swift`): wallet -> scan trigger -> settings.
- **Scan tab is a trigger, not a destination**: tapping it sets `selectedTab` back to `.wallet` and presents `ScanView` as `.fullScreenCover`. There is no view bound to the scan tab.
- **Single model** (`Models/Ticket.swift`): `Ticket` is the only SwiftData `@Model`. `TicketType` persists as `ticketTypeRaw: String`; computed `ticketType` rehydrates from `rawValue`.
- **Default expiry rules** live in `Ticket.defaultExpiry(for:eventDate:)`.
- **No multi-module app code**: app source lives under `Passo/`; the share extension lives under `PassoShareExtension/`.

## Directory Responsibilities

- `Passo/Components/`: reusable SwiftUI components only; do not place persistence, network, StoreKit, or camera flow logic here.
- `Passo/Models/`: SwiftData model, ticket type enum, model convenience logic.
- `Passo/Services/`: system integrations and async flows such as camera, OCR parsing, share import, pass signing, Wallet presentation, StoreKit, and reminders.
- `Passo/Theme/`: design tokens, themes, and `Color(hex:)`.
- `Passo/Views/`: page-level SwiftUI views grouped by feature area.

## Design Token Convention

Always use `AppSpacing` and `AppAnimation` design tokens instead of raw `CGFloat` literals when an existing token fits:

```swift
AppSpacing.xs / .sm / .md / .lg / .xl
AppSpacing.radiusCard / .radiusButton / .radiusTag
AppAnimation.themeChange / .cardFlip / .cardAppear / .scanPulse
```

`Color(hex:)` is defined in `Theme/AppTheme.swift`. Prefer `Color(hex: "#RRGGBB")` for custom colors.

## Theme System

`TicketType` -> `.theme` -> `TicketTheme` (`backgroundStart`, `backgroundEnd`, `accent`, `accentSecondary`).

Each ticket type must have a distinct color palette. Wire `ticket.ticketType.theme` into card views, scan accents, detail headers, and related highlighted states. Do not redefine per-type colors in feature views.

## Component Patterns

- `GlassCardView`: glassmorphism container using `.ultraThinMaterial`, highlight stroke, and multi-layer shadow. Takes `isDark`, optional `glowColor`, and `useStaticBackground` for 3D/offscreen rendering cases.
- `TicketCardView`: primary ticket card. Renders `.full` with barcode or `.compact` without barcode. Derives theme from `ticket.ticketType.theme`.
- `GlassPillButton`: 44pt circular icon button for navigation and compact commands.
- `GlassSegmentedControl`: glass-style segmented control for small mutually exclusive filters.
- `TicketTypeBadge`: small type chip using `TicketType.displayName`, `emoji`, and theme accent.

## Scan And Import Flow

1. `ScanView` owns the full-screen camera UI.
2. `CameraService` manages `AVCaptureSession`, `AVCaptureVideoPreviewLayer`, torch, barcode detection, and throttled OCR.
3. `TicketParser.parse(barcodeValue:ocrText:)` creates a best-effort `Ticket`.
4. `RecognitionConfirmView` lets the user edit fields before persistence and Wallet signing.
5. Share Extension import writes an App Group payload, opens `passo://import`, and lets the main app consume the payload through `ShareImportService`.

Parsing must be local, deterministic, and non-throwing. Worst case should produce an editable `.generic` ticket.

## PassKit And Signing

Pass signing requires a remote server. `NodePreference` is persisted via `@AppStorage("signingNodePreference")`.

Known endpoints:

- Domestic: `https://sign.passo.cn/api/sign`
- Overseas / Cloudflare: `https://passo-sign.workers.dev/api/sign`

Client responsibilities:

- Build `pass.json` through `PassBuilder`.
- Send a `TicketSnapshot` to `SigningService`.
- Present the returned `.pkpass` through `WalletPresenter`.

Server responsibilities:

- Add pass assets.
- Generate `manifest.json`.
- Sign with certificate/private key.
- Return a valid `.pkpass`.

Never place Pass certificates, `.p12` files, private keys, or signing passwords in the iOS app bundle or repository.

## Persisted State

- `@AppStorage("isPro")`: single source of truth for Pro gating such as iCloud sync, unlimited imports, and LLM classification.
- `@AppStorage("signingNodePreference")`: preferred signing node.
- `@AppStorage("iCloudSyncEnabled")`: user-facing iCloud sync preference.

`StoreService` is the StoreKit 2 entitlement source and syncs Pro status back to `UserDefaults`.

## Development Guidelines

- Keep system framework details in `Services/`; keep page composition in `Views/`.
- Use `@State` for local UI state, `@Query` for SwiftData lists, `@Bindable` when editing a `Ticket`, and `@EnvironmentObject` for shared app services.
- Create a `TicketSnapshot` before passing ticket data across actor/concurrency boundaries.
- UI-affecting async results must return to `MainActor`.
- Deletions and destructive cleanup require confirmation dialogs.
- Icon-only buttons need a clear accessible meaning and a 44pt hit target.
- When adding a ticket type, update `TicketType`, theme, preview fixture, parser classification/extraction, `TicketCardView`, and `PassBuilder` together.

See `Docs/UI-Design-Spec.md` and `Docs/Code-Development-Guidelines.md` for the fuller project conventions.

## Commit Messages

Follow [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/).

Format:

```text
<type>[optional scope]: <description>
```

Types:

- `feat`: new feature
- `fix`: bug fix
- `refactor`: code change that neither fixes a bug nor adds a feature
- `style`: formatting or whitespace only
- `perf`: performance improvement
- `docs`: documentation only
- `test`: adding or fixing tests
- `chore`: build process, tooling, dependency, or maintenance work

Scopes: `model`, `wallet`, `scan`, `detail`, `settings`, `theme`, `passkit`, `docs`.

Breaking changes: append `!` after type/scope, e.g. `feat(passkit)!: replace stub signing`.

Examples:

```text
feat(scan): integrate AVCaptureVideoPreviewLayer for live camera
fix(wallet): restore top card offset after incomplete swipe
refactor(theme): extract TicketTheme into separate file
docs: add UI and development guidelines
feat(passkit)!: replace stub signing with server-side PKPass generation
```
