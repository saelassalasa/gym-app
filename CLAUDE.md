# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

This is an iOS app (minimum iOS 17.0) using SwiftUI and SwiftData. No external SPM dependencies.

```bash
# Generate Xcode project from project.yml (requires xcodegen)
cd GymTracker && xcodegen generate

# Open in Xcode
open GymTracker/GymTracker.xcodeproj

# Build from command line
xcodebuild -project GymTracker/GymTracker.xcodeproj -scheme GymTracker -destination 'platform=iOS Simulator,name=iPhone 16' build
```

There are no tests. No linter is configured. No CI pipeline exists.

## Architecture

**Pattern:** MVVM with Swift's `@Observable` macro and SwiftData for persistence.

**Data flow:** Views (`@Query`) → ViewModels (`@Observable`) → Models (`@Model`) → SwiftData

### Key architectural decisions

- **SwiftData over CoreData** — All five models use `@Model` with `@Relationship(deleteRule: .cascade)` for referential integrity
- **`@Observable` over `ObservableObject`** — All ViewModels use the modern observation macro
- **Singleton managers** — `CalendarManager.shared` and `ProgressionManager.shared` handle cross-cutting concerns (EventKit integration and weight progression)
- **`WorkoutManager` is NOT a singleton** — instantiated per-workout with a `ModelContext`, presented via `.fullScreenCover(item:)` using an `Identifiable` conformance
- **Isolated query subviews** — `StatsHeaderView` has its own `@Query` to prevent full dashboard repaints

### SwiftData schema

```
Exercise ←cascade— WorkoutSet —cascade→ WorkoutSession
WorkoutProgram ←cascade— WorkoutTemplate (has [Exercise] inline, not a relationship)
WorkoutSession → WorkoutTemplate (optional ref)
```

Note: `WorkoutTemplate.exercises` is a stored `[Exercise]` array, NOT a SwiftData `@Relationship`. This means exercises are duplicated per template, not shared across templates.

### Design system

All UI uses the `Wire` enum (in `BrutalistTheme.swift`):
- `Wire.Color.*` — monochrome palette (black, white, bone, gray, dark, danger)
- `Wire.Font.*` — 100% monospaced typography (mega/large/header/sub/body/caption/tiny)
- `Wire.Layout.*` — border=1, radius=0, gap=8, pad=12
- `Wire.tap()` / `Wire.heavy()` / `Wire.success()` — haptic feedback
- Reusable components: `WireButton`, `WireCell`, `WireInput`, `WireStepper`, `WireNumField`, `WireTimer`

Always use `Wire.*` tokens instead of raw SwiftUI values. Border radius is always 0. The app is dark-mode only (forced in `GymTrackerApp.swift`).

### Navigation

4-tab structure in `MainTabView`: TRAIN (Dashboard), GRID (Plan), LOG (History), STATS (Progress). Active workouts are full-screen covers, not pushed views.

### External integrations

- **EventKit** — Calendar scheduling with `[IRON]` prefix for event filtering. All EventKit logic is centralized in `CalendarManager`.
- **Gemini Vision API** — `GeminiService` (actor) parses workout images via `gemini-2.5-flash`. API key stored in `UserDefaults` under `"gemini_api_key"`.

## Project configuration

- **Bundle ID:** `saelassasolutions.GymTracker`
- **Dev Team:** `AD5DUJ7D8K`
- **XcodeGen config:** `GymTracker/project.yml`
- **Portrait only**, calendar permissions required (`NSCalendarsFullAccessUsageDescription`)
