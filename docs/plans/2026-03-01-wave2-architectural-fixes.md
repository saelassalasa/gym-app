# Wave 2: Architectural Fixes — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix 7 architectural bugs that cause state corruption, double-progression, orphan data, and security issues.

**Architecture:** Child context isolation for WorkoutManager, idempotency gates on progression, launch-time orphan cleanup, Keychain for API secrets, and input validation at remaining unguarded entry points.

**Tech Stack:** SwiftUI, SwiftData, Security.framework (Keychain)

**Note:** No test suite exists. Testing is manual (Simulator). Each task ends with a build verification.

---

### Task 1: WorkoutManager child context (W2-1)

**Files:**
- Modify: `GymTracker/ViewModels/WorkoutManager.swift:11-16, 75-86, 189-207`
- Modify: `GymTracker/Views/DashboardView.swift:387-391`

**Why:** WorkoutManager currently takes the main `ModelContext` directly. Any insert/delete mutates the shared store immediately — causing races with `@Query`, dangling refs on abort, and cascading side effects.

**Step 1: Change WorkoutManager to accept ModelContainer**

In `WorkoutManager.swift`, replace:
```swift
private let context: ModelContext
var summaryContext: ModelContext { context }

// ...

init(template: WorkoutTemplate, context: ModelContext) {
    self.context = context
    let newSession = WorkoutSession(template: template)
    newSession.sets = []
    context.insert(newSession)
    try? context.save()
    self.session = newSession
    loadExerciseDefaults()
}
```

With:
```swift
private let context: ModelContext
private let container: ModelContainer
var summaryContext: ModelContext { context }

// ...

init(template: WorkoutTemplate, container: ModelContainer) {
    self.container = container
    self.context = ModelContext(container)
    context.autosaveEnabled = false

    // Re-fetch template in child context to avoid cross-context refs
    let templateID = template.id
    let descriptor = FetchDescriptor<WorkoutTemplate>(predicate: #Predicate { $0.id == templateID })
    let localTemplate = (try? context.fetch(descriptor))?.first ?? template

    let newSession = WorkoutSession(template: localTemplate)
    newSession.sets = []
    context.insert(newSession)
    try? context.save()
    self.session = newSession
    loadExerciseDefaults()
}
```

**Step 2: Update finishWorkout to merge child context**

In `finishWorkout()`, the `context.save()` call already writes to the store via the child context. No change needed — SwiftData child contexts auto-persist on save. Just ensure `context.save()` is called.

**Step 3: Update abortSession**

`abortSession()` already deletes from the context and saves. With a child context, aborting deletes only from the child — clean. No change needed.

**Step 4: Update DashboardView call site**

In `DashboardView.swift:387-391`, replace:
```swift
private func startWorkout(template: WorkoutTemplate) {
    Wire.heavy()
    let manager = WorkoutManager(template: template, context: modelContext)
    activeManager = manager
}
```

With:
```swift
private func startWorkout(template: WorkoutTemplate) {
    Wire.heavy()
    let manager = WorkoutManager(template: template, container: modelContext.container)
    activeManager = manager
}
```

**Step 5: Build and verify**

Run: `xcodebuild -project GymTracker/GymTracker.xcodeproj -scheme GymTracker -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 6: Commit**
```
git add GymTracker/ViewModels/WorkoutManager.swift GymTracker/Views/DashboardView.swift
git commit -m "W2-1: Isolate WorkoutManager in child ModelContext"
```

---

### Task 2: Progression idempotency gate (W2-2)

**Files:**
- Modify: `GymTracker/Models/GymModels.swift:153-176` (WorkoutSession model)
- Modify: `GymTracker/ViewModels/ProgressionManager.swift:42-61`

**Why:** Calling `finishWorkout()` twice (double-tap, re-render) calls `checkAndIncrement` twice, doubling weight progression. Need a flag to prevent re-entry.

**Step 1: Add progressionApplied to WorkoutSession**

In `GymModels.swift`, inside `WorkoutSession`, after `var isCompleted: Bool` (line 158), add:
```swift
var progressionApplied: Bool
```

And in the `init`, add `self.progressionApplied = false` after `self.isCompleted = isCompleted`.

Update the init signature to include `progressionApplied: Bool = false`.

**Step 2: Guard in checkAndIncrement**

In `ProgressionManager.swift:42`, replace:
```swift
func checkAndIncrement(session: WorkoutSession) {
    guard let template = session.template, let sets = session.sets else { return }
```

With:
```swift
func checkAndIncrement(session: WorkoutSession) {
    guard !session.progressionApplied else { return }
    guard let template = session.template, let sets = session.sets else { return }
```

At the end of the method (after the for loop, before the closing `}`), add:
```swift
    session.progressionApplied = true
```

**Step 3: Build and verify**

Run: `xcodebuild ... build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED (SwiftData handles additive fields with defaults automatically — no migration needed)

**Step 4: Commit**
```
git add GymTracker/Models/GymModels.swift GymTracker/ViewModels/ProgressionManager.swift
git commit -m "W2-2: Add progressionApplied idempotency gate"
```

---

### Task 3: Orphan session cleanup on launch (W2-3)

**Files:**
- Modify: `GymTracker/GymTrackerApp.swift:23-30`

**Why:** If the app is force-killed during a workout, the incomplete `WorkoutSession` persists forever — inflating streaks, showing phantom entries. Clean them up on launch.

**Step 1: Add cleanup to app launch**

In `GymTrackerApp.swift`, after the `.onAppear { seedIfNeeded() }` line (27), add a new call:

```swift
.onAppear {
    seedIfNeeded()
    cleanOrphanSessions()
}
```

**Step 2: Add cleanOrphanSessions method**

After `seedIfNeeded()` (line 76), add:

```swift
@MainActor
private func cleanOrphanSessions() {
    let context = sharedModelContainer.mainContext
    let descriptor = FetchDescriptor<WorkoutSession>(
        predicate: #Predicate<WorkoutSession> { !$0.isCompleted }
    )
    guard let orphans = try? context.fetch(descriptor), !orphans.isEmpty else { return }
    for session in orphans {
        session.isCompleted = true
        session.duration = 0
        session.notes = "[RECOVERED]"
    }
    try? context.save()
    debugLog("Cleaned \(orphans.count) orphan session(s)")
}
```

**Step 3: Build and verify**

Run: `xcodebuild ... build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 4: Commit**
```
git add GymTracker/GymTrackerApp.swift
git commit -m "W2-3: Clean orphan sessions on launch"
```

---

### Task 4: Delete-during-workout block (W2-4)

**Files:**
- Modify: `GymTracker/Views/DashboardView.swift:371-383`

**Why:** Deleting a program while its template is being used in an active workout causes a dangling reference crash.

**Step 1: Find the `activeManager` state variable**

It should be a `@State private var activeManager: WorkoutManager?` somewhere near the top of `DashboardView`. We need to reference it in `deleteProgram`.

**Step 2: Guard in deleteProgram**

In `DashboardView.swift`, replace:
```swift
private func deleteProgram(_ program: WorkoutProgram) {
    Wire.heavy()
```

With:
```swift
private func deleteProgram(_ program: WorkoutProgram) {
    // Block deletion if an active workout uses a template from this program
    if let manager = activeManager,
       let activeTemplate = manager.session.template,
       (program.templates ?? []).contains(where: { $0.id == activeTemplate.id }) {
        // TODO: Could show an alert here, but for now just refuse silently
        Wire.heavy()
        return
    }
    Wire.heavy()
```

**Step 3: Build and verify**

Expected: BUILD SUCCEEDED

**Step 4: Commit**
```
git add GymTracker/Views/DashboardView.swift
git commit -m "W2-4: Block program deletion during active workout"
```

---

### Task 5: API key to Keychain (W2-5)

**Files:**
- Create: `GymTracker/Services/KeychainManager.swift`
- Modify: `GymTracker/Services/GeminiService.swift:14-23`
- Modify: `GymTracker/Views/SettingsView.swift` (API key read/write)
- Modify: `GymTracker/GymTracker.xcodeproj/project.pbxproj` (add new file — or use xcodegen)

**Why:** API key in UserDefaults is plaintext in app sandbox backup. Keychain encrypts at rest.

**Step 1: Create KeychainManager**

Create `GymTracker/Services/KeychainManager.swift`:
```swift
import Foundation
import Security

enum KeychainManager {
    private static let service = "saelassasolutions.GymTracker"

    static func set(_ value: String, forKey key: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        SecItemAdd(add as CFDictionary, nil)
    }

    static func get(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
```

**Step 2: Update GeminiService apiKey**

In `GeminiService.swift`, replace the `apiKey` computed property that reads/writes UserDefaults:
```swift
static var apiKey: String? {
    get { KeychainManager.get(forKey: "gemini_api_key") }
    set {
        if let val = newValue { KeychainManager.set(val, forKey: "gemini_api_key") }
        else { KeychainManager.delete(forKey: "gemini_api_key") }
    }
}
```

**Step 3: Migrate existing key on first access**

Add a one-time migration in the getter:
```swift
static var apiKey: String? {
    get {
        if let key = KeychainManager.get(forKey: "gemini_api_key") { return key }
        // One-time migration from UserDefaults
        if let legacy = UserDefaults.standard.string(forKey: "gemini_api_key"), !legacy.isEmpty {
            KeychainManager.set(legacy, forKey: "gemini_api_key")
            UserDefaults.standard.removeObject(forKey: "gemini_api_key")
            return legacy
        }
        return nil
    }
    set {
        if let val = newValue { KeychainManager.set(val, forKey: "gemini_api_key") }
        else { KeychainManager.delete(forKey: "gemini_api_key") }
    }
}
```

**Step 4: Update SettingsView**

In `SettingsView.swift`, find where `apiKeyInput` is initialized from UserDefaults and change to read from `GeminiService.apiKey ?? ""`. The save action already calls `GeminiService.setAPIKey()` so that path should just work after Step 3.

**Step 5: Add file to Xcode project**

Run: `cd GymTracker && xcodegen generate` (or manually add to project.pbxproj)

**Step 6: Build and verify**

Expected: BUILD SUCCEEDED

**Step 7: Commit**
```
git add GymTracker/Services/KeychainManager.swift GymTracker/Services/GeminiService.swift GymTracker/Views/SettingsView.swift GymTracker/GymTracker.xcodeproj/project.pbxproj
git commit -m "W2-5: Move API key from UserDefaults to Keychain"
```

---

### Task 6: Gemini import primaryMuscle assignment (W2-6)

**Files:**
- Modify: `GymTracker/Views/ImageImportView.swift:397-405`

**Why:** Exercises created from Gemini image import have no `primaryMuscle` set (defaults to `.chest`). This poisons recovery calculations for non-chest exercises.

**Step 1: Add primaryMuscle resolution at import**

In `ImageImportView.swift:397-405`, replace:
```swift
let exercise = Exercise(
    name: editableExercise.name,
    category: inferCategory(from: editableExercise.name),
    notes: editableExercise.notes ?? "",
    targetReps: editableExercise.reps,
    targetSets: editableExercise.sets
)
```

With:
```swift
let exercise = Exercise(
    name: editableExercise.name,
    category: inferCategory(from: editableExercise.name),
    notes: editableExercise.notes ?? "",
    targetReps: editableExercise.reps,
    targetSets: editableExercise.sets
)
// Resolve primaryMuscle from BiomechanicsEngine registry
let activations = BiomechanicsEngine.muscleActivation(for: exercise)
if let topMuscle = activations.max(by: { $0.value < $1.value })?.key {
    exercise.primaryMuscle = topMuscle
}
```

**Step 2: Build and verify**

Expected: BUILD SUCCEEDED

**Step 3: Commit**
```
git add GymTracker/Views/ImageImportView.swift
git commit -m "W2-6: Assign primaryMuscle from BiomechanicsEngine on Gemini import"
```

---

### Task 7: SetEditorRow validation (W2-7)

**Files:**
- Modify: `GymTracker/Views/HistoryView.swift:281-311`

**Why:** `SetEditorRow` uses raw `TextField` with `.number` format — no NaN/Infinity/negative guard. Users can type garbage values that pollute PR calculations.

**Step 1: Add .onChange validation**

In `HistoryView.swift`, after the weight TextField block (line 299, after the `.overlay`), add:
```swift
.onChange(of: set.weight) { _, new in
    if !new.isFinite || new < 0 { set.weight = 0 }
    if new > 1000 { set.weight = 1000 }
}
```

After the reps TextField block (line 311, after the `.overlay`), add:
```swift
.onChange(of: set.reps) { _, new in
    if new < 0 { set.reps = 0 }
    if new > 100 { set.reps = 100 }
}
```

**Step 2: Build and verify**

Expected: BUILD SUCCEEDED

**Step 3: Commit**
```
git add GymTracker/Views/HistoryView.swift
git commit -m "W2-7: Add weight/rep validation to SetEditorRow"
```

---

## Execution Order & Dependencies

```
Task 1 (child context) ─── no deps, do first (highest leverage)
Task 2 (idempotency)   ─── no deps, can parallel with Task 1
Task 3 (orphan cleanup) ── depends on Task 2 (idempotency gate prevents double progression on recovered sessions)
Task 4 (delete block)  ─── depends on Task 1 (needs to know child context pattern)
Task 5 (Keychain)      ─── independent, can parallel
Task 6 (primaryMuscle) ─── independent, can parallel
Task 7 (SetEditorRow)  ─── independent, can parallel
```

**Recommended execution:** Tasks 1+2+5+6+7 in parallel, then Task 3, then Task 4.
