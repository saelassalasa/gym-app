import SwiftUI
import SwiftData

// ═══════════════════════════════════════════════════════════════════════════
// PROGRAM SETUP VIEW
// Dynamic N-day split program configuration (1-7 days)
// ═══════════════════════════════════════════════════════════════════════════

struct ProgramSetupView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // Program Configuration
    @State private var programName: String = ""
    @State private var days: [WorkoutDay] = [WorkoutDay(name: "DAY 1")]
    @State private var selectedDayIndex: Int = 0
    @State private var showAddExercise = false
    
    // Max 7 days allowed
    private let maxDays = 7

    // Safe binding that guards against out-of-bounds access
    private var safeDayExercisesBinding: Binding<[Exercise]> {
        Binding(
            get: { days.indices.contains(selectedDayIndex) ? days[selectedDayIndex].exercises : [] },
            set: { newValue in
                if days.indices.contains(selectedDayIndex) {
                    days[selectedDayIndex].exercises = newValue
                }
            }
        )
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Wire.Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    header
                    programNameField
                    dayTabs
                    exerciseList
                    addExerciseButton
                    saveButton
                }
            }
            .sheet(isPresented: $showAddExercise) {
                ExercisePickerSheet(exercises: safeDayExercisesBinding)
            }
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            Text("PROGRAM")
                .font(Wire.Font.sub)
                .foregroundColor(Wire.Color.white)
                .kerning(2)
            Spacer()
            Button("×") { dismiss() }
                .font(Wire.Font.header)
                .foregroundColor(Wire.Color.gray)
        }
        .padding(Wire.Layout.pad)
        .background(Wire.Color.black)
        .overlay(Rectangle().stroke(Wire.Color.white, lineWidth: Wire.Layout.border))
    }
    
    // MARK: - Program Name Field
    
    private var programNameField: some View {
        HStack {
            TextField("PROGRAM NAME", text: $programName)
                .font(Wire.Font.body)
                .foregroundColor(Wire.Color.white)
                .textInputAutocapitalization(.characters)
                .padding(Wire.Layout.pad)
        }
        .background(Wire.Color.black)
        .overlay(Rectangle().stroke(Wire.Color.dark, lineWidth: Wire.Layout.border))
        .padding(.horizontal, Wire.Layout.pad)
        .padding(.top, Wire.Layout.pad)
    }
    
    // MARK: - Day Tabs
    
    private var dayTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Array(days.enumerated()), id: \.element.id) { index, _ in
                    dayTab(index)
                }
                
                // Add Day Button
                if days.count < maxDays {
                    Button {
                        Wire.tap()
                        addDay()
                    } label: {
                        Text("+")
                            .font(Wire.Font.header)
                            .foregroundColor(Wire.Color.gray)
                            .frame(width: 44, height: 44)
                            .background(Wire.Color.black)
                            .overlay(Rectangle().stroke(Wire.Color.dark, lineWidth: Wire.Layout.border))
                    }
                }
            }
            .padding(.horizontal, Wire.Layout.pad)
        }
        .padding(.top, Wire.Layout.pad)
    }
    
    private func dayTab(_ index: Int) -> some View {
        Button {
            Wire.tap()
            selectedDayIndex = index
        } label: {
            HStack(spacing: 4) {
                Text(days[index].name.isEmpty ? "DAY \(index + 1)" : days[index].name)
                    .font(Wire.Font.body)
                    .kerning(1)
                    .foregroundColor(selectedDayIndex == index ? Wire.Color.black : Wire.Color.white)
                    .lineLimit(1)
                
                // Delete button (only if more than 1 day)
                if days.count > 1 {
                    Button {
                        Wire.tap()
                        deleteDay(at: index)
                    } label: {
                        Text("×")
                            .font(Wire.Font.caption)
                            .foregroundColor(selectedDayIndex == index ? Wire.Color.black.opacity(0.5) : Wire.Color.gray)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(selectedDayIndex == index ? Wire.Color.white : Wire.Color.black)
            .overlay(Rectangle().stroke(Wire.Color.white, lineWidth: Wire.Layout.border))
        }
    }
    
    // MARK: - Day Name Editor (inline in list)
    
    private var dayNameEditor: some View {
        HStack {
            Text("NAME:")
                .font(Wire.Font.caption)
                .foregroundColor(Wire.Color.gray)
            
            TextField("DAY \(selectedDayIndex + 1)", text: $days[selectedDayIndex].name)
                .font(Wire.Font.body)
                .foregroundColor(Wire.Color.white)
                .textInputAutocapitalization(.characters)
        }
        .padding(Wire.Layout.pad)
        .background(Wire.Color.black)
        .overlay(Rectangle().stroke(Wire.Color.dark, lineWidth: Wire.Layout.border))
    }
    
    // MARK: - Exercise List
    
    private var exerciseList: some View {
        ScrollView {
            VStack(spacing: 4) {
                // Day name editor
                if days.indices.contains(selectedDayIndex) {
                    dayNameEditor
                }
                
                let exercises = days.indices.contains(selectedDayIndex) ? days[selectedDayIndex].exercises : []
                
                if exercises.isEmpty {
                    Text("NO EXERCISES")
                        .font(Wire.Font.body)
                        .foregroundColor(Wire.Color.gray)
                        .padding(.vertical, 32)
                } else {
                    ForEach(Array(exercises.enumerated()), id: \.element.id) { i, ex in
                        exerciseRow(ex, at: i)
                    }
                }
            }
            .padding(Wire.Layout.pad)
        }
    }
    
    private func exerciseRow(_ exercise: Exercise, at index: Int) -> some View {
        HStack(spacing: Wire.Layout.gap) {
            Text(exercise.name.uppercased())
                .font(Wire.Font.body)
                .foregroundColor(Wire.Color.white)
                .lineLimit(1)

            Spacer()

            // Inline weight editor
            HStack(spacing: 0) {
                Button {
                    Wire.tap()
                    let newWeight = exercise.currentWeight - 2.5
                    exercise.currentWeight = max(0, newWeight)
                } label: {
                    Text("−")
                        .font(Wire.Font.body)
                        .foregroundColor(Wire.Color.white)
                        .frame(width: 32, height: 32)
                        .background(Wire.Color.black)
                        .overlay(Rectangle().stroke(Wire.Color.white, lineWidth: Wire.Layout.border))
                }

                TextField("", value: Binding(
                    get: { exercise.currentWeight },
                    set: { exercise.currentWeight = max(0, min(500, $0)) }
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
                    let newWeight = exercise.currentWeight + 2.5
                    exercise.currentWeight = min(500, newWeight)
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

            Button("×") {
                Wire.tap()
                days[selectedDayIndex].exercises.removeAll(where: { $0.id == exercise.id })
            }
            .font(Wire.Font.header)
            .foregroundColor(Wire.Color.danger)
        }
        .padding(Wire.Layout.pad)
        .background(Wire.Color.black)
        .overlay(Rectangle().stroke(Wire.Color.dark, lineWidth: Wire.Layout.border))
    }
    
    // MARK: - Add Exercise Button
    
    private var addExerciseButton: some View {
        WireButton("ADD EXERCISE") {
            showAddExercise = true
        }
        .padding(.horizontal, Wire.Layout.pad)
        .padding(.top, Wire.Layout.gap)
    }
    
    // MARK: - Save Button
    
    private var saveButton: some View {
        WireButton("SAVE PROGRAM", inverted: isValid) { save() }
            .padding(Wire.Layout.pad)
            .disabled(!isValid)
    }
    
    // MARK: - Validation
    
    private var isValid: Bool {
        // At least one day with at least one exercise
        days.contains { !$0.exercises.isEmpty }
    }
    
    // MARK: - Actions
    
    private func addDay() {
        let newDay = WorkoutDay(name: "DAY \(days.count + 1)")
        days.append(newDay)
        selectedDayIndex = days.count - 1
    }
    
    private func deleteDay(at index: Int) {
        guard days.count > 1 else { return }
        days.remove(at: index)
        if index < selectedDayIndex {
            selectedDayIndex -= 1
        } else if selectedDayIndex >= days.count {
            selectedDayIndex = days.count - 1
        }
    }
    
    private func save() {
        Wire.heavy()
        
        // Create the program
        let program = WorkoutProgram(
            name: programName.isEmpty ? "\(days.count)-DAY SPLIT" : programName,
            isActive: true
        )
        modelContext.insert(program)
        
        // Deactivate other programs
        let descriptor = FetchDescriptor<WorkoutProgram>()
        if let existingPrograms = try? modelContext.fetch(descriptor) {
            for p in existingPrograms where p.id != program.id {
                p.isActive = false
            }
        }
        
        // Create templates for each day
        for (index, day) in days.enumerated() where !day.exercises.isEmpty {
            let template = WorkoutTemplate(
                name: day.name.isEmpty ? "DAY \(index + 1)" : day.name,
                dayIndex: index,
                exercises: day.exercises
            )
            template.program = program
            modelContext.insert(template)
        }
        
        modelContext.saveSafe()
        dismiss()
    }
}

// MARK: - Workout Day (Local State)
// Temporary struct for UI state before saving to SwiftData

struct WorkoutDay: Identifiable {
    let id = UUID()
    var name: String
    var exercises: [Exercise] = []
}
