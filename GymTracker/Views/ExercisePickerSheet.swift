import SwiftUI

// ═══════════════════════════════════════════════════════════════════════════
// EXERCISE PICKER SHEET
// Searchable exercise library with category/muscle filters.
// Multi-select: tap exercises to toggle, then batch-add with bottom button.
// ═══════════════════════════════════════════════════════════════════════════

struct ExercisePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var exercises: [Exercise]

    @State private var searchText = ""
    @State private var selectedCategories: Set<ExerciseCategory> = []
    @State private var selectedMuscles: Set<MuscleGroup> = []
    @State private var showCustomSheet = false
    @State private var isAdding = false
    @State private var selectedTemplates: Set<UUID> = []

    private var filteredExercises: [ExerciseTemplate] {
        ExerciseLibrary.filter(
            query: searchText,
            categories: selectedCategories,
            muscles: selectedMuscles
        )
    }

    var body: some View {
        ZStack {
            Wire.Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                searchBar
                filterChips
                resultsList

                if !selectedTemplates.isEmpty {
                    addSelectedButton
                }
            }
        }
        .onAppear { isAdding = false }
        .sheet(isPresented: $showCustomSheet) {
            AddExerciseSheet(exercises: $exercises)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            HStack(spacing: 6) {
                Text("ADD EXERCISE")
                    .font(Wire.Font.sub)
                    .foregroundColor(Wire.Color.white)
                    .kerning(2)

                if !selectedTemplates.isEmpty {
                    Text("[\(selectedTemplates.count)]")
                        .font(Wire.Font.sub)
                        .foregroundColor(Wire.Color.white)
                        .kerning(1)
                }
            }
            Spacer()
            Button("×") { dismiss() }
                .font(Wire.Font.header)
                .foregroundColor(Wire.Color.gray)
        }
        .padding(Wire.Layout.pad)
        .overlay(Rectangle().stroke(Wire.Color.white, lineWidth: Wire.Layout.border))
    }

    // MARK: - Search

    private var searchBar: some View {
        HStack(spacing: Wire.Layout.gap) {
            Text("//")
                .font(Wire.Font.caption)
                .foregroundColor(Wire.Color.dark)
            TextField("Search exercises...", text: $searchText)
                .font(Wire.Font.body)
                .foregroundColor(Wire.Color.white)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        }
        .padding(Wire.Layout.pad)
        .overlay(Rectangle().stroke(Wire.Color.dark, lineWidth: Wire.Layout.border))
    }

    // MARK: - Filter Chips

    private var filterChips: some View {
        VStack(spacing: Wire.Layout.gap) {
            // Category row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(ExerciseCategory.allCases, id: \.self) { cat in
                        chipButton(
                            label: cat.rawValue,
                            isSelected: selectedCategories.contains(cat)
                        ) {
                            if selectedCategories.contains(cat) {
                                selectedCategories.remove(cat)
                            } else {
                                selectedCategories.insert(cat)
                            }
                        }
                    }
                }
                .padding(.horizontal, Wire.Layout.pad)
            }

            // Muscle row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(MuscleGroup.allCases) { muscle in
                        chipButton(
                            label: muscle.rawValue.uppercased(),
                            isSelected: selectedMuscles.contains(muscle)
                        ) {
                            if selectedMuscles.contains(muscle) {
                                selectedMuscles.remove(muscle)
                            } else {
                                selectedMuscles.insert(muscle)
                            }
                        }
                    }
                }
                .padding(.horizontal, Wire.Layout.pad)
            }
        }
        .padding(.vertical, Wire.Layout.gap)
    }

    // MARK: - Results

    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredExercises) { template in
                    Button {
                        Wire.tap()
                        toggleSelection(template)
                    } label: {
                        exerciseRow(template)
                    }
                    .buttonStyle(.plain)
                }

                // Custom exercise button
                Button {
                    Wire.tap()
                    showCustomSheet = true
                } label: {
                    HStack {
                        Text("+ CUSTOM EXERCISE")
                            .font(Wire.Font.body)
                            .foregroundColor(Wire.Color.bone)
                            .kerning(1)
                        Spacer()
                    }
                    .padding(Wire.Layout.pad)
                    .overlay(Rectangle().stroke(Wire.Color.dark, lineWidth: Wire.Layout.border))
                }
                .buttonStyle(.plain)
                .padding(.top, Wire.Layout.gap)
            }
            .padding(.horizontal, Wire.Layout.pad)
            .padding(.bottom, Wire.Layout.pad)
        }
    }

    // MARK: - Add Selected Button

    private var addSelectedButton: some View {
        WireButton("ADD \(selectedTemplates.count) EXERCISE\(selectedTemplates.count > 1 ? "S" : "")", inverted: true) {
            addSelectedExercises()
        }
        .padding(Wire.Layout.pad)
    }

    // MARK: - Components

    private func exerciseRow(_ template: ExerciseTemplate) -> some View {
        let isSelected = selectedTemplates.contains(template.id)

        return HStack(spacing: Wire.Layout.gap) {
            Text(isSelected ? "[x]" : "[ ]")
                .font(Wire.Font.body)
                .foregroundColor(isSelected ? Wire.Color.white : Wire.Color.dark)

            VStack(alignment: .leading, spacing: 4) {
                Text(template.name.uppercased())
                    .font(Wire.Font.body)
                    .foregroundColor(Wire.Color.white)
                    .kerning(1)
                Text("\(template.category.rawValue) · \(template.primaryMuscle.rawValue.uppercased()) · \(template.exerciseType.rawValue)")
                    .font(Wire.Font.tiny)
                    .foregroundColor(Wire.Color.gray)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Wire.Layout.pad)
        .background(isSelected ? Wire.Color.dark : Wire.Color.black)
        .overlay(Rectangle().stroke(isSelected ? Wire.Color.white : Wire.Color.dark, lineWidth: Wire.Layout.border))
    }

    private func chipButton(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(Wire.Font.tiny)
                .foregroundColor(isSelected ? Wire.Color.black : Wire.Color.gray)
                .kerning(1)
                .padding(.horizontal, Wire.Layout.gap)
                .padding(.vertical, 4)
                .background(isSelected ? Wire.Color.white : Wire.Color.black)
                .overlay(Rectangle().stroke(isSelected ? Wire.Color.white : Wire.Color.dark, lineWidth: Wire.Layout.border))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func toggleSelection(_ template: ExerciseTemplate) {
        if selectedTemplates.contains(template.id) {
            selectedTemplates.remove(template.id)
        } else {
            selectedTemplates.insert(template.id)
        }
    }

    private func addSelectedExercises() {
        guard !isAdding else { return }
        isAdding = true
        Wire.heavy()

        let allTemplates = ExerciseLibrary.all
        let toAdd = allTemplates.filter { selectedTemplates.contains($0.id) }

        for template in toAdd {
            exercises.append(Exercise(
                name: template.name,
                category: template.category,
                exerciseType: template.exerciseType,
                primaryMuscle: template.primaryMuscle
            ))
        }

        dismiss()
    }
}
