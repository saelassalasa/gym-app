# GymTracker Bug Fix Plan

**Date:** 2026-02-21
**Total bugs found:** 102 (76 from QA + 26 from black-hat testing)
**This plan covers:** ~50 highest priority fixes across 3 waves

---

## Test Summary

### QA Phase (15 Sonnet agents)
13 Sonnet agents tested every module as regular users. 2 additional agents covered edge cases and navigation. Found 76 unique bugs: 5 Critical, 18 High, 25 Medium, 28 Low.

### Black-Hat Phase (5 Opus agents)
5 adversarial Opus agents attacked the app from different vectors:
1. Data corruption & state manipulation
2. UI abuse & input injection
3. Memory & resource exhaustion
4. Logic bombs & exploit chains
5. Network & API exploitation

Found 26 NEW bugs: 7 Critical, 12 High, 7 Medium.

### Engineering Discussion (3 Sonnet agents)
3 engineers debated solutions:
- **Engineer A (Defensive):** Input validation, guards, NaN prevention
- **Engineer B (Systems):** State management, child context, concurrency
- **Engineer C (Security):** Network, encryption, exploit chain prevention

---

## Severity Breakdown

| Severity | QA (15) | Black-Hat (5) | Total |
|----------|---------|---------------|-------|
| Critical | 5       | 7             | 12    |
| High     | 18      | 12            | 30    |
| Medium   | 25      | 7             | 32    |
| Low      | 28      | 0             | 28    |
| **Total**| **76**  | **26**        | **102**|

---

## Architectural Decisions (Closed)

| Decision | Verdict | Rationale |
|----------|---------|-----------|
| Certificate pinning | NO | ATS (TLS 1.2+) is sufficient for personal app threat model. Cert pinning adds maintenance burden on Google cert rotations. |
| SQLCipher encryption | NO | iOS Data Protection `.complete` encrypts DB at rest when device is locked. SQLCipher doubles binary size. |
| `[Exercise]` stored array → `@Relationship` | NO | Current duplication-per-template model is correct. Each template owns its own progression state. Shared identity would cause cross-template side effects. |
| API key storage | Keychain | UserDefaults is world-readable in app group, included in unencrypted backups. Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` is the correct answer. |
| All numeric input routing | WireNumField | SetEditorRow and PlateCalculator must use `WireNumField` with validation baked in. One guard at the gate prevents 3+ bugs. |

---

## Cross-Cutting Patterns (Root Causes)

1. **Shared ModelContext** — WorkoutManager and DashboardView share the same context. Template edits/deletes during active workouts corrupt exercise references. Fix: child context.
2. **No input validation on numeric fields** — NaN, Infinity, negative, and astronomical values flow straight into SwiftData. Fix: WireNumField guard.
3. **Silent `try?` error swallowing** — 25+ `try? context.save()` calls across 15 files. Data loss is invisible. Fix: centralized error handler (future wave).
4. **`resolvedPrimaryMuscle` defaults to `.chest`** — Cascades through RecoveryEngine, BiomechanicsEngine, and heatmap. All untyped exercises show as chest. Fix: BiomechanicsEngine-driven assignment at import.
5. **Unbounded @Query fetches** — PRService, StatsHeaderView, ProgressView fetch ALL records and filter in Swift. O(n) memory on every render. Fix: predicates and fetch limits.

---

## WAVE 1: Emergency Fixes (~30 min, zero risk)

All S effort. Single-line guards and parameter changes.

### W1-1: WireNumField NaN/Infinity guard
**Bugs solved:** BH-C2, BH-H4 (partial), BH-H6 (partial)
**File:** `BrutalistTheme.swift:277`
**Fix:** Add `.onChange(of: value)` to sanitize non-finite and negative values:
```swift
TextField("", value: $value, format: .number)
    .onChange(of: value) { _, new in
        if !new.isFinite || new < 0 { value = 0 }
    }
```

### W1-2: API key to HTTP header
**Bugs solved:** C1
**File:** `GeminiService.swift:58`
**Fix:** Remove `?key=\(apiKey)` from URL. Add `request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")`.

### W1-3: Force-unwrap in drag-drop
**Bugs solved:** C2
**File:** `WorkoutTemplateView.swift:183`
**Fix:** Replace `items.firstIndex(of: draggedItem)!` with `guard let from = items.firstIndex(of: draggedItem), let to = items.firstIndex(of: item) else { return }`.

### W1-4: computeDuration() before guard
**Bugs solved:** C4
**File:** `WorkoutSummaryViewModel.swift:62`
**Fix:** Move `computeDuration()` call above the `guard totalSets > 0` early return.

### W1-5: Gemini response cap
**Bugs solved:** BH-C7
**File:** `GeminiService.swift:41,106`
**Fix:** `maxOutputTokens: 1024` (down from 4096). Add `guard data.count <= 512 * 1024` before JSON decode.

### W1-6: Debug log wrapper
**Bugs solved:** BH-H12
**File:** All files with `print()` calls (40 total)
**Fix:** Create `debugLog(_ message: @autoclosure () -> String)` with `#if DEBUG`. Find-replace `print(` → `debugLog(`.

### W1-7: Error body sanitize
**Bugs solved:** BH-M7
**File:** `GeminiService.swift:48-49`
**Fix:** Map HTTP status codes to safe strings. Never render raw server body to UI.

### W1-8: estimated1RM Brzycki formula
**Bugs solved:** H10
**File:** `GymModels.swift:197`
**Fix:** Replace the `guard reps <= 10` with Brzycki formula: `weight / (1.0278 - 0.0278 * Double(reps))`. Guard `reps < 37`.

### W1-9: Zero weight user feedback
**Bugs solved:** H5
**File:** `WorkoutManager.swift:89`
**Fix:** Add `Wire.heavy()` haptic + `validationError = "ENTER WEIGHT"` instead of silent return.

### W1-10: effectivePercent cap
**Bugs solved:** H17
**File:** `WorkoutSummaryViewModel.swift:97`
**Fix:** `let effectivePercent = min(Double(effective) / Double(totalSets), 1.0)`

### W1-11: log() input guard
**Bugs solved:** H1, H2
**File:** `RecoveryEngine.swift:50,129-130`
**Fix:** `log(max(Double(sets), 1.0) / 6.0)` for volumeMultiplier. `log(max(currentFatigue, 0.001) / targetFatigue)` for hoursUntilReady.

### W1-12: PlateCalculator input cap
**Bugs solved:** BH-H6
**File:** `PlateCalculatorView.swift:17`
**Fix:** `guard targetWeight.isFinite, targetWeight > barWeight, targetWeight <= 2000 else { return [] }`

---

## WAVE 2: Architectural Fixes (~2-3 hours, medium risk)

### W2-1: WorkoutManager child context
**Bugs solved:** BH-C1, BH-C5, H18, shared state races
**File:** `WorkoutManager.swift:72-83`, `DashboardView.swift:388`
**Fix:** `WorkoutManager.init` takes `ModelContainer` instead of `ModelContext`. Creates `ModelContext(container)` internally. Re-fetches template in isolated context. All workout mutations happen in child context, merged on `finishWorkout`.
**Risk:** WorkoutSets won't appear in main context @Query until child context saves. PRService already uses WorkoutManager's context, so no change needed.
**Effort:** M

### W2-2: Progression idempotency gate
**Bugs solved:** BH-C3, double-FINISH (H16), BH-M6
**File:** `GymModels.swift` (add field), `ProgressionManager.swift:42-61`
**Fix:** Add `var progressionApplied: Bool = false` to WorkoutSession. Guard `!session.progressionApplied` at top of `checkAndIncrement`. Set `true` after mutation.
**Risk:** Schema migration (SwiftData handles additive fields with defaults automatically).
**Effort:** S

### W2-3: Orphan session cleanup on launch
**Bugs solved:** C5, BH-M6, streak inflation
**File:** `GymTrackerApp.swift`
**Fix:** On launch, fetch all sessions where `isCompleted == false`. Mark them `isCompleted = true, duration = 0, notes = "[RECOVERED]"`. Do NOT call `checkAndIncrement` (idempotency gate prevents it anyway).
**Effort:** S

### W2-4: Delete-during-workout block
**Bugs solved:** BH-C5
**File:** `DashboardView.swift:371-383`
**Fix:** Check `activeManager != nil` and if the active workout's template belongs to the program being deleted. Show alert instead of deleting.
**Effort:** S

### W2-5: API key to Keychain
**Bugs solved:** Security hardening
**File:** `GeminiService.swift`, `SettingsView.swift`
**Fix:** Create `KeychainManager` enum with `set/get` using `kSecClassGenericPassword` + `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`. Replace `UserDefaults.standard.string(forKey: "gemini_api_key")` calls.
**Effort:** M

### W2-6: Gemini import primaryMuscle assignment
**Bugs solved:** BH-C4, recovery poisoning chain
**File:** `ImageImportView.swift:398-404`
**Fix:** At import time, run exercise name through `BiomechanicsEngine` to determine top muscle activation. Assign `exercise.primaryMuscle = topMuscle`.
**Effort:** S-M

### W2-7: SetEditorRow validation
**Bugs solved:** BH-H4, BH-H9 (PR pollution prevention)
**File:** `HistoryView.swift:293-310`
**Fix:** Route through `WireNumField` or add `.onChange` guards: weight 0-1000, reps 0-100.
**Effort:** S

---

## WAVE 3: Data Quality & Performance (~1-2 days)

### W3-1: computeStreak fix
**Bugs solved:** H7
**File:** `DashboardView.swift:497-513`
**Fix:** Allow streak to start from yesterday if no workout today. Only count `isCompleted == true` sessions. Group by calendar day (not per-session).

### W3-2: StatsHeaderView @Query predicate
**Bugs solved:** H6
**File:** `DashboardView.swift:442`
**Fix:** Add `#Predicate { $0.isCompleted == true }` to the @Query.

### W3-3: PRService fetch optimization
**Bugs solved:** H9, performance degradation
**File:** `PRService.swift:106-114`
**Fix:** Add exercise name predicate to FetchDescriptor. Add fetchLimit. Eliminate full-table scan.

### W3-4: wipeHistory resets template weights
**Bugs solved:** BH-H8
**File:** `SettingsView.swift:206-224`
**Fix:** After deleting sessions, also reset `exercise.currentWeight` to initial value on all template exercises. Reset `progressionApplied` flags.

### W3-5: New user atrophy false positive
**Bugs solved:** M1
**File:** `RecoveryEngine.swift:84-90`
**Fix:** When `relevant.isEmpty`, return `.unknown` or `.noData` instead of `.atrophyRisk`. Add new case to RecoveryColor.

### W3-6: Fuzzy match deterministic
**Bugs solved:** H14
**File:** `BiomechanicsEngine.swift:49`
**Fix:** Sort registry matches by key length descending. Longest match wins. Cache results in a dictionary.

### W3-7: File protection on SwiftData store
**Bugs solved:** BH-H11
**File:** `GymTrackerApp.swift:14`
**Fix:** Set `URLFileProtection.complete` on the store URL after container creation.

### W3-8: "cable kickback" key collision
**Bugs solved:** M5
**File:** `BiomechanicsEngine.swift:245,448`
**Fix:** Rename to `"cable tricep kickback"` and `"cable glute kickback"`.

### W3-9: Body.obj missing fallback
**Bugs solved:** C3
**File:** `HologramBodyView.swift:193-210`
**Fix:** If OBJ fails to load, show a placeholder text or skip the hologram gracefully.

### W3-10: updateUIView equality check
**Bugs solved:** H13
**File:** `HologramBodyView.swift:21-24`
**Fix:** Compare `muscleVolumes` with previous values before calling `updateIntensities`. Skip if unchanged.

---

## Bugs NOT covered by this plan (backlog, 52 remaining)

### Categories:
- **Accessibility:** Dynamic Type support, VoiceOver labels, contrast ratios (6 bugs)
- **Design system drift:** Raw padding/font sizes in PlanView, SettingsView, ImageImportView (6 bugs)
- **Performance long-tail:** ProgressView unbounded @Query, PlanView O(42*n), DateFormatter caching (5 bugs)
- **UX polish:** No date grouping in history, notes field not exposed, reps stepper max 30, DISMISS not sticky (8 bugs)
- **Minor correctness:** Shrug muscle mapping, hammerCurl missing forearm, locale-dependent dates, RPE half-points (7 bugs)
- **Concurrency audit:** ProgressionManager @MainActor, CalendarManager thread safety (4 bugs)
- **Silent error handling:** 25+ `try?` calls to replace with proper error reporting (future wave)
- **Calendar edge cases:** [IRON] prefix scope, past-date validation, deployProgram batching (4 bugs)
- **Timer/lifecycle:** Background timer drift, sheet stacking, tab switch during workout (5 bugs)
- **Data cleanup:** Orphan set detection, schema migration versioning (3 bugs)
- **Hologram:** Head zone, UV coords, Fresnel NaN, additive blend artifacts (4 bugs)

---

## Risk Assessment

| Wave | Effort | Risk | Bugs Solved |
|------|--------|------|-------------|
| 1    | 30 min | Zero — all additive guards | ~15 |
| 2    | 2-3 hrs | Medium — child context changes data flow | ~12 |
| 3    | 1-2 days | Low — isolated fixes | ~23 |
| **Total** | **~2-3 days** | | **~50** |

---

## Implementation Order

1. Wave 1 first (all S effort, zero risk, immediate safety)
2. Wave 2-1 (child context) is the highest-leverage single change
3. Wave 2-2 (idempotency) must come before Wave 2-3 (orphan cleanup)
4. Wave 3 items are independent and can be parallelized
