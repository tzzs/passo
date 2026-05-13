# AGENTS.md

## Build & Run

- Xcode-only: open `Passo.xcodeproj` in Xcode 16+, iOS 17+ simulator/device, ⌘R
- No CLI build, no package dependencies, no CI, no tests
- Portrait-only, no multiple scenes
- Physical device requires Apple Developer signing identity

## Architecture

- **Entry**: `PassoApp.swift` — injects SwiftData `ModelContainer` for `Ticket`, shows `ContentView`
- **Tabs** (`ContentView.swift`): wallet → scan (trigger only, see below) → settings
- **Scan tab is a trigger, not a destination**: tapping it sets `selectedTab` back to `.wallet` and presents `ScanView` as `.fullScreenCover`. There is no view bound to the scan tab.
- **Single model** `Ticket` (`Models/Ticket.swift`): `@Model` class. `TicketType` persists as `ticketTypeRaw: String`; computed `ticketType: TicketType` re-hydrates from rawValue.
- **No multi-module**: everything lives in the `Passo/` directory

## Design Token Convention

Always use `AppSpacing` and `AppAnimation` design tokens instead of raw `CGFloat` literals:

```swift
AppSpacing.xs / .sm / .md / .lg / .xl
AppSpacing.radiusCard / .radiusButton / .radiusTag
AppAnimation.themeChange / .cardFlip / .cardAppear / .scanPulse
```

`Color(hex:)` is defined in `Theme/AppTheme.swift`. Prefer `Color(hex: "#RRGGBB")`.

## Theme System

`TicketType` enum → `.theme` → `TicketTheme` (backgroundStart/End gradient, accent/accentSecondary). Each ticket type gets a distinct color palette. Wire `ticket.ticketType.theme` into card views.

## Component Patterns

- `GlassCardView` — glassmorphism wrapper (.ultraThinMaterial, highlight stroke, multi-layer shadow). Takes `isDark: Bool` and optional `glowColor`.
- `TicketCardView` — renders `.full` (with barcode) or `.compact` (without). Derives theme from `ticket.ticketType.theme`.

## Key Stubs (known unimplemented areas)

- `ScanView` camera: needs `UIViewRepresentable` wrapping `AVCaptureVideoPreviewLayer` + Vision barcode detection + torch toggle
- `RecognitionConfirmView.addToWallet()`: needs PassKit `.pkpass` generation + server-side certificate signing
- `PassDetailView` Wallet button: needs `passTypeIdentifier://` URL scheme

## Persisted State

- `@AppStorage("isPro")` — single source of truth for Pro gating (iCloud sync, unlimited imports, LLM classification)
- `@AppStorage("signingNodePreference")` — domestic vs overseas signing node

## Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/). Format: `<type>[optional scope]: <description>`

Types: `feat`, `fix`, `refactor`, `style`, `perf`, `docs`, `test`, `chore`
Scopes: `model`, `wallet`, `scan`, `detail`, `settings`, `theme`, `passkit`

Append `!` after type/scope for breaking changes, e.g. `feat(passkit)!: replace stub signing`.
