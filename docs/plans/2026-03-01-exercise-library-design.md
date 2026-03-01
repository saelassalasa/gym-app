# Built-in Exercise Library — Design

**Date:** 2026-03-01
**Goal:** Provide a curated, searchable exercise library with pre-set metadata so users don't have to manually type exercise names and categories.

---

## Data Layer

### ExerciseTemplate struct (NOT a SwiftData model)

```swift
struct ExerciseTemplate: Identifiable {
    let id = UUID()
    let name: String
    let category: ExerciseCategory
    let exerciseType: ExerciseType
    let primaryMuscle: MuscleGroup
}
```

### ExerciseLibrary enum

Static registry of ~80-100 exercises organized by category. Each exercise has name, category, type, and primary muscle pre-filled.

Coverage targets:
- **Push (20+):** Bench variations, OHP variations, flyes, raises, dips, pushdowns, extensions
- **Pull (20+):** Rows, pulldowns, pull-ups, curls, face pulls, reverse flyes, shrugs
- **Legs (20+):** Squats, deadlifts, leg press, lunges, RDLs, leg curls, calf raises, hip thrusts
- **Core (10+):** Planks, crunches, ab wheel, cable woodchop, leg raises, pallof press

Includes modern/trending movements: Bulgarian split squat, hip thrust, cable lateral raise, landmine press, Pendlay row, deficit deadlift, Z-press, seal row, etc.

### API

```swift
enum ExerciseLibrary {
    static let all: [ExerciseTemplate]
    static func search(_ query: String) -> [ExerciseTemplate]
    static func filter(category: ExerciseCategory?, muscle: MuscleGroup?) -> [ExerciseTemplate]
}
```

---

## UI: ExercisePickerSheet

Replaces the current `AddExerciseSheet` as the primary entry point. Full-screen sheet with:

### Layout (top to bottom)

1. **Header:** "ADD EXERCISE" + dismiss button
2. **Search bar:** `WireInput` with placeholder "Search exercises..."
3. **Category filters:** Horizontal row of toggleable chips (PUSH / PULL / LEGS / CORE)
4. **Muscle filters:** Horizontal row of toggleable chips (CHEST / BACK / SHOULDERS / ...)
5. **Results list:** Filtered exercises, each row shows:
   - Exercise name (Wire.Font.body, white)
   - Subtitle: "Push · Chest · Compound" (Wire.Font.caption, gray)
6. **Footer:** "CUSTOM" button → opens existing manual AddExerciseSheet

### Interaction

- Tap exercise → creates `Exercise(name:category:exerciseType:primaryMuscle:)` with library defaults
- Appends to the template's exercise array
- Dismisses picker
- User can then adjust weight/reps/sets in the template view

### Filtering logic

- Search: case-insensitive substring match on name
- Category chip: toggle on/off, multiple allowed
- Muscle chip: toggle on/off, multiple allowed
- All filters combine with AND (search AND category AND muscle)
- Empty filters = show all

---

## Integration Points

### Files to modify

1. **Create:** `GymTracker/Models/ExerciseLibrary.swift` — ExerciseTemplate + ExerciseLibrary enum
2. **Create:** `GymTracker/Views/ExercisePickerSheet.swift` — New picker UI
3. **Modify:** `GymTracker/Views/WorkoutTemplateView.swift` — "ADD EXERCISE" opens picker instead of AddExerciseSheet
4. **Modify:** `GymTracker/Views/ProgramSetupView.swift` — Same change
5. **Modify:** `GymTracker/GymTracker.xcodeproj` — Add new files (xcodegen)

### What stays the same

- `Exercise` model unchanged (no schema migration)
- `AddExerciseSheet` preserved as "CUSTOM" fallback
- `BiomechanicsEngine` registry unchanged (library is a separate data source)
- Seed data unchanged

---

## Non-goals

- No favorites/recently used (YAGNI)
- No exercise descriptions or instructions
- No exercise images/videos
- No user-created library entries (custom exercises go through AddExerciseSheet)
- No sync between library and BiomechanicsEngine (they serve different purposes)
