import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// ═══════════════════════════════════════════════════════════════════════════
// TEMPLATE EDITOR VIEW (Polymorphic: Create OR Edit)
// If templateToEdit is nil -> NEW mode
// If templateToEdit exists -> EDIT mode (pre-fill and update)
// ═══════════════════════════════════════════════════════════════════════════

struct WorkoutTemplateView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // Optional: If provided, we're in EDIT mode
    var templateToEdit: WorkoutTemplate?
    
    @State private var templateName = ""
    @State private var exercises: [Exercise] = []
    @State private var showAdd = false
    @State private var draggedExercise: Exercise? // FOR DRAG & DROP
    
    private var isEditMode: Bool { templateToEdit != nil }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Wire.Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    header
                    
                    ScrollView {
                        VStack(spacing: Wire.Layout.gap) {
                            WireInput(label: "Name", value: $templateName)
                            exerciseList
                            WireButton("ADD EXERCISE") { showAdd = true }
                        }
                        .padding(Wire.Layout.pad)
                    }
                    
                    saveButton
                }
            }
            .sheet(isPresented: $showAdd) {
                ExercisePickerSheet(exercises: $exercises)
            }
            .onAppear {
                // Pre-fill if editing
                if let template = templateToEdit {
                    templateName = template.name
                    // Defensive copies — avoid mutating shared @Model references
                    exercises = template.exercises.map { ex in
                        Exercise(
                            name: ex.name,
                            category: ex.category,
                            exerciseType: ex.exerciseType ?? .compound,
                            primaryMuscle: ex.primaryMuscle ?? .chest,
                            notes: ex.notes,
                            restSeconds: ex.restSeconds,
                            currentWeight: ex.currentWeight,
                            targetIncrement: ex.targetIncrement,
                            targetReps: ex.targetReps,
                            targetSets: ex.targetSets
                        )
                    }
                }
            }
        }
    }
    
    private var header: some View {
        HStack {
            Text(isEditMode ? "EDIT TEMPLATE" : "NEW TEMPLATE")
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
    
    private var exerciseList: some View {
        VStack(spacing: 4) {
            if !exercises.isEmpty {
                Text("EXERCISES [\(exercises.count)]")
                    .font(Wire.Font.caption)
                    .foregroundColor(Wire.Color.gray)
                    .kerning(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // USING FOREACH WITH IDENTIFIABLE EXERCISE FOR DRAG DROP
            ForEach(exercises) { ex in
                ExerciseRow(exercise: ex, onDelete: {
                    if let idx = exercises.firstIndex(where: { $0.id == ex.id }) {
                        exercises.remove(at: idx)
                    }
                })
                .onDrag {
                    self.draggedExercise = ex
                    return NSItemProvider(object: ex.id.uuidString as NSString)
                }
                .onDrop(of: [UTType.text], delegate: ExerciseDropDelegate(item: ex, items: $exercises, draggedItem: $draggedExercise))
            }
        }
        .animation(.default, value: exercises)
    }
    
    private var saveButton: some View {
        WireButton("SAVE", inverted: isValid) {
            save()
        }
        .padding(Wire.Layout.pad)
        .disabled(!isValid)
    }
    
    private var isValid: Bool {
        !templateName.isEmpty && !exercises.isEmpty
    }
    
    private func save() {
        Wire.heavy()
        
        if let template = templateToEdit {
            // EDIT MODE: Update existing template
            template.name = templateName
            template.exercises = exercises
            modelContext.saveSafe()
        } else {
            // NEW MODE: Insert new template
            modelContext.insert(WorkoutTemplate(name: templateName, exercises: exercises))
        }
        
        dismiss()
    }
}

// MARK: - Subviews & Helpers

struct ExerciseRow: View {
    let exercise: Exercise
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            // DRAG HANDLE
            Image(systemName: "line.3.horizontal")
                .font(Wire.Font.header)
                .foregroundColor(Wire.Color.gray)
                .padding(.trailing, 8)
            
            Text(exercise.category.rawValue.prefix(4).uppercased())
                .font(Wire.Font.tiny)
                .foregroundColor(Wire.Color.gray)
                .frame(width: 36, alignment: .leading)
            
            Text(exercise.name.uppercased())
                .font(Wire.Font.body)
                .foregroundColor(Wire.Color.white)
                .lineLimit(1)
            
            Spacer()
            
            Text("\(Int(exercise.currentWeight))")
                .font(Wire.Font.body)
                .foregroundColor(Wire.Color.gray)
            
            Button("×") {
                Wire.tap()
                onDelete()
            }
            .font(Wire.Font.header)
            .foregroundColor(Wire.Color.danger)
            .padding(.leading, 8)
        }
        .padding(Wire.Layout.pad)
        .background(Wire.Color.black)
        .overlay(Rectangle().stroke(Wire.Color.dark, lineWidth: Wire.Layout.border))
    }
}

struct ExerciseDropDelegate: DropDelegate {
    let item: Exercise
    @Binding var items: [Exercise]
    @Binding var draggedItem: Exercise?
    
    func dropEntered(info: DropInfo) {
        guard let draggedItem = draggedItem else { return }
        
        if draggedItem.id != item.id {
            guard let from = items.firstIndex(of: draggedItem),
                  let to = items.firstIndex(of: item) else { return }

            if items[to].id != draggedItem.id {
                withAnimation {
                    items.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
                }
            }
        }
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
    
    func performDrop(info: DropInfo) -> Bool {
        self.draggedItem = nil
        return true
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// ADD EXERCISE SHEET
// ═══════════════════════════════════════════════════════════════════════════

struct AddExerciseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var exercises: [Exercise]
    
    @State private var name = ""
    @State private var category: ExerciseCategory = .push
    @State private var exerciseType: ExerciseType = .accessory
    @State private var primaryMuscle: MuscleGroup = .chest
    @State private var weight: String = "20"
    @State private var reps: Int = 8
    @State private var sets: Int = 3
    @State private var rest: Int = 120
    
    var body: some View {
        ZStack {
            Wire.Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                HStack {
                    Text("ADD EXERCISE")
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
                
                ScrollView {
                    VStack(spacing: Wire.Layout.gap) {
                        WireInput(label: "Name", value: $name)
                        categoryPicker
                        typePicker
                        musclePicker
                        WireInput(label: "Weight (kg)", value: $weight, keyboard: .decimalPad)
                        
                        HStack(spacing: Wire.Layout.gap) {
                            WireStepper(label: "Sets", value: $sets, range: 1...10)
                            WireStepper(label: "Reps", value: $reps, range: 1...30)
                        }
                        
                        WireStepper(label: "Rest (sec)", value: $rest, range: 30...300, step: 15)
                    }
                    .padding(Wire.Layout.pad)
                }
                
                WireButton("ADD", inverted: !name.isEmpty) { addExercise() }
                    .padding(Wire.Layout.pad)
                    .disabled(name.isEmpty)
                    .onChange(of: category) { _, newCat in
                        primaryMuscle = Self.defaultMuscle(for: newCat)
                    }
            }
        }
    }
    
    private var categoryPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("CATEGORY")
                .font(Wire.Font.caption)
                .foregroundColor(Wire.Color.gray)
                .kerning(1)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
                ForEach(ExerciseCategory.allCases, id: \.self) { cat in
                    Button {
                        Wire.tap()
                        category = cat
                    } label: {
                        Text(cat.rawValue)
                            .font(Wire.Font.caption)
                            .foregroundColor(category == cat ? Wire.Color.black : Wire.Color.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(category == cat ? Wire.Color.white : Wire.Color.black)
                            .overlay(Rectangle().stroke(Wire.Color.white, lineWidth: Wire.Layout.border))
                    }
                }
            }
        }
    }
    
    private var typePicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("TYPE")
                .font(Wire.Font.caption)
                .foregroundColor(Wire.Color.gray)
                .kerning(1)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
                ForEach(ExerciseType.allCases, id: \.self) { t in
                    Button {
                        Wire.tap()
                        exerciseType = t
                    } label: {
                        Text(t.rawValue)
                            .font(Wire.Font.caption)
                            .foregroundColor(exerciseType == t ? Wire.Color.black : Wire.Color.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(exerciseType == t ? Wire.Color.white : Wire.Color.black)
                            .overlay(Rectangle().stroke(Wire.Color.white, lineWidth: Wire.Layout.border))
                    }
                }
            }
        }
    }

    private var musclePicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("PRIMARY MUSCLE")
                .font(Wire.Font.caption)
                .foregroundColor(Wire.Color.gray)
                .kerning(1)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
                ForEach(MuscleGroup.allCases, id: \.self) { m in
                    Button {
                        Wire.tap()
                        primaryMuscle = m
                    } label: {
                        Text(m.rawValue.uppercased())
                            .font(Wire.Font.caption)
                            .foregroundColor(primaryMuscle == m ? Wire.Color.black : Wire.Color.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(primaryMuscle == m ? Wire.Color.white : Wire.Color.black)
                            .overlay(Rectangle().stroke(Wire.Color.white, lineWidth: Wire.Layout.border))
                    }
                }
            }
        }
    }

    /// Map category to the most common primary muscle for that movement pattern
    private static func defaultMuscle(for category: ExerciseCategory) -> MuscleGroup {
        switch category {
        case .push:   return .chest
        case .pull:   return .back
        case .legs:   return .quads
        case .core:   return .core
        case .cardio: return .quads
        case .other:  return .shoulders
        }
    }

    private func addExercise() {
        Wire.heavy()
        exercises.append(Exercise(
            name: name,
            category: category,
            exerciseType: exerciseType,
            primaryMuscle: primaryMuscle,
            restSeconds: rest,
            currentWeight: Double(weight) ?? 20,
            targetReps: reps,
            targetSets: sets
        ))
        dismiss()
    }
}
