import SwiftUI

// ═══════════════════════════════════════════════════════════════════════════
// EXERCISE PICKER SHEET
// Searchable exercise library with category/muscle filters.
// ═══════════════════════════════════════════════════════════════════════════

struct ExercisePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var exercises: [Exercise]

    @State private var searchText = ""
    @State private var selectedCategories: Set<ExerciseCategory> = []
    @State private var selectedMuscles: Set<MuscleGroup> = []
    @State private var showCustomSheet = false

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
            }
        }
        .sheet(isPresented: $showCustomSheet) {
            AddExerciseSheet(exercises: $exercises)
        }
    }

    // MARK: - Header

    private var header: some View {
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
                    ForEach([ExerciseCategory.push, .pull, .legs, .core], id: \.self) { cat in
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
                        addFromTemplate(template)
                    } label: {
                        exerciseRow(template)
                    }
                    .buttonStyle(.plain)
                }

                // Custom exercise button
                Button {
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

    // MARK: - Components

    private func exerciseRow(_ template: ExerciseTemplate) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(template.name.uppercased())
                .font(Wire.Font.body)
                .foregroundColor(Wire.Color.white)
                .kerning(1)
            Text("\(template.category.rawValue) · \(template.primaryMuscle.rawValue.uppercased()) · \(template.exerciseType.rawValue)")
                .font(Wire.Font.tiny)
                .foregroundColor(Wire.Color.gray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Wire.Layout.pad)
        .overlay(Rectangle().stroke(Wire.Color.dark, lineWidth: Wire.Layout.border))
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

    private func addFromTemplate(_ template: ExerciseTemplate) {
        Wire.tap()
        let exercise = Exercise(
            name: template.name,
            category: template.category,
            exerciseType: template.exerciseType,
            primaryMuscle: template.primaryMuscle
        )
        exercises.append(exercise)
        dismiss()
    }
}
