import SwiftUI
import SwiftData
import Combine

// ═══════════════════════════════════════════════════════════════════════════
// WORKOUT MANAGER
// Single source of truth for workout state. Prevents recursive saves.
// ═══════════════════════════════════════════════════════════════════════════

@MainActor @Observable
final class WorkoutManager {
    
    // MARK: - State
    private(set) var session: WorkoutSession
    private let container: ModelContainer
    private let context: ModelContext
    nonisolated let _sessionID: UUID
    var summaryContext: ModelContext { context }
    
    var currentExerciseIndex: Int = 0
    var weightInput: Double = 0
    var repsInput: Int = 8
    var rpeInput: Int = 7
    
    // PR Detection
    var prResults: [UUID: Set<PRType>] = [:]
    var showPRBanner: Bool = false
    var lastPRTypes: Set<PRType> = []

    // Timer — stores end date so background time is automatically handled
    var timerValue: Int = 0
    var isTimerActive: Bool = false
    private var timerEndDate: Date?
    private var timerCancellable: AnyCancellable?

    // Background tracking for accurate duration
    private var pausedDuration: TimeInterval = 0
    private var backgroundEntryDate: Date?
    private var backgroundObservers: [Any] = []

    // Save Guard - prevents multiple saves
    private var isSaving: Bool = false

    // Validation feedback
    var validationError: String? = nil

    // Save error (surfaced to UI)
    var saveError: String? = nil

    // Abort flag — session deleted, no further access
    private(set) var isAborted: Bool = false
    
    // MARK: - Computed
    
    var currentExercise: Exercise? {
        guard let exercises = session.template?.exercises,
              exercises.indices.contains(currentExerciseIndex) else { return nil }
        return exercises[currentExerciseIndex]
    }
    
    var exerciseCount: Int {
        session.template?.exercises.count ?? 0
    }
    
    var setsForCurrentExercise: [WorkoutSet] {
        guard let exercise = currentExercise,
              let sets = session.sets else { return [] }
        return sets
            .filter { $0.exercise?.id == exercise.id }
            .sorted { $0.setNumber < $1.setNumber }
    }
    
    var nextSetNumber: Int {
        setsForCurrentExercise.count + 1
    }
    
    var estimated1RM: Double {
        guard repsInput > 0, weightInput > 0 else { return 0 }
        if repsInput == 1 { return weightInput }
        guard repsInput < 37 else { return weightInput * 0.65 }
        return weightInput / (1.0278 - 0.0278 * Double(repsInput))
    }
    
    var lastSessionSummary: String? {
        currentExercise?.lastSessionSummary(in: context)
    }

    /// Per-set data from the last completed session for the current exercise (excludes current session)
    var previousSetsForCurrentExercise: [WorkoutSet] {
        guard let exercise = currentExercise else { return [] }
        return exercise.lastSessionSets(in: context, excludingSession: session.id)
    }

    // MARK: - Init
    
    init(template: WorkoutTemplate, container: ModelContainer) {
        self.container = container
        self.context = ModelContext(container)
        context.autosaveEnabled = false

        // Re-fetch template in child context to avoid cross-context references
        let templateID = template.id
        let descriptor = FetchDescriptor<WorkoutTemplate>(predicate: #Predicate { $0.id == templateID })
        guard let localTemplate = (try? context.fetch(descriptor))?.first else {
            debugLog("[CRITICAL] Template not found in child context — using defensive copy")
            // Create a minimal session without template reference rather than using cross-context object
            let newSession = WorkoutSession(template: nil)
            newSession.sets = []
            context.insert(newSession)
            try? context.save()
            self.session = newSession
            self._sessionID = newSession.id
            self.saveError = "Template sync failed — workout started without template link"
            return
        }

        // Create session ONCE and persist immediately
        let newSession = WorkoutSession(template: localTemplate)
        newSession.sets = []
        context.insert(newSession)
        do {
            try context.save()
        } catch {
            debugLog("[CRITICAL] Init save failed: \(error)")
            saveError = "Failed to create workout session"
        }

        self.session = newSession
        self._sessionID = newSession.id
        loadExerciseDefaults()
        registerBackgroundObservers()
    }
    
    // MARK: - Actions
    
    func logSet(setType: SetType = .working) {
        guard !isSaving else { return }
        guard weightInput > 0 else {
            Wire.heavy()
            validationError = "ENTER WEIGHT"
            return
        }
        guard repsInput > 0, let exercise = currentExercise else { return }
        validationError = nil

        isSaving = true
        defer { isSaving = false }

        // Detect PRs BEFORE inserting the new set (skip PR detection for warmup sets)
        let prs: Set<PRType> = setType == .warmup ? [] : PRService.detectPRs(
            weight: weightInput,
            reps: repsInput,
            exerciseName: exercise.name,
            context: context
        )

        let newSet = WorkoutSet(
            setNumber: nextSetNumber,
            reps: repsInput,
            weight: weightInput,
            rpe: rpeInput,
            setType: setType,
            isCompleted: true
        )

        newSet.exercise = exercise
        newSet.session = session
        context.insert(newSet)

        do {
            try context.save()
        } catch {
            debugLog("[ERROR] Save failed: \(error)")
        }

        // Store PR results and trigger banner
        if !prs.isEmpty {
            prResults[newSet.id] = prs
            lastPRTypes = prs
            showPRBanner = true
            Wire.success()
        } else {
            Wire.heavy()
        }

        startTimer(seconds: currentExercise?.restSeconds ?? 120)
    }
    
    /// SKIP PROTOCOL: Mark a set as skipped without weight/rep data
    func skipSet() {
        guard !isSaving else { return }
        guard let exercise = currentExercise else { return }
        
        isSaving = true
        defer { isSaving = false }
        
        let skippedSet = WorkoutSet(
            setNumber: nextSetNumber,
            reps: 0,      // No reps
            weight: 0,    // No weight
            rpe: nil,
            isCompleted: false,
            isSkipped: true
        )
        
        skippedSet.exercise = exercise
        skippedSet.session = session
        context.insert(skippedSet)
        
        do {
            try context.save()
        } catch {
            debugLog("[ERROR] Skip save failed: \(error)")
        }
        
        Wire.tap()
        // No timer after skip - move on immediately
    }
    
    func nextExercise() {
        if currentExerciseIndex < exerciseCount - 1 {
            currentExerciseIndex += 1
            loadExerciseDefaults()
        }
        Wire.tap()
    }
    
    func previousExercise() {
        if currentExerciseIndex > 0 {
            currentExerciseIndex -= 1
            loadExerciseDefaults()
        }
        Wire.tap()
    }

    /// Reorder exercises in the current template via drag-and-drop.
    /// Adjusts currentExerciseIndex so the user stays on the same exercise.
    func reorderExercises(from source: IndexSet, to destination: Int) {
        guard var exercises = session.template?.exercises else { return }
        let currentID = currentExercise?.id
        exercises.move(fromOffsets: source, toOffset: destination)
        session.template?.exercises = exercises
        // Keep the user on the same exercise they were viewing
        if let id = currentID,
           let newIndex = exercises.firstIndex(where: { $0.id == id }) {
            currentExerciseIndex = newIndex
        }
        do {
            try context.save()
        } catch {
            debugLog("[ERROR] Reorder save failed: \(error)")
        }
    }
    
    func finishWorkout() {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }

        stopTimer()
        removeBackgroundObservers()

        session.isCompleted = true
        // Subtract time spent in background for accurate active duration
        session.duration = Date().timeIntervalSince(session.date) - pausedDuration
        ProgressionManager.shared.checkAndIncrement(session: session)
        do {
            try context.save()
        } catch {
            debugLog("[CRITICAL] Finish save failed: \(error)")
            saveError = "Failed to save workout — your data may be lost"
        }
        Wire.success()
    }
    
    /// KILL SWITCH: Incinerate the session and all associated sets
    func abortSession() {
        stopTimer()
        removeBackgroundObservers()
        context.delete(session)
        do {
            try context.save()
        } catch {
            debugLog("[CRITICAL] Abort save failed: \(error)")
            saveError = "Failed to delete session — restart app to clean up"
        }
        isAborted = true
        Wire.heavy()
    }
    
    // MARK: - Timer
    
    func startTimer(seconds: Int) {
        timerEndDate = Date().addingTimeInterval(Double(seconds))
        timerValue = seconds
        isTimerActive = true

        timerCancellable?.cancel()
        timerCancellable = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tickTimer()
            }
    }

    /// Recompute remaining from timerEndDate — works correctly after background
    private func tickTimer() {
        guard let endDate = timerEndDate else { return }
        let remaining = Int(ceil(endDate.timeIntervalSinceNow))
        if remaining > 0 {
            timerValue = remaining
        } else {
            timerValue = 0
            stopTimer()
            Wire.success()
        }
    }

    func stopTimer() {
        isTimerActive = false
        timerEndDate = nil
        timerCancellable?.cancel()
    }
    
    // MARK: - Private
    
    private func loadExerciseDefaults() {
        guard let exercise = currentExercise else { return }
        weightInput = exercise.currentWeight
        repsInput = exercise.targetReps
    }

    // MARK: - Background Tracking

    private func registerBackgroundObservers() {
        let resignObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.backgroundEntryDate = Date()
            }
        }

        let activeObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let entry = self.backgroundEntryDate else { return }
                self.pausedDuration += Date().timeIntervalSince(entry)
                self.backgroundEntryDate = nil
                // Refresh rest timer display immediately on foreground return
                if self.isTimerActive { self.tickTimer() }
            }
        }

        backgroundObservers = [resignObserver, activeObserver]
    }

    private func removeBackgroundObservers() {
        for observer in backgroundObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        backgroundObservers = []
    }

    deinit {
        MainActor.assumeIsolated {
            removeBackgroundObservers()
        }
    }
}
