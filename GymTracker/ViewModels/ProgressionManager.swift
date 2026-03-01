import Foundation
import SwiftData

@MainActor class ProgressionManager {
    static let shared = ProgressionManager()
    
    private init() {}
    
    // MARK: - Next Workout Index (N-day cycling)
    
    /// Get the next workout index in an N-day program rotation
    /// Returns 0-based index: Day 1 = 0, Day 2 = 1, etc.
    func getNextWorkoutIndex(
        inProgram program: WorkoutProgram,
        recentSessions: [WorkoutSession]
    ) -> Int {
        guard let lastSession = recentSessions.first,
              let lastTemplate = lastSession.template,
              let lastIndex = program.orderedTemplates.firstIndex(where: { $0.id == lastTemplate.id }) else {
            return 0  // Start with Day 1
        }
        
        // Cycle: 0 → 1 → 2 → ... → N-1 → 0
        guard !program.orderedTemplates.isEmpty else { return 0 }
        return (lastIndex + 1) % program.orderedTemplates.count
    }
    
    /// Get the next template directly from a program
    func getNextTemplate(
        inProgram program: WorkoutProgram,
        recentSessions: [WorkoutSession]
    ) -> WorkoutTemplate? {
        let ordered = program.orderedTemplates
        guard !ordered.isEmpty else { return nil }
        
        let nextIndex = getNextWorkoutIndex(inProgram: program, recentSessions: recentSessions)
        return ordered.indices.contains(nextIndex) ? ordered[nextIndex] : ordered.first
    }
    
    // MARK: - Progression Logic
    
    // MARK: - Weight Caps

    private static let maxWeightCompound: Double = 500   // kg
    private static let maxWeightAccessory: Double = 200   // kg

    private func maxWeight(for exercise: Exercise) -> Double {
        exercise.exerciseType == .compound ? Self.maxWeightCompound : Self.maxWeightAccessory
    }

    /// Check success and increment weight for completed exercises.
    /// Applies deload (−10%) when majority of sets fail target reps.
    func checkAndIncrement(session: WorkoutSession) {
        guard !session.progressionApplied else { return }
        guard let template = session.template, let sets = session.sets else { return }

        for exercise in template.exercises {
            // Fix 4: Skip core/cardio — progression is nonsensical
            guard exercise.category != .core, exercise.category != .cardio else { continue }

            // Fix 5: Sort by setNumber before prefix check
            let exerciseSets = sets
                .filter { $0.exercise?.id == exercise.id }
                .sorted { $0.setNumber < $1.setNumber }

            // Check if we have enough sets
            guard exerciseSets.count >= exercise.targetSets else { continue }

            let relevantSets = Array(exerciseSets.prefix(exercise.targetSets))
            let successCount = relevantSets.filter { $0.reps >= exercise.targetReps && $0.isCompleted }.count
            let allSuccessful = successCount == relevantSets.count

            if allSuccessful {
                // Increment weight
                exercise.currentWeight += exercise.targetIncrement
            } else {
                // Fix 3: Deload — if majority of sets failed target reps, reduce by 10%
                let failedCount = relevantSets.count - successCount
                if failedCount > relevantSets.count / 2 {
                    exercise.currentWeight *= 0.9
                }
            }

            // Fix 1 + 2: Clamp weight to [0, maxWeight]
            exercise.currentWeight = min(max(0, exercise.currentWeight), maxWeight(for: exercise))
        }

        session.progressionApplied = true
    }
}
