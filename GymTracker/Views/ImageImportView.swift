import SwiftUI
import SwiftData
import PhotosUI

// ═══════════════════════════════════════════════════════════════════════════
// IMAGE IMPORT VIEW
// Parse workout images using Gemini Vision API
// ═══════════════════════════════════════════════════════════════════════════

// MARK: - Editable Models (for reordering)

class EditableProgram: ObservableObject {
    @Published var programName: String
    @Published var days: [EditableDay]
    
    init(from parsed: ParsedWorkoutProgram) {
        self.programName = parsed.programName
        self.days = parsed.days.enumerated().map { EditableDay(from: $1, index: $0) }
    }
}

class EditableDay: Identifiable, ObservableObject {
    let id = UUID()
    @Published var name: String
    @Published var exercises: [EditableExercise]
    var dayIndex: Int
    
    init(from parsed: ParsedWorkoutDay, index: Int) {
        self.name = parsed.name
        self.dayIndex = index
        self.exercises = parsed.exercises.map { EditableExercise(from: $0) }
    }
}

class EditableExercise: Identifiable, ObservableObject {
    let id = UUID()
    @Published var name: String
    @Published var sets: Int
    @Published var reps: Int
    @Published var notes: String?
    
    init(from parsed: ParsedExercise) {
        self.name = parsed.name
        self.sets = parsed.sets
        self.reps = parsed.reps
        self.notes = parsed.notes
    }
}

struct ImageImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // Photo selection
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    
    // Parsing state
    @State private var isParsing = false
    @State private var errorMessage: String?
    @State private var parsedProgram: ParsedWorkoutProgram?
    
    // Editable state for reordering
    @StateObject private var editableProgram = EditableProgram(from: ParsedWorkoutProgram(programName: "", days: []))
    @State private var hasEditableProgram = false
    
    // Confirmation state
    @State private var showConfirmation = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Wire.Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    header
                    
                    ScrollView {
                        VStack(spacing: Wire.Layout.pad) {
                            if selectedImage == nil {
                                imagePickerSection
                            } else if isParsing {
                                parsingView
                            } else if hasEditableProgram {
                                editableResultView
                            } else {
                                selectedImageView
                            }
                        }
                        .padding(Wire.Layout.pad)
                    }
                }
            }
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            Text("IMPORT")
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
    
    // MARK: - Image Picker Section
    
    private var imagePickerSection: some View {
        VStack(spacing: Wire.Layout.pad) {
            Text("📸")
                .font(.system(size: 64))
                .padding(.top, 32)
            
            Text("UPLOAD WORKOUT SCHEDULE")
                .font(Wire.Font.body)
                .foregroundColor(Wire.Color.white)
                .kerning(1)
            
            Text("Photo of a workout plan, whiteboard, or screenshot")
                .font(Wire.Font.caption)
                .foregroundColor(Wire.Color.gray)
                .multilineTextAlignment(.center)
            
            PhotosPicker(
                selection: $selectedItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Text("SELECT IMAGE")
                    .font(Wire.Font.body)
                    .foregroundColor(Wire.Color.black)
                    .kerning(1)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Wire.Color.white)
            }
            .onChange(of: selectedItem) { _, newValue in
                loadImage(from: newValue)
            }
            
            if !GeminiService.hasAPIKey() {
                HStack {
                    Text("⚠️")
                    Text("Add API key in Settings first")
                        .font(Wire.Font.caption)
                        .foregroundColor(Wire.Color.danger)
                }
                .padding(.top, Wire.Layout.pad)
            }
        }
    }
    
    // MARK: - Selected Image View
    
    private var selectedImageView: some View {
        VStack(spacing: Wire.Layout.pad) {
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 250)
                    .clipped()
                    .overlay(Rectangle().stroke(Wire.Color.white, lineWidth: Wire.Layout.border))
            }
            
            if let error = errorMessage {
                Text(error)
                    .font(Wire.Font.caption)
                    .foregroundColor(Wire.Color.danger)
                    .multilineTextAlignment(.center)
                    .padding()
            }
            
            HStack(spacing: Wire.Layout.gap) {
                Button {
                    selectedImage = nil
                    selectedItem = nil
                    errorMessage = nil
                } label: {
                    Text("CANCEL")
                        .font(Wire.Font.body)
                        .foregroundColor(Wire.Color.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .overlay(Rectangle().stroke(Wire.Color.white, lineWidth: Wire.Layout.border))
                }
                
                Button {
                    parseImage()
                } label: {
                    Text("PARSE")
                        .font(Wire.Font.body)
                        .foregroundColor(Wire.Color.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Wire.Color.white)
                }
                .disabled(!GeminiService.hasAPIKey())
            }
        }
    }
    
    // MARK: - Parsing View
    
    private var parsingView: some View {
        VStack {
            Spacer()
            
            VStack(spacing: Wire.Layout.pad) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Wire.Color.white))
                    .scaleEffect(1.5)
                    .padding()
                
                Text("ANALYZING...")
                    .font(Wire.Font.body)
                    .foregroundColor(Wire.Color.white)
                    .kerning(2)
                
                Text("Gemini is reading your workout schedule")
                    .font(Wire.Font.caption)
                    .foregroundColor(Wire.Color.gray)
                    .multilineTextAlignment(.center)
            }
            .padding(32)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .background(Wire.Color.black)
    }
    
    // MARK: - Editable Result View (with drag-drop)
    
    private var editableResultView: some View {
        VStack(alignment: .leading, spacing: Wire.Layout.pad) {
            HStack {
                Text("DETECTED PROGRAM")
                    .font(Wire.Font.sub)
                    .foregroundColor(Wire.Color.white)
                    .kerning(2)
                Spacer()
                Text("DRAG TO REORDER")
                    .font(Wire.Font.tiny)
                    .foregroundColor(Wire.Color.gray)
            }
            
            Text(editableProgram.programName.uppercased())
                .font(Wire.Font.header)
                .foregroundColor(Wire.Color.white)
            
            ForEach(editableProgram.days) { day in
                editableDayCard(day)
            }
            
            HStack(spacing: Wire.Layout.gap) {
                Button {
                    // Reset
                    hasEditableProgram = false
                    parsedProgram = nil
                    selectedImage = nil
                    selectedItem = nil
                } label: {
                    Text("RETRY")
                        .font(Wire.Font.body)
                        .foregroundColor(Wire.Color.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .overlay(Rectangle().stroke(Wire.Color.white, lineWidth: Wire.Layout.border))
                }
                
                Button {
                    saveEditableProgram()
                } label: {
                    Text("SAVE")
                        .font(Wire.Font.body)
                        .foregroundColor(Wire.Color.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Wire.Color.white)
                }
            }
            .padding(.top, Wire.Layout.pad)
        }
    }
    
    private func editableDayCard(_ day: EditableDay) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("DAY \(day.dayIndex + 1)")
                    .font(Wire.Font.tiny)
                    .foregroundColor(Wire.Color.gray)
                Spacer()
                Text(day.name.uppercased())
                    .font(Wire.Font.caption)
                    .foregroundColor(Wire.Color.white)
            }
            
            ForEach(day.exercises) { exercise in
                HStack {
                    Image(systemName: "line.3.horizontal")
                        .font(.caption2)
                        .foregroundColor(Wire.Color.dark)
                    
                    Text(exercise.name.uppercased())
                        .font(Wire.Font.caption)
                        .foregroundColor(Wire.Color.white)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text("\(exercise.sets)×\(exercise.reps)")
                        .font(Wire.Font.body)
                        .foregroundColor(Wire.Color.gray)
                }
            }
            .onMove { from, to in
                day.exercises.move(fromOffsets: from, toOffset: to)
            }
        }
        .padding(Wire.Layout.pad)
        .background(Wire.Color.black)
        .overlay(Rectangle().stroke(Wire.Color.dark, lineWidth: Wire.Layout.border))
    }
    
    // MARK: - Actions
    
    private func loadImage(from item: PhotosPickerItem?) {
        guard let item else { return }
        
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    selectedImage = image
                    errorMessage = nil
                }
            }
        }
    }
    
    private func parseImage() {
        guard let image = selectedImage else { return }
        
        isParsing = true
        errorMessage = nil
        
        Task {
            do {
                let result = try await GeminiService.shared.parseWorkoutImage(image)
                await MainActor.run {
                    parsedProgram = result
                    // Create editable version
                    let editable = EditableProgram(from: result)
                    editableProgram.programName = editable.programName
                    editableProgram.days = editable.days
                    hasEditableProgram = true
                    isParsing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isParsing = false
                }
            }
        }
    }
    
    private func saveEditableProgram() {
        Wire.heavy()
        
        // Create program
        let program = WorkoutProgram(name: editableProgram.programName, isActive: true)
        modelContext.insert(program)
        
        // Deactivate other programs
        let descriptor = FetchDescriptor<WorkoutProgram>()
        if let existingPrograms = try? modelContext.fetch(descriptor) {
            for p in existingPrograms where p.id != program.id {
                p.isActive = false
            }
        }
        
        // Create templates for each day (using reordered exercises)
        for (index, day) in editableProgram.days.enumerated() {
            var exercises: [Exercise] = []
            
            for editableExercise in day.exercises {
                let exercise = Exercise(
                    name: editableExercise.name,
                    category: inferCategory(from: editableExercise.name),
                    notes: editableExercise.notes ?? "",
                    targetReps: editableExercise.reps,
                    targetSets: editableExercise.sets
                )
                // Resolve primaryMuscle from BiomechanicsEngine registry
                let activations = BiomechanicsEngine.muscleActivation(for: exercise)
                if let topMuscle = activations.max(by: { $0.value < $1.value })?.key {
                    exercise.primaryMuscle = topMuscle
                }
                exercises.append(exercise)
            }
            
            let template = WorkoutTemplate(
                name: day.name,
                dayIndex: index,
                exercises: exercises
            )
            template.program = program
            modelContext.insert(template)
        }
        
        try? modelContext.save()
        dismiss()
    }
    
    // MARK: - Helpers
    
    private func inferCategory(from name: String) -> ExerciseCategory {
        let lowercased = name.lowercased()
        
        if lowercased.contains("bench") || lowercased.contains("press") || lowercased.contains("dip") || lowercased.contains("fly") {
            return .push
        } else if lowercased.contains("row") || lowercased.contains("pull") || lowercased.contains("curl") || lowercased.contains("lat") {
            return .pull
        } else if lowercased.contains("squat") || lowercased.contains("leg") || lowercased.contains("lunge") || lowercased.contains("deadlift") || lowercased.contains("calf") {
            return .legs
        } else if lowercased.contains("plank") || lowercased.contains("crunch") || lowercased.contains("ab") {
            return .core
        } else if lowercased.contains("run") || lowercased.contains("cardio") || lowercased.contains("bike") {
            return .cardio
        }
        
        return .other
    }
}
