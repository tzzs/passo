# Passo Achievements System Design

Date: 2026-06-05
Status: Approved for planning

## Goal

Add a lightweight achievements system that improves engagement without turning Passo into a game-first app.

The first version should serve two product goals:

- Encourage complete use of Passo's core workflow: import, Wallet add, reminders, use, archive, and card creation.
- Make long-term ticket and card collection feel cumulative and worth revisiting.

The achievements system is not designed as a Pro conversion mechanic in the first version. Pro-related ideas can be revisited later, but first-version achievements must not gate app functionality or make free users feel penalized.

## Chosen Direction

Use a lightweight combination of:

- A Settings entry that opens an achievement center.
- A non-blocking unlock banner after important actions.

The implementation should use an event-driven model from the start. This is more work than a pure computed-statistics approach, but it avoids a painful migration when achievements later need iCloud sync, cross-device consistency, and richer long-term history.

## Architecture

### `AchievementEvent`

`AchievementEvent` is a local persisted record of achievement-relevant product behavior.

Suggested fields:

- `id: UUID`
- `kindRaw: String`
- `ticketID: UUID?`
- `ticketTypeRaw: String?`
- `createdAt: Date`
- `sourceRaw: String`
- `metadataJSON: String`

Suggested event kinds:

- `ticketImported`
- `cardCreated`
- `walletAdded`
- `reminderSet`
- `ticketUsed`
- `ticketArchived`

Suggested sources:

- `live`
- `backfill`

The event model should record only Passo-owned local product behavior. It must not become a general analytics or marketing attribution system. Do not record page views, click paths, device identifiers, ad sources, or unrelated behavioral telemetry.

### `AchievementDefinition`

`AchievementDefinition` is a static rule definition, not a persisted model.

Each definition should include:

- Stable achievement ID
- Name
- Description
- Symbol or icon name
- Group
- Required threshold
- Score value
- Progress calculation rule

Definitions are code-owned in the first version. Remote-configured achievement rules are future work.

### `AchievementService`

`AchievementService` evaluates current achievements from:

- Persisted `AchievementEvent` records.
- Current `Ticket` snapshots where needed.
- Persisted display state for whether an unlock banner has already been shown.

Responsibilities:

- Backfill events from existing tickets.
- Deduplicate events.
- Calculate unlocked achievements and progress.
- Calculate user level and total score.
- Return newly unlocked, not-yet-displayed banner payloads after important actions.

SwiftUI views should not contain achievement rules directly.

## Historical Backfill

Backfill is required.

On first launch after the feature ships, or on first achievement center open, Passo should generate `source = backfill` events from existing `Ticket` data:

- Every existing ticket creates a `ticketImported` event.
- Every `.member` ticket creates a `cardCreated` event.
- Every ticket with `isAddedToWallet == true` creates a `walletAdded` event.
- Every ticket with `reminderEnabled == true` creates a `reminderSet` event.
- Every ticket with `isUsed == true` creates a `ticketUsed` event.
- Every ticket with `isArchived == true` creates a `ticketArchived` event.

Backfill must be idempotent. Running it more than once should not create duplicate events.

Backfilled unlocks should appear in the achievement center, but should not trigger unlock banners. This prevents an old user from receiving a burst of notifications on first open.

## First-Version Achievements

The first version should include 18 achievements across four groups.

### Starter

- First ticket imported.
- First membership card created.
- First ticket added to Wallet.
- First reminder set.

Purpose: encourage the user to complete Passo's core workflow.

### Collection

- 5 tickets imported.
- 20 tickets imported.
- 50 tickets imported.
- 3 membership cards collected.
- 10 membership cards collected.
- 3 ticket types collected.
- 6 ticket types collected.

Purpose: make long-term collection visible.

### Organization

- First ticket marked used.
- 5 tickets archived.
- Imports in two different calendar months.

Purpose: encourage Passo as a durable wallet, not a one-time scanner.

### Scenario

- First movie ticket.
- First concert ticket.
- First train ticket.
- First scenic ticket.

Purpose: make Passo's ticket type system feel meaningful.

If implementation needs to reduce first-version scope, keep Starter and Collection first. Scenario achievements are lowest-risk and useful, but less important than the core workflow achievements.

## Level Rules

Add a simple score-based level system in the achievement center.

Levels:

- Lv.1: 新手票夹, 0 points
- Lv.2: 票据管家, 30 points
- Lv.3: 城市收藏家, 80 points
- Lv.4: 出行策展人, 150 points
- Lv.5: Passo 大师, 260 points

Achievement score values should use three tiers:

- 10 points for starter and single-action achievements.
- 20 points for medium collection and organization achievements.
- 40 points for high-threshold collection achievements.

Levels must not unlock Pro features or gate product functionality. They are status and progress only.

## UI

### Settings Entry

Add an Achievements row to `SettingsView`.

The row should show:

- Current level.
- Unlocked count, for example `6 / 18`.
- Most recently unlocked achievement when available.

### Achievement Center

Add `AchievementCenterView`.

Top section:

- Level title.
- Score progress toward the next level.
- Unlocked achievement count.

Content sections:

- 起步
- 收藏
- 整理
- 场景

Each achievement row should show:

- Icon or symbol.
- Name.
- Description.
- Current progress.
- Locked or unlocked state.

The first version should not include hidden achievements.

### Unlock Banner

After important actions, show a lightweight banner if new live achievements unlock.

Examples:

- `解锁成就：首次添加到 Wallet`
- `解锁 3 个新成就`

The banner should:

- Not block the current flow.
- Auto-dismiss.
- Allow tapping into the achievement center if practical.
- Show only for live unlocks, not backfilled unlocks.

## Event Write Points

First-version live events should be emitted after successful business actions:

- Ticket saved from import or manual creation.
- Card saved as `.member`.
- Wallet add succeeds.
- Reminder is enabled.
- Ticket is marked used.
- Ticket is manually archived.

Event write failure must not roll back the primary action. If ticket save succeeds but achievement event save fails, the user should not lose the ticket. Backfill and later evaluation can recover many missing events from the ticket snapshot.

## Deduplication

Deduplication is required.

For per-ticket events, the same `kind + ticketID` should only be recorded once. This prevents repeated Wallet checks or repeated edits from awarding the same achievement again.

For aggregate events, achievement rules should count distinct events or distinct ticket IDs depending on the rule.

Deleting a ticket should not delete historical achievement events. Long-term achievements and level score should not go backward after cleanup. Current inventory progress can still show current counts where useful.

## Local First, iCloud Before Launch

The first implementation may persist achievement events locally.

Before launch, achievements must be revisited as part of the iCloud sync work. `AchievementEvent` and unlock-display state need a final sync strategy alongside the existing SwiftData CloudKit decision.

This is required because the current app configuration uses `ModelConfiguration(... cloudKitDatabase: .none)`. The achievement feature must not be documented or marketed as cross-device until CloudKit behavior is verified.

Launch-readiness tasks:

- Decide whether `AchievementEvent` syncs through SwiftData CloudKit.
- Verify CloudKit compatibility for event fields, especially `metadataJSON`.
- Verify backfill idempotency across devices.
- Decide how unlock-banner display state behaves across devices.
- Add or update tests for synced event duplication.

## Testing

### Unit Tests

Cover `AchievementService` behavior:

- Event deduplication.
- Historical backfill from existing tickets.
- All first-version achievement rules.
- Level score and level thresholds.
- Multiple achievements unlocking from one action.
- Deleting tickets does not reduce historical level score.

### Model Tests

Cover:

- `AchievementEvent` defaults.
- Event kind raw-value round trips.
- Metadata JSON decoding fallback.
- Same ticket and same kind deduplication.

### UI Tests

Keep UI tests focused:

- Settings can navigate to the achievement center.
- Achievement center shows current level.
- Achievement center shows at least one achievement group.
- A manual create or import flow can produce a lightweight unlock banner once.

## Future Work

These items are explicitly not part of the first implementation, but should remain in the long-term roadmap.

### Social And Sharing

- Leaderboards.
- Social achievement sharing.
- Achievement poster generation.

These should be evaluated carefully because public comparison can conflict with Passo's private wallet positioning.

### Recurring Tasks

- Daily tasks.
- Check-in streaks.
- Periodic challenges.

These are lower priority because they can make a practical wallet feel noisy.

### Commercial Extensions

- Pro-only achievements.
- Pro membership identity badge.
- Subscription anniversary achievements.

These should only be considered after the base system feels valuable without purchase pressure.

### Operational Configuration

- Remote achievement rule configuration.
- Holiday or campaign-limited achievements.

These require operational discipline and should not be added before the local static rule system is stable.

### Presentation Enhancements

- Rich unlock animations.
- Full-screen celebrations.
- Annual recap animations.

Annual recap and poster-style collection summaries are the most promising visual future work because they strengthen the collection value without requiring competitive mechanics.

### Analytics

- Marketing attribution.
- Cross-channel funnels.

These are intentionally separate from first-version achievements. If added later, they should go through a privacy review and should not reuse local achievement events as a general tracking sink by default.

## Implementation Boundaries

First version does not include:

- Leaderboards.
- Social sharing.
- Daily tasks.
- Check-in streaks.
- Pro-only achievements.
- Remote-configured rules.
- Full-screen celebrations.
- Marketing attribution.

These are tracked as future work above, not forgotten scope.
