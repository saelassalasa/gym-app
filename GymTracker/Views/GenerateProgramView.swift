import SwiftUI
import SwiftData

// ═══════════════════════════════════════════════════════════════════════════
// GENERATE PROGRAM VIEW
// Smart program generator backed by training style prescriptions.
// Pick exercises → pick style → preview → generate template.
// ═══════════════════════════════════════════════════════════════════════════

struct GenerateProgramView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var targetProgram: WorkoutProgram?

    @State private var templateName = ""
    @State private var style: TrainingStyle = .highIntensity
    @State private var exercises: [Exercise] = []
    @State private var showAddExercise = false

    var body: some View {
        NavigationStack {
            ZStack {
                Wire.Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    header

                    ScrollView {
                        VStack(spacing: Wire.Layout.gap) {
                            WireInput(label: "Template Name", value: $templateName)
                            stylePicker
                            styleInfo

                            if !exercises.isEmpty {
                                prescriptionPreview
                            }

                            exerciseList

                            WireButton("ADD EXERCISE") { showAddExercise = true }
                        }
                        .padding(Wire.Layout.pad)
                    }

                    generateButton
                }
            }
            .sheet(isPresented: $showAddExercise) {
                ExercisePickerSheet(exercises: $exercises)
            }
            .onAppear {
                if let program = targetProgram, templateName.isEmpty {
                    templateName = "DAY \(program.orderedTemplates.count + 1)"
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text(targetProgram != nil ? "ADD DAY TO \(targetProgram!.name.uppercased())" : "GENERATE")
                .font(Wire.Font.sub)
                .foregroundColor(Wire.Color.white)
                .kerning(2)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Spacer()
            Button("×") { dismiss() }
                .font(Wire.Font.header)
                .foregroundColor(Wire.Color.gray)
        }
        .padding(Wire.Layout.pad)
        .background(Wire.Color.black)
        .overlay(Rectangle().stroke(Wire.Color.white, lineWidth: Wire.Layout.border))
    }

    // MARK: - Style Picker

    private var stylePicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("TRAINING STYLE")
                .font(Wire.Font.caption)
                .foregroundColor(Wire.Color.gray)
                .kerning(1)

            VStack(spacing: 0) {
                ForEach(TrainingStyle.allCases) { s in
                    Button {
                        Wire.tap()
                        style = s
                    } label: {
                        HStack {
                            Text(s.rawValue)
                                .font(Wire.Font.body)
                                .foregroundColor(style == s ? Wire.Color.black : Wire.Color.white)
                                .kerning(1)

                            Spacer()

                            if style == s {
                                Text("●")
                                    .font(Wire.Font.body)
                                    .foregroundColor(Wire.Color.black)
                            }
                        }
                        .padding(Wire.Layout.pad)
                        .background(style == s ? Wire.Color.white : Wire.Color.black)
                        .overlay(Rectangle().stroke(Wire.Color.white, lineWidth: Wire.Layout.border))
                    }
                }
            }
        }
    }

    // MARK: - Style Info

    private var styleInfo: some View {
        WireCell {
            VStack(alignment: .leading, spacing: 4) {
                Text(style.subtitle)
                    .font(Wire.Font.caption)
                    .foregroundColor(Wire.Color.white)
                    .kerning(0.5)

                Text(styleDescription)
                    .font(Wire.Font.tiny)
                    .foregroundColor(Wire.Color.gray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var styleDescription: String {
        switch style {
        case .highIntensity:
            return "2 WORKING SETS × 5-8 REPS @ RPE 10 (FAILURE). MAX EFFICIENCY. LONGER RECOVERY PER MUSCLE."
        case .hypertrophyVolume:
            return "3 WORKING SETS × 8-12 REPS @ RPE 8 (2 RIR). VOLUME-DRIVEN GROWTH. MODERATE RECOVERY."
        case .powerbuilding:
            return "COMPOUNDS: 4×3-5 @ RPE 9. ACCESSORIES: 3×8-12 @ RPE 7. STRENGTH + SIZE."
        }
    }

    // MARK: - Prescription Preview

    private var prescriptionPreview: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("PRESCRIPTION")
                .font(Wire.Font.caption)
                .foregroundColor(Wire.Color.gray)
                .kerning(1)

            ForEach(exercises) { ex in
                let rx = ProgramGenerator.prescribe(exercise: ex, style: style)
                HStack {
                    Text(ex.name.uppercased())
                        .font(Wire.Font.caption)
                        .foregroundColor(Wire.Color.white)
                        .lineLimit(1)

                    Spacer()

                    Text("\(rx.sets)×\(rx.repMin)-\(rx.repMax)")
                        .font(Wire.Font.body)
                        .foregroundColor(Wire.Color.white)

                    Text("@\(rx.rpe)")
                        .font(Wire.Font.caption)
                        .foregroundColor(rx.rpe >= 10 ? Wire.Color.danger : Wire.Color.gray)

                    Text("\(rx.restSeconds)s")
                        .font(Wire.Font.tiny)
                        .foregroundColor(Wire.Color.gray)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, Wire.Layout.pad)
                .background(Wire.Color.black)
                .overlay(Rectangle().stroke(Wire.Color.dark, lineWidth: Wire.Layout.border))
            }
        }
    }

    // MARK: - Exercise List

    private var exerciseList: some View {
        VStack(spacing: 4) {
            if !exercises.isEmpty {
                Text("EXERCISES [\(exercises.count)]")
                    .font(Wire.Font.caption)
                    .foregroundColor(Wire.Color.gray)
                    .kerning(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            ForEach(exercises) { ex in
                VStack(spacing: 0) {
                    HStack {
                        Text(ex.resolvedExerciseType == .compound ? "C" : "A")
                            .font(Wire.Font.tiny)
                            .foregroundColor(Wire.Color.black)
                            .frame(width: 16, height: 16)
                            .background(Wire.Color.white)

                        Text(ex.name.uppercased())
                            .font(Wire.Font.body)
                            .foregroundColor(Wire.Color.white)
                            .lineLimit(1)

                        Spacer()

                        Text(ex.resolvedPrimaryMuscle.rawValue.uppercased())
                            .font(Wire.Font.tiny)
                            .foregroundColor(Wire.Color.gray)

                        Button("×") {
                            Wire.tap()
                            exercises.removeAll { $0.id == ex.id }
                        }
                        .font(Wire.Font.header)
                        .foregroundColor(Wire.Color.danger)
                        .padding(.leading, 8)
                    }

                    // Inline weight editor
                    HStack(spacing: Wire.Layout.gap) {
                        Text("WEIGHT")
                            .font(Wire.Font.tiny)
                            .foregroundColor(Wire.Color.gray)
                            .kerning(1)

                        Spacer()

                        HStack(spacing: 0) {
                            Button {
                                Wire.tap()
                                ex.currentWeight = max(0, ex.currentWeight - 2.5)
                            } label: {
                                Text("−")
                                    .font(Wire.Font.body)
                                    .foregroundColor(Wire.Color.white)
                                    .frame(width: 32, height: 32)
                                    .background(Wire.Color.black)
                                    .overlay(Rectangle().stroke(Wire.Color.white, lineWidth: Wire.Layout.border))
                            }

                            TextField("", value: Binding(
                                get: { ex.currentWeight },
                                set: { ex.currentWeight = max(0, min(500, $0)) }
                            ), format: .number)
                                .font(Wire.Font.body)
                                .foregroundColor(Wire.Color.white)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.center)
                                .frame(width: 56, height: 32)
                                .background(Wire.Color.black)
                                .overlay(Rectangle().stroke(Wire.Color.white, lineWidth: Wire.Layout.border))

                            Button {
                                Wire.tap()
                                ex.currentWeight = min(500, ex.currentWeight + 2.5)
                            } label: {
                                Text("+")
                                    .font(Wire.Font.body)
                                    .foregroundColor(Wire.Color.white)
                                    .frame(width: 32, height: 32)
                                    .background(Wire.Color.black)
                                    .overlay(Rectangle().stroke(Wire.Color.white, lineWidth: Wire.Layout.border))
                            }
                        }

                        Text("KG")
                            .font(Wire.Font.tiny)
                            .foregroundColor(Wire.Color.gray)
                    }
                    .padding(.top, Wire.Layout.gap)
                }
                .padding(Wire.Layout.pad)
                .background(Wire.Color.black)
                .overlay(Rectangle().stroke(Wire.Color.dark, lineWidth: Wire.Layout.border))
            }
        }
    }

    // MARK: - Generate Button

    private var generateButton: some View {
        WireButton("GENERATE", inverted: isValid) {
            generate()
        }
        .padding(Wire.Layout.pad)
        .disabled(!isValid)
    }

    private var isValid: Bool {
        !templateName.isEmpty && !exercises.isEmpty
    }

    private func generate() {
        Wire.success()

        // Apply prescriptions to exercises
        for exercise in exercises {
            let rx = ProgramGenerator.prescribe(exercise: exercise, style: style)
            exercise.targetSets = rx.sets
            exercise.targetReps = rx.repMax
            exercise.restSeconds = rx.restSeconds
        }

        if let program = targetProgram {
            // Add day to existing program
            let nextIndex = program.orderedTemplates.count
            let template = WorkoutTemplate(name: templateName, dayIndex: nextIndex, exercises: exercises)
            template.program = program
            modelContext.insert(template)
        } else {
            // Create template and wrap in a program so it shows on the Dashboard.
            // Dashboard queries WorkoutProgram, not standalone templates.
            let template = WorkoutTemplate(name: templateName, dayIndex: 0, exercises: exercises)
            let program = WorkoutProgram(name: templateName)
            template.program = program
            modelContext.insert(program)
            modelContext.insert(template)
        }

        modelContext.saveSafe()
        dismiss()
    }
}
