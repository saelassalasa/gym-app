import Foundation
import SwiftData

// MARK: - Supporting Types

struct PRSummary: Identifiable {
    let id = UUID()
    let exerciseName: String
    let types: Set<PRType>
    let weight: Double
    let estimated1RM: Double
}

struct RecoveryDelta: Identifiable {
    let id = UUID()
    let muscle: MuscleGroup
    let phaseBefore: RecoveryPhase
    let phaseAfter: RecoveryPhase
}

struct IntensityZone: Identifiable {
    let id = UUID()
    let label: String
    let count: Int
    let fraction: Double
}

// MARK: - ViewModel

@Observable
final class WorkoutSummaryViewModel {

    let session: WorkoutSession
    let prResults: [UUID: Set<PRType>]
    private let context: ModelContext

    // Computed results
    var effectivePercent: Double = 0
    var effectiveSets: Int = 0
    var totalSets: Int = 0

    var intensityZones: [IntensityZone] = []
    var sessionDensity: Double = 0 // kg/min

    var muscleVolumes: [MuscleGroup: Double] = [:]
    var recoveryDeltas: [RecoveryDelta] = []
    var prSummaries: [PRSummary] = []

    var durationFormatted: String = "0:00"
    var totalVolume: Double = 0

    init(session: WorkoutSession, prResults: [UUID: Set<PRType>], context: ModelContext) {
        self.session = session
        self.prResults = prResults
        self.context = context
        computeAll()
    }

    private func computeAll() {
        computeDuration()

        let sets = (session.sets ?? []).filter { $0.isCompleted && !$0.isSkipped }
        totalSets = sets.count
        guard totalSets > 0 else { return }

        computeEffectiveVolume(sets)
        computeIntensityDistribution(sets)
        computeSessionDensity(sets)
        computeMuscleVolumes(sets)
        computePRSummaries(sets)
        computeRecoveryDeltas()
    }

    // MARK: - Duration

    private func computeDuration() {
        let dur = session.duration
        let mins = Int(dur) / 60
        let secs = Int(dur) % 60
        durationFormatted = String(format: "%d:%02d", mins, secs)
    }

    // MARK: - Effective Volume Score

    private func computeEffectiveVolume(_ sets: [WorkoutSet]) {
        var effective = 0.0
        let setsWithRPE = sets.filter { ($0.rpe ?? 0) > 0 }
        for s in setsWithRPE {
            guard let rpeVal = s.rpe else { continue }
            let rpe = Double(rpeVal)
            if rpe >= 8 {
                effective += 1.0
            } else if rpe >= 6 {
                effective += 0.7
            } else {
                effective += 0.4
            }
        }
        let denominator = setsWithRPE.isEmpty ? 1.0 : Double(setsWithRPE.count)
        effectiveSets = Int(effective.rounded())
        effectivePercent = min(effective / denominator, 1.0)
    }

    // MARK: - Intensity Distribution

    private func computeIntensityDistribution(_ sets: [WorkoutSet]) {
        var warmup = 0, moderate = 0, hard = 0, maxEffort = 0, notLogged = 0
        for s in sets {
            guard let rpe = s.rpe, rpe > 0 else { notLogged += 1; continue }
            switch rpe {
            case ..<6:      warmup += 1
            case 6...7:     moderate += 1
            case 8...9:     hard += 1
            default:        maxEffort += 1
            }
        }
        let total = Double(sets.count)
        intensityZones = [
            IntensityZone(label: "WARM-UP", count: warmup, fraction: Double(warmup) / total),
            IntensityZone(label: "MODERATE", count: moderate, fraction: Double(moderate) / total),
            IntensityZone(label: "HARD", count: hard, fraction: Double(hard) / total),
            IntensityZone(label: "MAX", count: maxEffort, fraction: Double(maxEffort) / total),
            IntensityZone(label: "RPE NOT LOGGED", count: notLogged, fraction: Double(notLogged) / total),
        ]
    }

    // MARK: - Session Density

    private func computeSessionDensity(_ sets: [WorkoutSet]) {
        totalVolume = sets.reduce(0) { $0 + $1.weight * Double($1.reps) }
        let minutes = max(session.duration / 60.0, 1.0)
        sessionDensity = totalVolume / minutes
    }

    // MARK: - Muscle Volumes (for hologram heatmap)

    private func computeMuscleVolumes(_ sets: [WorkoutSet]) {
        muscleVolumes = BiomechanicsEngine.heatmap(from: sets)
    }

    // MARK: - PR Summaries

    private func computePRSummaries(_ sets: [WorkoutSet]) {
        // Group PR sets by exercise name
        var grouped: [String: (types: Set<PRType>, maxWeight: Double, maxE1RM: Double)] = [:]
        for s in sets {
            guard let types = prResults[s.id], let name = s.exercise?.name else { continue }
            var entry = grouped[name] ?? (Set(), 0, 0)
            entry.types.formUnion(types)
            entry.maxWeight = max(entry.maxWeight, s.weight)
            entry.maxE1RM = max(entry.maxE1RM, s.estimated1RM)
            grouped[name] = entry
        }
        prSummaries = grouped.map { name, data in
            PRSummary(exerciseName: name, types: data.types, weight: data.maxWeight, estimated1RM: data.maxE1RM)
        }.sorted { $0.exerciseName < $1.exerciseName }
    }

    // MARK: - Recovery Deltas

    private func computeRecoveryDeltas() {
        let allEvents = RecoveryEngine.extractRecentEvents(context: context)
        let sessionEvents = RecoveryEngine.extractEvents(from: session)
        let workedMuscles = Set(sessionEvents.map(\.muscle))
        guard !workedMuscles.isEmpty else { return }

        // "Before" = all events minus this session's
        let sessionDate = session.date
        let beforeEvents = allEvents.filter { event in
            !Calendar.current.isDate(event.date, inSameDayAs: sessionDate) ||
            !workedMuscles.contains(event.muscle)
        }

        let beforeStatuses = RecoveryEngine.status(for: Array(workedMuscles), events: beforeEvents)
        let afterStatuses = RecoveryEngine.status(for: Array(workedMuscles), events: allEvents)

        var deltas: [RecoveryDelta] = []
        for muscle in workedMuscles {
            let before = beforeStatuses.first(where: { $0.muscle == muscle })?.phase ?? .ready
            let after = afterStatuses.first(where: { $0.muscle == muscle })?.phase ?? .fatigued
            deltas.append(RecoveryDelta(muscle: muscle, phaseBefore: before, phaseAfter: after))
        }
        recoveryDeltas = deltas.sorted { $0.muscle.rawValue < $1.muscle.rawValue }
    }
}
