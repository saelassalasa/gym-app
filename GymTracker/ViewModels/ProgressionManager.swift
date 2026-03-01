import Foundation
import SwiftData

class ProgressionManager {
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
    
    /// Check success and increment weight for completed exercises
    func checkAndIncrement(session: WorkoutSession) {
        guard !session.progressionApplied else { return }
        guard let template = session.template, let sets = session.sets else { return }
        
        for exercise in template.exercises {
            let exerciseSets = sets.filter { $0.exercise?.id == exercise.id }
            
            // Check if we have enough sets
            if exerciseSets.count >= exercise.targetSets {
                let relevantSets = exerciseSets.prefix(exercise.targetSets)
                let allSuccessful = relevantSets.allSatisfy { set in
                    set.reps >= exercise.targetReps && set.isCompleted
                }
                
                if allSuccessful {
                    // Increment Weight
                    exercise.currentWeight += exercise.targetIncrement
                }
            }
        }

        session.progressionApplied = true
    }
}
