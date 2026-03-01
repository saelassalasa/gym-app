import Foundation
import SwiftData

// MARK: - Exercise Category (movement pattern)
enum ExerciseCategory: String, Codable, CaseIterable {
    case push = "PUSH"
    case pull = "PULL"
    case legs = "LEGS"
    case core = "CORE"
    case cardio = "CARDIO"
    case other = "OTHER"
}

// MARK: - Exercise Type (compound vs accessory — drives powerbuilding logic + recovery math)
enum ExerciseType: String, Codable, CaseIterable {
    case compound  = "COMPOUND"
    case accessory = "ACCESSORY"
}

// MARK: - Muscle Group (anatomy — drives recovery engine)
enum MuscleGroup: String, Codable, CaseIterable, Identifiable {
    case chest, back, quads, hamstrings, glutes
    case shoulders, biceps, triceps
    case calves, core

    var id: String { rawValue }

    /// Base hours to recover at moderate volume (6 sets), RPE 8, isolation
    var baseRecoveryHours: Double {
        switch self {
        case .quads, .hamstrings, .chest:    return 60
        case .back, .glutes:                 return 56
        case .shoulders, .biceps, .triceps:  return 42
        case .calves, .core:                 return 30
        }
    }

    /// Fatigue decay time constant (days) — Banister tau2
    var fatigueTau: Double {
        switch self {
        case .quads, .hamstrings, .chest, .back, .glutes: return 2.5
        case .shoulders, .biceps, .triceps:                return 1.75
        case .calves, .core:                               return 1.0
        }
    }
}

// MARK: - Exercise
@Model
final class Exercise {
    var id: UUID
    var name: String
    var category: ExerciseCategory
    var exerciseType: ExerciseType?
    var primaryMuscle: MuscleGroup?
    var notes: String
    var restSeconds: Int

    // Progression Data
    var currentWeight: Double
    var targetIncrement: Double
    var targetReps: Int
    var targetSets: Int

    @Relationship(deleteRule: .cascade, inverse: \WorkoutSet.exercise)
    var sets: [WorkoutSet]?

    init(
        name: String,
        category: ExerciseCategory,
        exerciseType: ExerciseType = .compound,
        primaryMuscle: MuscleGroup = .chest,
        notes: String = "",
        restSeconds: Int = 120,
        currentWeight: Double = 20.0,
        targetIncrement: Double = 2.5,
        targetReps: Int = 8,
        targetSets: Int = 3
    ) {
        self.id = UUID()
        self.name = name
        self.category = category
        self.exerciseType = exerciseType
        self.primaryMuscle = primaryMuscle
        self.notes = notes
        self.restSeconds = restSeconds
        self.currentWeight = currentWeight
        self.targetIncrement = targetIncrement
        self.targetReps = targetReps
        self.targetSets = targetSets
    }

    /// Safe accessors with defaults for legacy data (pre-migration exercises without these fields)
    var resolvedExerciseType: ExerciseType { exerciseType ?? .compound }
    var resolvedPrimaryMuscle: MuscleGroup { primaryMuscle ?? .chest }
}

// MARK: - Workout Program
// Container for N-day split programs (e.g., Push/Pull/Legs, 5-day split)
@Model
final class WorkoutProgram {
    var id: UUID
    var name: String
    var isActive: Bool
    var createdAt: Date
    
    @Relationship(deleteRule: .cascade, inverse: \WorkoutTemplate.program)
    var templates: [WorkoutTemplate]?
    
    /// Ordered templates by dayIndex
    var orderedTemplates: [WorkoutTemplate] {
        (templates ?? []).sorted { $0.dayIndex < $1.dayIndex }
    }
    
    /// Number of workout days in this program
    var dayCount: Int {
        templates?.count ?? 0
    }
    
    init(name: String, isActive: Bool = false) {
        self.id = UUID()
        self.name = name
        self.isActive = isActive
        self.createdAt = Date()
    }
}

// MARK: - Workout Template
@Model
final class WorkoutTemplate {
    var id: UUID
    var name: String
    var dayIndex: Int  // 0-based: Day 1 = 0, Day 2 = 1, etc.
    var exercises: [Exercise]
    
    var program: WorkoutProgram?
    
    /// Display name like "DAY 1" or custom name
    var displayName: String {
        name.isEmpty ? "DAY \(dayIndex + 1)" : name
    }
    
    init(name: String, dayIndex: Int = 0, exercises: [Exercise] = []) {
        self.id = UUID()
        self.name = name
        self.dayIndex = dayIndex
        self.exercises = exercises
    }
}

// MARK: - Workout Session
@Model
final class WorkoutSession {
    var id: UUID
    var date: Date
    var duration: TimeInterval
    var notes: String
    var isCompleted: Bool
    var template: WorkoutTemplate?
    
    @Relationship(deleteRule: .cascade, inverse: \WorkoutSet.session)
    var sets: [WorkoutSet]?
    
    init(
        date: Date = Date(),
        duration: TimeInterval = 0,
        notes: String = "",
        isCompleted: Bool = false,
        template: WorkoutTemplate? = nil
    ) {
        self.id = UUID()
        self.date = date
        self.duration = duration
        self.notes = notes
        self.isCompleted = isCompleted
        self.template = template
    }
}

// MARK: - Workout Set
@Model
final class WorkoutSet {
    var id: UUID
    var setNumber: Int
    var reps: Int
    var weight: Double
    var rpe: Int?
    var isCompleted: Bool = false
    var isSkipped: Bool = false
    var timestamp: Date = Date()
    
    var exercise: Exercise?
    var session: WorkoutSession?
    
    /// Brzycki Formula: 1RM = weight / (1.0278 − 0.0278 × reps)
    var estimated1RM: Double {
        guard reps > 0, weight > 0 else { return 0 }
        if reps == 1 { return weight }
        guard reps < 37 else { return weight * 0.65 }
        return weight / (1.0278 - 0.0278 * Double(reps))
    }
    
    init(
        setNumber: Int = 1,
        reps: Int,
        weight: Double,
        rpe: Int? = nil,
        isCompleted: Bool = false,
        isSkipped: Bool = false
    ) {
        self.id = UUID()
        self.setNumber = setNumber
        self.reps = reps
        self.weight = weight
        self.rpe = rpe
        self.isCompleted = isCompleted
        self.isSkipped = isSkipped
        self.timestamp = Date()
    }
}

// MARK: - Exercise History Extension
extension Exercise {
    /// Returns the last completed sets for this exercise from a previous session
    func lastSessionSets(in context: ModelContext) -> [WorkoutSet] {
        let exerciseId = self.id
        let descriptor = FetchDescriptor<WorkoutSet>(
            predicate: #Predicate { set in
                set.exercise?.id == exerciseId && set.isCompleted
            },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        guard let allSets = try? context.fetch(descriptor),
              let lastSession = allSets.first?.session else {
            return []
        }
        
        let lastSessionId = lastSession.id
        return allSets.filter { $0.session?.id == lastSessionId }
            .sorted { $0.setNumber < $1.setNumber }
    }
    
    /// Formatted string for history overlay: "LAST: 100kg × 5 @ RPE 8"
    func lastSessionSummary(in context: ModelContext) -> String? {
        let sets = lastSessionSets(in: context)
        guard let topSet = sets.max(by: { $0.weight < $1.weight }) else {
            return nil
        }
        
        var summary = "LAST: \(Int(topSet.weight))kg × \(topSet.reps)"
        if let rpe = topSet.rpe {
            summary += " @ RPE \(rpe)"
        }
        return summary
    }
}

// MARK: - Program Cycling Extension
extension WorkoutProgram {
    /// Get the next template in rotation after a given template
    func nextTemplate(after template: WorkoutTemplate?) -> WorkoutTemplate? {
        let ordered = orderedTemplates
        guard !ordered.isEmpty else { return nil }
        
        guard let current = template,
              let currentIndex = ordered.firstIndex(where: { $0.id == current.id }) else {
            return ordered.first
        }
        
        let nextIndex = (currentIndex + 1) % ordered.count
        return ordered[nextIndex]
    }
}
