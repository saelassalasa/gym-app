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

    // Timer
    var timerValue: Int = 0
    var isTimerActive: Bool = false
    private var timerCancellable: AnyCancellable?
    
    // Save Guard - prevents multiple saves
    private var isSaving: Bool = false

    // Validation feedback
    var validationError: String? = nil
    
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
        guard repsInput > 0, repsInput <= 10, weightInput > 0 else { return weightInput }
        if repsInput == 1 { return weightInput }
        return weightInput * (1.0 + Double(repsInput) / 30.0)
    }
    
    var lastSessionSummary: String? {
        currentExercise?.lastSessionSummary(in: context)
    }
    
    // MARK: - Init
    
    init(template: WorkoutTemplate, container: ModelContainer) {
        self.container = container
        self.context = ModelContext(container)
        context.autosaveEnabled = false

        // Re-fetch template in child context to avoid cross-context references
        let templateID = template.id
        let descriptor = FetchDescriptor<WorkoutTemplate>(predicate: #Predicate { $0.id == templateID })
        let localTemplate = (try? context.fetch(descriptor))?.first ?? template

        // Create session ONCE and persist immediately
        let newSession = WorkoutSession(template: localTemplate)
        newSession.sets = []
        context.insert(newSession)
        try? context.save()

        self.session = newSession
        self._sessionID = newSession.id
        loadExerciseDefaults()
    }
    
    // MARK: - Actions
    
    func logSet() {
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

        // Detect PRs BEFORE inserting the new set
        let prs = PRService.detectPRs(
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
    
    func finishWorkout() {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        
        session.isCompleted = true
        session.duration = Date().timeIntervalSince(session.date)
        ProgressionManager.shared.checkAndIncrement(session: session)
        try? context.save()
        Wire.success()
    }
    
    /// KILL SWITCH: Incinerate the session and all associated sets
    func abortSession() {
        stopTimer()
        context.delete(session)
        try? context.save()
        Wire.heavy()
    }
    
    // MARK: - Timer
    
    func startTimer(seconds: Int) {
        timerValue = seconds
        isTimerActive = true
        
        timerCancellable?.cancel()
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                if self.timerValue > 0 {
                    self.timerValue -= 1
                } else {
                    self.stopTimer()
                    Wire.success()
                }
            }
    }
    
    func stopTimer() {
        isTimerActive = false
        timerCancellable?.cancel()
    }
    
    // MARK: - Private
    
    private func loadExerciseDefaults() {
        guard let exercise = currentExercise else { return }
        weightInput = exercise.currentWeight
        repsInput = exercise.targetReps
    }
}
