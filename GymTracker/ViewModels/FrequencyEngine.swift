import Foundation
import SwiftData

// ═══════════════════════════════════════════════════════════════════════════
// FREQUENCY ENGINE
// Evidence-based weekly training frequency tracker per muscle group.
// Stateless: computes frequency from workout history on demand.
//
// Science: Schoenfeld 2019, Pelland 2025, Israetel/Nippard practical recs.
// Default 2x/week per muscle (configurable). Min 4 sets/muscle/week.
// ═══════════════════════════════════════════════════════════════════════════

// MARK: - Data Structures

struct MuscleFrequencyTarget {
    let muscle: MuscleGroup
    let optimalFrequency: Int
    let minSetsPerWeek: Int
    let optimalSetsPerWeek: Int
}

struct MuscleFrequencyStatus: Identifiable {
    let muscle: MuscleGroup
    let sessionsThisWeek: Int
    let setsThisWeek: Int
    let optimalFrequency: Int
    let optimalSets: Int
    let verdict: FrequencyVerdict

    var id: String { muscle.id }
}

enum FrequencyVerdict: String {
    case undertrained = "UNDERTRAINED"
    case optimal      = "OPTIMAL"
    case overtrained  = "OVERTRAINED"
    case noData       = "NO DATA"
}

// MARK: - Engine

enum FrequencyEngine {

    // MARK: - UserDefaults Key

    private static let frequencyKey = "user_frequency_preference"

    /// User-configurable frequency (2 or 3). Defaults to 2.
    static var userPreferredFrequency: Int {
        get {
            let val = UserDefaults.standard.integer(forKey: frequencyKey)
            return val >= 2 && val <= 4 ? val : 2
        }
        set {
            UserDefaults.standard.set(max(2, min(4, newValue)), forKey: frequencyKey)
        }
    }

    // MARK: - Targets

    static func target(for muscle: MuscleGroup) -> MuscleFrequencyTarget {
        let freq = userPreferredFrequency

        switch muscle {
        case .chest, .back, .quads, .hamstrings, .glutes:
            return MuscleFrequencyTarget(
                muscle: muscle,
                optimalFrequency: freq,
                minSetsPerWeek: 4,
                optimalSetsPerWeek: freq == 2 ? 8 : 10
            )
        case .shoulders, .biceps, .triceps:
            return MuscleFrequencyTarget(
                muscle: muscle,
                optimalFrequency: freq,
                minSetsPerWeek: 4,
                optimalSetsPerWeek: freq == 2 ? 6 : 9
            )
        case .calves, .core:
            return MuscleFrequencyTarget(
                muscle: muscle,
                optimalFrequency: freq,
                minSetsPerWeek: 4,
                optimalSetsPerWeek: freq == 2 ? 8 : 10
            )
        }
    }

    // MARK: - Weekly Analysis

    @MainActor
    static func weeklyStatus(context: ModelContext, now: Date = Date()) -> [MuscleFrequencyStatus] {
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now) else {
            return MuscleGroup.allCases.map {
                MuscleFrequencyStatus(muscle: $0, sessionsThisWeek: 0, setsThisWeek: 0,
                                      optimalFrequency: target(for: $0).optimalFrequency,
                                      optimalSets: target(for: $0).optimalSetsPerWeek, verdict: .noData)
            }
        }
        let startOfWeek = weekInterval.start

        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { session in
                session.isCompleted && session.date >= startOfWeek
            }
        )
        let sessions = (try? context.fetch(descriptor)) ?? []

        var muscleSessionDays: [MuscleGroup: Set<Date>] = [:]
        var muscleSets: [MuscleGroup: Int] = [:]

        for session in sessions {
            guard let sets = session.sets else { continue }
            let sessionDay = calendar.startOfDay(for: session.date)

            var grouped: [MuscleGroup: Int] = [:]
            for set in sets where set.isCompleted && !set.isSkipped && set.setType != .warmup {
                guard let exercise = set.exercise else { continue }
                let muscle = exercise.resolvedPrimaryMuscle
                grouped[muscle, default: 0] += 1
            }

            for (muscle, setCount) in grouped {
                muscleSessionDays[muscle, default: []].insert(sessionDay)
                muscleSets[muscle, default: 0] += setCount
            }
        }

        return MuscleGroup.allCases.map { muscle in
            let sessionCount = muscleSessionDays[muscle]?.count ?? 0
            let setCount = muscleSets[muscle] ?? 0
            let t = target(for: muscle)

            let verdict: FrequencyVerdict
            if sessionCount == 0 && setCount == 0 {
                verdict = .noData
            } else if setCount < t.minSetsPerWeek || sessionCount < t.optimalFrequency {
                verdict = .undertrained
            } else if setCount > t.optimalSetsPerWeek * 2 {
                verdict = .overtrained
            } else {
                verdict = .optimal
            }

            return MuscleFrequencyStatus(
                muscle: muscle,
                sessionsThisWeek: sessionCount,
                setsThisWeek: setCount,
                optimalFrequency: t.optimalFrequency,
                optimalSets: t.optimalSetsPerWeek,
                verdict: verdict
            )
        }
    }

    // MARK: - Suggestions (Recovery-Aware)

    static func smartSuggestions(
        frequencyStatuses: [MuscleFrequencyStatus],
        recoveryStatuses: [MuscleStatus]
    ) -> [String] {
        var result: [String] = []

        for freq in frequencyStatuses {
            guard freq.verdict == .undertrained, freq.sessionsThisWeek > 0 else { continue }
            let recovery = recoveryStatuses.first { $0.muscle == freq.muscle }

            let remaining = freq.optimalFrequency - freq.sessionsThisWeek
            guard remaining > 0 else { continue }

            if let r = recovery, r.phase == .ready || r.phase == .atrophyRisk {
                result.append("\(freq.muscle.rawValue.uppercased()): READY + UNDERTRAINED (\(freq.sessionsThisWeek)/\(freq.optimalFrequency)x). TRAIN TODAY.")
            } else if let r = recovery, r.phase == .recovering {
                let hours = Int(r.hoursUntilReady)
                result.append("\(freq.muscle.rawValue.uppercased()): UNDERTRAINED (\(freq.sessionsThisWeek)/\(freq.optimalFrequency)x) BUT RECOVERING (\(hours)H).")
            } else {
                result.append("\(freq.muscle.rawValue.uppercased()): TRAINED \(freq.sessionsThisWeek)x, NEED \(remaining) MORE.")
            }
        }

        for freq in frequencyStatuses where freq.verdict == .overtrained {
            result.append("\(freq.muscle.rawValue.uppercased()): \(freq.setsThisWeek) SETS (>\(freq.optimalSets * 2)). REDUCE VOLUME.")
        }

        return result
    }
}
