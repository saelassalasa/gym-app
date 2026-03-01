import Foundation

// ═══════════════════════════════════════════════════════════════════════════
// EXERCISE LIBRARY
// Built-in exercise registry with pre-set metadata.
// NOT a SwiftData model — pure value type for the picker UI.
// ═══════════════════════════════════════════════════════════════════════════

struct ExerciseTemplate: Identifiable {
    let id = UUID()
    let name: String
    let category: ExerciseCategory
    let exerciseType: ExerciseType
    let primaryMuscle: MuscleGroup
}

enum ExerciseLibrary {

    // MARK: - API

    static func search(_ query: String) -> [ExerciseTemplate] {
        guard !query.isEmpty else { return all }
        let q = query.lowercased()
        return all.filter { $0.name.lowercased().contains(q) }
    }

    static func filter(
        query: String = "",
        categories: Set<ExerciseCategory> = [],
        muscles: Set<MuscleGroup> = []
    ) -> [ExerciseTemplate] {
        var results = query.isEmpty ? all : search(query)
        if !categories.isEmpty {
            results = results.filter { categories.contains($0.category) }
        }
        if !muscles.isEmpty {
            results = results.filter { muscles.contains($0.primaryMuscle) }
        }
        return results
    }

    // MARK: - Full Registry

    static let all: [ExerciseTemplate] = push + pull + legs + core

    // ═══════════════════════════════════════════════════════════════════
    // PUSH — Chest, Shoulders, Triceps
    // ═══════════════════════════════════════════════════════════════════

    private static let push: [ExerciseTemplate] = [
        // Chest — Compound
        .init(name: "Bench Press", category: .push, exerciseType: .compound, primaryMuscle: .chest),
        .init(name: "Incline Bench Press", category: .push, exerciseType: .compound, primaryMuscle: .chest),
        .init(name: "Decline Bench Press", category: .push, exerciseType: .compound, primaryMuscle: .chest),
        .init(name: "Dumbbell Bench Press", category: .push, exerciseType: .compound, primaryMuscle: .chest),
        .init(name: "Incline Dumbbell Press", category: .push, exerciseType: .compound, primaryMuscle: .chest),
        .init(name: "Close Grip Bench Press", category: .push, exerciseType: .compound, primaryMuscle: .chest),
        .init(name: "Floor Press", category: .push, exerciseType: .compound, primaryMuscle: .chest),
        .init(name: "Dips", category: .push, exerciseType: .compound, primaryMuscle: .chest),

        // Chest — Accessory
        .init(name: "Cable Fly", category: .push, exerciseType: .accessory, primaryMuscle: .chest),
        .init(name: "Incline Dumbbell Fly", category: .push, exerciseType: .accessory, primaryMuscle: .chest),
        .init(name: "Pec Deck", category: .push, exerciseType: .accessory, primaryMuscle: .chest),
        .init(name: "Cable Crossover", category: .push, exerciseType: .accessory, primaryMuscle: .chest),

        // Shoulders — Compound
        .init(name: "Overhead Press", category: .push, exerciseType: .compound, primaryMuscle: .shoulders),
        .init(name: "Seated Dumbbell Press", category: .push, exerciseType: .compound, primaryMuscle: .shoulders),
        .init(name: "Arnold Press", category: .push, exerciseType: .compound, primaryMuscle: .shoulders),
        .init(name: "Push Press", category: .push, exerciseType: .compound, primaryMuscle: .shoulders),
        .init(name: "Landmine Press", category: .push, exerciseType: .compound, primaryMuscle: .shoulders),
        .init(name: "Z Press", category: .push, exerciseType: .compound, primaryMuscle: .shoulders),

        // Shoulders — Accessory
        .init(name: "Lateral Raise", category: .push, exerciseType: .accessory, primaryMuscle: .shoulders),
        .init(name: "Cable Lateral Raise", category: .push, exerciseType: .accessory, primaryMuscle: .shoulders),
        .init(name: "Front Raise", category: .push, exerciseType: .accessory, primaryMuscle: .shoulders),
        .init(name: "Reverse Pec Deck", category: .push, exerciseType: .accessory, primaryMuscle: .shoulders),
        .init(name: "Lu Raise", category: .push, exerciseType: .accessory, primaryMuscle: .shoulders),

        // Triceps — Accessory
        .init(name: "Tricep Pushdown", category: .push, exerciseType: .accessory, primaryMuscle: .triceps),
        .init(name: "Overhead Tricep Extension", category: .push, exerciseType: .accessory, primaryMuscle: .triceps),
        .init(name: "Skull Crusher", category: .push, exerciseType: .accessory, primaryMuscle: .triceps),
        .init(name: "Cable Tricep Kickback", category: .push, exerciseType: .accessory, primaryMuscle: .triceps),
        .init(name: "JM Press", category: .push, exerciseType: .accessory, primaryMuscle: .triceps),
    ]

    // ═══════════════════════════════════════════════════════════════════
    // PULL — Back, Biceps
    // ═══════════════════════════════════════════════════════════════════

    private static let pull: [ExerciseTemplate] = [
        // Back — Compound
        .init(name: "Barbell Row", category: .pull, exerciseType: .compound, primaryMuscle: .back),
        .init(name: "Pendlay Row", category: .pull, exerciseType: .compound, primaryMuscle: .back),
        .init(name: "Dumbbell Row", category: .pull, exerciseType: .compound, primaryMuscle: .back),
        .init(name: "Seal Row", category: .pull, exerciseType: .compound, primaryMuscle: .back),
        .init(name: "T-Bar Row", category: .pull, exerciseType: .compound, primaryMuscle: .back),
        .init(name: "Cable Row", category: .pull, exerciseType: .compound, primaryMuscle: .back),
        .init(name: "Lat Pulldown", category: .pull, exerciseType: .compound, primaryMuscle: .back),
        .init(name: "Pull Up", category: .pull, exerciseType: .compound, primaryMuscle: .back),
        .init(name: "Chin Up", category: .pull, exerciseType: .compound, primaryMuscle: .back),
        .init(name: "Meadows Row", category: .pull, exerciseType: .compound, primaryMuscle: .back),
        .init(name: "Chest Supported Row", category: .pull, exerciseType: .compound, primaryMuscle: .back),
        .init(name: "Helms Row", category: .pull, exerciseType: .compound, primaryMuscle: .back),

        // Back — Accessory
        .init(name: "Face Pull", category: .pull, exerciseType: .accessory, primaryMuscle: .shoulders),
        .init(name: "Reverse Fly", category: .pull, exerciseType: .accessory, primaryMuscle: .shoulders),
        .init(name: "Straight Arm Pulldown", category: .pull, exerciseType: .accessory, primaryMuscle: .back),
        .init(name: "Pullover", category: .pull, exerciseType: .accessory, primaryMuscle: .back),
        .init(name: "Shrug", category: .pull, exerciseType: .accessory, primaryMuscle: .back),
        .init(name: "Barbell Shrug", category: .pull, exerciseType: .accessory, primaryMuscle: .back),

        // Biceps — Accessory
        .init(name: "Barbell Curl", category: .pull, exerciseType: .accessory, primaryMuscle: .biceps),
        .init(name: "Dumbbell Curl", category: .pull, exerciseType: .accessory, primaryMuscle: .biceps),
        .init(name: "Hammer Curl", category: .pull, exerciseType: .accessory, primaryMuscle: .biceps),
        .init(name: "Incline Curl", category: .pull, exerciseType: .accessory, primaryMuscle: .biceps),
        .init(name: "Preacher Curl", category: .pull, exerciseType: .accessory, primaryMuscle: .biceps),
        .init(name: "Cable Curl", category: .pull, exerciseType: .accessory, primaryMuscle: .biceps),
        .init(name: "Spider Curl", category: .pull, exerciseType: .accessory, primaryMuscle: .biceps),
        .init(name: "Bayesian Curl", category: .pull, exerciseType: .accessory, primaryMuscle: .biceps),
    ]

    // ═══════════════════════════════════════════════════════════════════
    // LEGS — Quads, Hamstrings, Glutes, Calves
    // ═══════════════════════════════════════════════════════════════════

    private static let legs: [ExerciseTemplate] = [
        // Quads — Compound
        .init(name: "Squat", category: .legs, exerciseType: .compound, primaryMuscle: .quads),
        .init(name: "Front Squat", category: .legs, exerciseType: .compound, primaryMuscle: .quads),
        .init(name: "Hack Squat", category: .legs, exerciseType: .compound, primaryMuscle: .quads),
        .init(name: "Leg Press", category: .legs, exerciseType: .compound, primaryMuscle: .quads),
        .init(name: "Bulgarian Split Squat", category: .legs, exerciseType: .compound, primaryMuscle: .quads),
        .init(name: "Goblet Squat", category: .legs, exerciseType: .compound, primaryMuscle: .quads),
        .init(name: "Walking Lunge", category: .legs, exerciseType: .compound, primaryMuscle: .quads),
        .init(name: "Sissy Squat", category: .legs, exerciseType: .compound, primaryMuscle: .quads),
        .init(name: "Pendulum Squat", category: .legs, exerciseType: .compound, primaryMuscle: .quads),

        // Quads — Accessory
        .init(name: "Leg Extension", category: .legs, exerciseType: .accessory, primaryMuscle: .quads),

        // Hamstrings — Compound
        .init(name: "Romanian Deadlift", category: .legs, exerciseType: .compound, primaryMuscle: .hamstrings),
        .init(name: "Stiff Leg Deadlift", category: .legs, exerciseType: .compound, primaryMuscle: .hamstrings),
        .init(name: "Good Morning", category: .legs, exerciseType: .compound, primaryMuscle: .hamstrings),

        // Hamstrings — Accessory
        .init(name: "Lying Leg Curl", category: .legs, exerciseType: .accessory, primaryMuscle: .hamstrings),
        .init(name: "Seated Leg Curl", category: .legs, exerciseType: .accessory, primaryMuscle: .hamstrings),
        .init(name: "Nordic Curl", category: .legs, exerciseType: .accessory, primaryMuscle: .hamstrings),

        // Glutes — Compound
        .init(name: "Deadlift", category: .legs, exerciseType: .compound, primaryMuscle: .glutes),
        .init(name: "Sumo Deadlift", category: .legs, exerciseType: .compound, primaryMuscle: .glutes),
        .init(name: "Deficit Deadlift", category: .legs, exerciseType: .compound, primaryMuscle: .glutes),
        .init(name: "Hip Thrust", category: .legs, exerciseType: .compound, primaryMuscle: .glutes),
        .init(name: "Barbell Hip Thrust", category: .legs, exerciseType: .compound, primaryMuscle: .glutes),
        .init(name: "Glute Bridge", category: .legs, exerciseType: .accessory, primaryMuscle: .glutes),

        // Glutes — Accessory
        .init(name: "Cable Glute Kickback", category: .legs, exerciseType: .accessory, primaryMuscle: .glutes),
        .init(name: "Hip Abduction", category: .legs, exerciseType: .accessory, primaryMuscle: .glutes),

        // Calves
        .init(name: "Standing Calf Raise", category: .legs, exerciseType: .accessory, primaryMuscle: .calves),
        .init(name: "Seated Calf Raise", category: .legs, exerciseType: .accessory, primaryMuscle: .calves),
        .init(name: "Leg Press Calf Raise", category: .legs, exerciseType: .accessory, primaryMuscle: .calves),
    ]

    // ═══════════════════════════════════════════════════════════════════
    // CORE
    // ═══════════════════════════════════════════════════════════════════

    private static let core: [ExerciseTemplate] = [
        .init(name: "Plank", category: .core, exerciseType: .accessory, primaryMuscle: .core),
        .init(name: "Ab Wheel Rollout", category: .core, exerciseType: .accessory, primaryMuscle: .core),
        .init(name: "Hanging Leg Raise", category: .core, exerciseType: .accessory, primaryMuscle: .core),
        .init(name: "Cable Crunch", category: .core, exerciseType: .accessory, primaryMuscle: .core),
        .init(name: "Cable Woodchop", category: .core, exerciseType: .accessory, primaryMuscle: .core),
        .init(name: "Pallof Press", category: .core, exerciseType: .accessory, primaryMuscle: .core),
        .init(name: "Decline Crunch", category: .core, exerciseType: .accessory, primaryMuscle: .core),
        .init(name: "Russian Twist", category: .core, exerciseType: .accessory, primaryMuscle: .core),
        .init(name: "Dead Bug", category: .core, exerciseType: .accessory, primaryMuscle: .core),
        .init(name: "Copenhagen Plank", category: .core, exerciseType: .accessory, primaryMuscle: .core),
    ]
}
