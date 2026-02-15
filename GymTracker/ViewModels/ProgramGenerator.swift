import Foundation

// ═══════════════════════════════════════════════════════════════════════════
// TRAINING STYLE
// Each style encodes a training philosophy backed by sports science.
// ═══════════════════════════════════════════════════════════════════════════

enum TrainingStyle: String, Codable, CaseIterable, Identifiable {
    case highIntensity     = "HIGH INTENSITY"
    case hypertrophyVolume = "HYPERTROPHY"
    case powerbuilding     = "POWERBUILDING"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .highIntensity:     return "MENTZER / YATES — 1-2 SETS TO FAILURE"
        case .hypertrophyVolume: return "RP / ISRAETEL — VOLUME LANDMARKS"
        case .powerbuilding:     return "HEAVY COMPOUNDS + VOLUME ACCESSORIES"
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// SET PRESCRIPTION — What the generator outputs per exercise
// ═══════════════════════════════════════════════════════════════════════════

struct SetPrescription {
    let sets: Int
    let repMin: Int
    let repMax: Int
    let rpe: Int
    let restSeconds: Int
}

// ═══════════════════════════════════════════════════════════════════════════
// PROGRAM GENERATOR — Stateless engine
// Takes exercises + style, returns configured WorkoutTemplate.
// ═══════════════════════════════════════════════════════════════════════════

enum ProgramGenerator {

    static func prescribe(
        exercise: Exercise,
        style: TrainingStyle
    ) -> SetPrescription {
        switch style {
        case .highIntensity:
            // Mentzer/Yates: 2 all-out sets, 5-8 reps, RPE 10, moderate rest
            return SetPrescription(
                sets: 2, repMin: 5, repMax: 8, rpe: 10,
                restSeconds: 150
            )

        case .hypertrophyVolume:
            // Israetel/RP: 3 sets, 8-12 reps, RPE 8
            return SetPrescription(
                sets: 3, repMin: 8, repMax: 12, rpe: 8,
                restSeconds: exercise.exerciseType == .compound ? 150 : 90
            )

        case .powerbuilding:
            if exercise.exerciseType == .compound {
                // Heavy strength: 4×3-5 @RPE 9, long rest
                return SetPrescription(
                    sets: 4, repMin: 3, repMax: 5, rpe: 9,
                    restSeconds: 180
                )
            } else {
                // Volume accessories: 3×8-12 @RPE 7, short rest
                return SetPrescription(
                    sets: 3, repMin: 8, repMax: 12, rpe: 7,
                    restSeconds: 90
                )
            }
        }
    }

    /// Generate a full template from selected exercises + style
    static func generate(
        name: String,
        exercises: [Exercise],
        style: TrainingStyle,
        dayIndex: Int = 0
    ) -> WorkoutTemplate {
        for exercise in exercises {
            let rx = prescribe(exercise: exercise, style: style)
            exercise.targetSets = rx.sets
            exercise.targetReps = rx.repMax
            exercise.restSeconds = rx.restSeconds
        }
        return WorkoutTemplate(
            name: name,
            dayIndex: dayIndex,
            exercises: exercises
        )
    }
}
