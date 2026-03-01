import Foundation
import SwiftData

// ═══════════════════════════════════════════════════════════════════════════
// PR SERVICE
// Stateless detection of personal records. Compares by exercise name
// (case-insensitive) since exercises are duplicated across templates.
// ═══════════════════════════════════════════════════════════════════════════

enum PRType: Hashable {
    case weight
    case estimated1RM
}

enum PRService {

    // MARK: - Historical Bests

    /// Returns (maxWeight, maxEstimated1RM) across all completed non-skipped sets for the given exercise name.
    static func getHistoricalBests(exerciseName: String, context: ModelContext) -> (weight: Double, estimated1RM: Double) {
        let sets = fetchCompletedSets(exerciseName: exerciseName, context: context)
        let maxWeight = sets.map(\.weight).max() ?? 0
        let maxE1RM = sets.map(\.estimated1RM).max() ?? 0
        return (maxWeight, maxE1RM)
    }

    // MARK: - Live Detection (during workout)

    /// Compare a new set against all historical bests for the exercise.
    /// Call BEFORE inserting the new set so history doesn't include it.
    static func detectPRs(weight: Double, reps: Int, exerciseName: String, context: ModelContext) -> Set<PRType> {
        let bests = getHistoricalBests(exerciseName: exerciseName, context: context)
        var prs = Set<PRType>()

        if weight > bests.weight && weight > 0 {
            prs.insert(.weight)
        }

        let newE1RM = estimatedOneRM(weight: weight, reps: reps)
        if newE1RM > bests.estimated1RM && newE1RM > 0 {
            prs.insert(.estimated1RM)
        }

        return prs
    }

    // MARK: - Retrospective Detection (for completed sessions)

    /// Reconstruct which sets were PRs at the time they were logged.
    /// Compares only against sets from sessions with earlier dates.
    /// Tracks running bests so only the first record-breaking set per metric gets the badge.
    static func detectPRsForSession(_ session: WorkoutSession, context: ModelContext) -> [UUID: Set<PRType>] {
        guard let sessionSets = session.sets else { return [:] }

        let sessionDate = session.date
        var result: [UUID: Set<PRType>] = [:]

        // Group session sets by exercise name (lowercased)
        var exerciseGroups: [String: [WorkoutSet]] = [:]
        for set in sessionSets where set.isCompleted && !set.isSkipped {
            guard let name = set.exercise?.name.lowercased() else { continue }
            exerciseGroups[name, default: []].append(set)
        }

        for (_, sets) in exerciseGroups {
            // Use the original (title-cased) exercise name for the predicate query
            guard let originalName = sets.first?.exercise?.name else { continue }
            let allSets = fetchCompletedSets(exerciseName: originalName, context: context)

            // Historical bests = sets from sessions with earlier dates
            let historicalSets = allSets.filter { s in
                guard let sDate = s.session?.date else { return false }
                return sDate < sessionDate
            }

            var runningMaxWeight = historicalSets.map(\.weight).max() ?? 0
            var runningMaxE1RM = historicalSets.map(\.estimated1RM).max() ?? 0

            // Sort session sets by set number to process in order
            let sorted = sets.sorted { $0.setNumber < $1.setNumber }

            for set in sorted {
                var prs = Set<PRType>()

                if set.weight > runningMaxWeight && set.weight > 0 {
                    prs.insert(.weight)
                    runningMaxWeight = set.weight
                }

                let e1rm = set.estimated1RM
                if e1rm > runningMaxE1RM && e1rm > 0 {
                    prs.insert(.estimated1RM)
                    runningMaxE1RM = e1rm
                }

                if !prs.isEmpty {
                    result[set.id] = prs
                }
            }
        }

        return result
    }

    // MARK: - Private

    private static func fetchCompletedSets(exerciseName: String, context: ModelContext) -> [WorkoutSet] {
        let lowered = exerciseName.lowercased()
        let descriptor = FetchDescriptor<WorkoutSet>(
            predicate: #Predicate<WorkoutSet> { set in
                set.isCompleted && !set.isSkipped && set.exercise?.name == lowered
            }
        )
        // Try case-sensitive match first (fast path for normalized names)
        let exact = (try? context.fetch(descriptor)) ?? []
        if !exact.isEmpty { return exact }

        // Fallback: fetch all completed sets and filter case-insensitively
        let allDescriptor = FetchDescriptor<WorkoutSet>(
            predicate: #Predicate<WorkoutSet> { set in
                set.isCompleted && !set.isSkipped
            }
        )
        let all = (try? context.fetch(allDescriptor)) ?? []
        return all.filter { $0.exercise?.name.lowercased() == lowered }
    }

    /// Brzycki formula — matches GymModels.WorkoutSet.estimated1RM exactly
    private static func estimatedOneRM(weight: Double, reps: Int) -> Double {
        guard reps > 0, weight > 0 else { return 0 }
        if reps == 1 { return weight }
        guard reps < 37 else { return weight * 0.65 }
        return weight / (1.0278 - 0.0278 * Double(reps))
    }
}
