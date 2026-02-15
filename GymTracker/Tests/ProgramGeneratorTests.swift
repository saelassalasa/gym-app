import XCTest
import SwiftData
@testable import GymTracker

@MainActor
final class ProgramGeneratorTests: XCTestCase {

    // MARK: - Logic Tests: Prescription Output

    func testHighIntensityPrescription_CompoundExercise() {
        let exercise = Exercise(name: "Squat", category: .legs, exerciseType: .compound, primaryMuscle: .quads)
        let rx = ProgramGenerator.prescribe(exercise: exercise, style: .highIntensity)

        XCTAssertEqual(rx.sets, 2, "HIT should prescribe 2 working sets")
        XCTAssertEqual(rx.repMin, 5, "HIT rep range should start at 5")
        XCTAssertEqual(rx.repMax, 8, "HIT rep range should end at 8")
        XCTAssertEqual(rx.rpe, 10, "HIT should prescribe RPE 10 (failure)")
        XCTAssertEqual(rx.restSeconds, 150, "HIT rest should be 150s")
    }

    func testHighIntensityPrescription_AccessoryExercise() {
        let exercise = Exercise(name: "Bicep Curl", category: .pull, exerciseType: .accessory, primaryMuscle: .biceps)
        let rx = ProgramGenerator.prescribe(exercise: exercise, style: .highIntensity)

        // HIT treats all exercises the same — no compound/accessory split
        XCTAssertEqual(rx.sets, 2)
        XCTAssertEqual(rx.rpe, 10)
    }

    func testHypertrophyVolumePrescription_Compound() {
        let exercise = Exercise(name: "Bench Press", category: .push, exerciseType: .compound, primaryMuscle: .chest)
        let rx = ProgramGenerator.prescribe(exercise: exercise, style: .hypertrophyVolume)

        XCTAssertEqual(rx.sets, 3, "Hypertrophy should prescribe 3 working sets")
        XCTAssertEqual(rx.repMin, 8)
        XCTAssertEqual(rx.repMax, 12)
        XCTAssertEqual(rx.rpe, 8, "Hypertrophy should prescribe RPE 8 (2 RIR)")
        XCTAssertEqual(rx.restSeconds, 150, "Compound rest should be 150s")
    }

    func testHypertrophyVolumePrescription_Accessory() {
        let exercise = Exercise(name: "Lateral Raise", category: .push, exerciseType: .accessory, primaryMuscle: .shoulders)
        let rx = ProgramGenerator.prescribe(exercise: exercise, style: .hypertrophyVolume)

        XCTAssertEqual(rx.restSeconds, 90, "Accessory rest should be 90s")
    }

    func testPowerbuildingPrescription_Compound() {
        let exercise = Exercise(name: "Deadlift", category: .pull, exerciseType: .compound, primaryMuscle: .back)
        let rx = ProgramGenerator.prescribe(exercise: exercise, style: .powerbuilding)

        XCTAssertEqual(rx.sets, 4, "Powerbuilding compounds: 4 sets")
        XCTAssertEqual(rx.repMin, 3, "Powerbuilding compounds: 3-5 reps")
        XCTAssertEqual(rx.repMax, 5)
        XCTAssertEqual(rx.rpe, 9, "Powerbuilding compounds: RPE 9")
        XCTAssertEqual(rx.restSeconds, 180, "Powerbuilding compounds: 180s rest")
    }

    func testPowerbuildingPrescription_Accessory() {
        let exercise = Exercise(name: "Tricep Pushdown", category: .push, exerciseType: .accessory, primaryMuscle: .triceps)
        let rx = ProgramGenerator.prescribe(exercise: exercise, style: .powerbuilding)

        XCTAssertEqual(rx.sets, 3, "Powerbuilding accessories: 3 sets")
        XCTAssertEqual(rx.repMin, 8)
        XCTAssertEqual(rx.repMax, 12)
        XCTAssertEqual(rx.rpe, 7, "Powerbuilding accessories: RPE 7")
        XCTAssertEqual(rx.restSeconds, 90)
    }

    // MARK: - SwiftData Integration: Save Path

    func testGenerateAndSaveTemplate() throws {
        // Create an in-memory SwiftData container
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Exercise.self, WorkoutTemplate.self, WorkoutSession.self, WorkoutSet.self, WorkoutProgram.self,
            configurations: config
        )
        let context = container.mainContext

        // Create exercises (NOT inserted — mimics GeneratorAddExerciseSheet)
        let squat = Exercise(name: "Squat", category: .legs, exerciseType: .compound, primaryMuscle: .quads, currentWeight: 100)
        let curl = Exercise(name: "Curl", category: .pull, exerciseType: .accessory, primaryMuscle: .biceps, currentWeight: 20)

        let exercises = [squat, curl]

        // Apply prescriptions (mimics generate())
        for exercise in exercises {
            let rx = ProgramGenerator.prescribe(exercise: exercise, style: .highIntensity)
            exercise.targetSets = rx.sets
            exercise.targetReps = rx.repMax
            exercise.restSeconds = rx.restSeconds
        }

        // Insert ONLY the template — SwiftData manages the exercises
        let template = WorkoutTemplate(name: "Test HIT", dayIndex: 0, exercises: exercises)
        context.insert(template)
        try context.save()

        // Verify the template was saved correctly
        let descriptor = FetchDescriptor<WorkoutTemplate>()
        let fetched = try context.fetch(descriptor)
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.name, "Test HIT")
        XCTAssertEqual(fetched.first?.exercises.count, 2)

        // Verify prescriptions were applied
        let savedSquat = fetched.first?.exercises.first { $0.name == "Squat" }
        XCTAssertEqual(savedSquat?.targetSets, 2, "HIT: 2 sets")
        XCTAssertEqual(savedSquat?.targetReps, 8, "HIT: repMax = 8")
        XCTAssertEqual(savedSquat?.restSeconds, 150)

        // Verify exercises are fetchable independently
        let exDescriptor = FetchDescriptor<Exercise>()
        let fetchedExercises = try context.fetch(exDescriptor)
        XCTAssertEqual(fetchedExercises.count, 2, "Both exercises should be in the store")
    }

    func testDoubleInsertCausesNoIssue() throws {
        // This test documents that inserting exercises THEN template is redundant but shouldn't crash
        // If this test fails, the double-insert approach is dangerous
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Exercise.self, WorkoutTemplate.self, WorkoutSession.self, WorkoutSet.self, WorkoutProgram.self,
            configurations: config
        )
        let context = container.mainContext

        let exercise = Exercise(name: "Bench", category: .push, exerciseType: .compound, primaryMuscle: .chest)

        // Double insert: exercise first, then template containing it
        context.insert(exercise)
        let template = WorkoutTemplate(name: "Double Insert Test", exercises: [exercise])
        context.insert(template)

        // This is the critical line — does save crash?
        XCTAssertNoThrow(try context.save(), "Double insert should not crash on save")

        // Verify no duplicates
        let exDescriptor = FetchDescriptor<Exercise>()
        let fetchedExercises = try context.fetch(exDescriptor)
        XCTAssertEqual(fetchedExercises.count, 1, "Should not duplicate the exercise")
    }
}
