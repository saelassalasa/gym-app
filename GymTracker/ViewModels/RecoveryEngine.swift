import Foundation
import SwiftData

// ═══════════════════════════════════════════════════════════════════════════
// RECOVERY ENGINE
// Banister Fitness-Fatigue model for per-muscle-group SRA tracking.
// Stateless: computes recovery from workout history on demand.
// ═══════════════════════════════════════════════════════════════════════════

enum RecoveryPhase: String {
    case fatigued     = "FATIGUED"
    case recovering   = "RECOVERING"
    case ready        = "READY"
    case atrophyRisk  = "ATROPHY RISK"
}

struct FatigueEvent {
    let muscle: MuscleGroup
    let sets: Int
    let rpe: Double
    let isCompound: Bool
    let date: Date
}

struct MuscleStatus: Identifiable {
    let muscle: MuscleGroup
    let recoveryPercent: Double
    let hoursUntilReady: Double
    let phase: RecoveryPhase

    var id: String { muscle.id }
}

enum RecoveryEngine {

    // MARK: - Multipliers (evidence-based)

    static func rpeMultiplier(_ rpe: Double) -> Double {
        switch rpe {
        case ..<6.5: return 0.85
        case ..<7.5: return 0.90
        case ..<8.5: return 1.00
        case ..<9.5: return 1.15
        default:     return 1.35
        }
    }

    static func volumeMultiplier(_ sets: Int) -> Double {
        guard sets > 0 else { return 0 }
        return 1.0 + 0.12 * log(Double(sets) / 6.0)
    }

    static func typeMultiplier(_ isCompound: Bool) -> Double {
        isCompound ? 1.20 : 0.85
    }

    /// Effective recovery hours for a single fatigue event
    static func effectiveRecoveryHours(_ event: FatigueEvent) -> Double {
        event.muscle.baseRecoveryHours
            * volumeMultiplier(event.sets)
            * rpeMultiplier(event.rpe)
            * typeMultiplier(event.isCompound)
    }

    // MARK: - Core Math

    /// Exponential fatigue decay
    static func fatigueRemaining(tau: Double, hoursElapsed: Double) -> Double {
        exp(-hoursElapsed / (tau * 24.0))
    }

    // MARK: - Public API

    /// Get current recovery status for all muscle groups
    static func status(
        for muscles: [MuscleGroup] = MuscleGroup.allCases,
        events: [FatigueEvent],
        now: Date = Date()
    ) -> [MuscleStatus] {
        muscles.map { muscle in
            let relevant = events.filter { $0.muscle == muscle }

            // If no events for this muscle, check if it's atrophy risk
            if relevant.isEmpty {
                return MuscleStatus(
                    muscle: muscle,
                    recoveryPercent: 1.0,
                    hoursUntilReady: 0,
                    phase: .atrophyRisk
                )
            }

            var totalFatigue = 0.0

            for event in relevant {
                let hours = now.timeIntervalSince(event.date) / 3600.0
                guard hours > 0 else { continue }
                let recoveryHours = effectiveRecoveryHours(event)
                let magnitude = recoveryHours / muscle.baseRecoveryHours
                let remaining = magnitude * fatigueRemaining(
                    tau: muscle.fatigueTau, hoursElapsed: hours
                )
                totalFatigue += remaining
            }

            let recoveryPercent = min(1.0, max(0, 1.0 - totalFatigue))

            // Check for atrophy risk: most recent event is older than 5 days
            let mostRecent = relevant.map(\.date).max() ?? .distantPast
            let hoursSinceLast = now.timeIntervalSince(mostRecent) / 3600.0

            let phase: RecoveryPhase
            if hoursSinceLast > 120 { // 5+ days since last training
                phase = .atrophyRisk
            } else if recoveryPercent < 0.80 {
                phase = .fatigued
            } else if recoveryPercent < 0.95 {
                phase = .recovering
            } else {
                phase = .ready
            }

            let hoursUntilReady: Double
            if recoveryPercent >= 0.90 {
                hoursUntilReady = 0
            } else {
                let currentFatigue = 1.0 - recoveryPercent
                let targetFatigue = 0.10
                hoursUntilReady = muscle.fatigueTau * 24.0
                    * log(currentFatigue / targetFatigue)
            }

            return MuscleStatus(
                muscle: muscle,
                recoveryPercent: recoveryPercent,
                hoursUntilReady: max(0, hoursUntilReady),
                phase: phase
            )
        }
    }

    // MARK: - Extract Events from Session

    /// Convert a completed WorkoutSession into FatigueEvents
    static func extractEvents(from session: WorkoutSession) -> [FatigueEvent] {
        guard let sets = session.sets else { return [] }

        var grouped: [UUID: (exercise: Exercise, sets: [WorkoutSet])] = [:]
        for set in sets where set.isCompleted && !set.isSkipped {
            guard let ex = set.exercise else { continue }
            grouped[ex.id, default: (ex, [])].sets.append(set)
        }

        return grouped.values.compactMap { exercise, sets in
            let rpes = sets.compactMap(\.rpe).map(Double.init)
            let avgRPE = rpes.isEmpty ? 8.0 : rpes.reduce(0, +) / Double(rpes.count)
            return FatigueEvent(
                muscle: exercise.resolvedPrimaryMuscle,
                sets: sets.count,
                rpe: avgRPE,
                isCompound: exercise.resolvedExerciseType == .compound,
                date: session.date
            )
        }
    }

    /// Extract all fatigue events from recent sessions (last 14 days)
    static func extractRecentEvents(context: ModelContext) -> [FatigueEvent] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { session in
                session.isCompleted && session.date > cutoff
            }
        )
        let sessions = (try? context.fetch(descriptor)) ?? []
        return sessions.flatMap { extractEvents(from: $0) }
    }
}
