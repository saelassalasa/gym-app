import SwiftUI
import SwiftData

// ═══════════════════════════════════════════════════════════════════════════
// ACTIVE WORKOUT VIEW
// Wireframe workout logging interface. Dense data. Maximum utility.
// ═══════════════════════════════════════════════════════════════════════════

struct ActiveWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var manager: WorkoutManager
    @State private var showPlateCalc = false
    @State private var showWarmup = false
    @State private var showAbortAlert = false
    @State private var showFinishAlert = false
    @State private var showSummary = false
    @State private var showExtraSetInput = false
    @State private var showReorder = false
    @State private var selectedSetType: SetType = .working

    init(manager: WorkoutManager) {
        _manager = State(initialValue: manager)
    }

    var body: some View {
        if showSummary {
            WorkoutSummaryView(
                viewModel: WorkoutSummaryViewModel(
                    session: manager.session,
                    prResults: manager.prResults,
                    context: manager.summaryContext
                )
            )
        } else {
            workoutBody
        }
    }

    private var workoutBody: some View {
        ZStack {
            Wire.Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView {
                    VStack(spacing: Wire.Layout.gap) {
                        toolsRow
                        setsSection
                        inputSection
                        oneRMRow
                    }
                    .padding(Wire.Layout.pad)
                }

                bottomBar
            }

            if manager.isTimerActive {
                timerOverlay
            }

            if manager.showPRBanner {
                prBanner
            }
        }
        .sheet(isPresented: $showPlateCalc) {
            PlateCalculatorView()
        }
        .sheet(isPresented: $showWarmup) {
            WarmupGeneratorView(
                workWeight: manager.weightInput,
                workReps: manager.repsInput,
                exerciseName: manager.currentExercise?.name ?? "Exercise"
            ) { _ in }
        }
        .sheet(isPresented: $showReorder) {
            ReorderExercisesSheet(manager: manager)
        }
        .alert("INCINERATE SESSION?", isPresented: $showAbortAlert) {
            Button("ABORT", role: .destructive) {
                manager.abortSession()
                dismiss()
            }
            Button("CANCEL", role: .cancel) {}
        } message: {
            Text("All logged sets will be permanently destroyed.")
        }
        .alert("FINISH WORKOUT?", isPresented: $showFinishAlert) {
            Button("FINISH", role: .destructive) {
                manager.finishWorkout()
                showSummary = true
            }
            Button("CANCEL", role: .cancel) {}
        } message: {
            Text("Save this session and log all sets.")
        }
        .alert("SAVE ERROR", isPresented: Binding(
            get: { manager.saveError != nil },
            set: { if !$0 { manager.saveError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(manager.saveError ?? "")
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("DONE") { hideKeyboard() }
                    .font(Wire.Font.body)
                    .foregroundColor(Wire.Color.white)
            }
        }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .onChange(of: manager.currentExerciseIndex) {
            showExtraSetInput = false
            selectedSetType = .working
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { Wire.tap(); manager.previousExercise() }) {
                    Text("◀")
                        .font(Wire.Font.header)
                        .foregroundColor(manager.currentExerciseIndex > 0 ? Wire.Color.white : Wire.Color.dark)
                        .frame(width: 44, height: 44)
                }
                .disabled(manager.currentExerciseIndex == 0)

                Spacer()

                VStack(spacing: 2) {
                    Text(manager.currentExercise?.name.uppercased() ?? "—")
                        .font(Wire.Font.sub)
                        .foregroundColor(Wire.Color.white)
                        .kerning(2)

                    Text("\(manager.currentExerciseIndex + 1)/\(manager.exerciseCount)")
                        .font(Wire.Font.caption)
                        .foregroundColor(Wire.Color.gray)
                }

                Spacer()

                Button(action: { Wire.tap(); manager.nextExercise() }) {
                    Text("▶")
                        .font(Wire.Font.header)
                        .foregroundColor(manager.currentExerciseIndex < manager.exerciseCount - 1 ? Wire.Color.white : Wire.Color.dark)
                        .frame(width: 44, height: 44)
                }
                .disabled(manager.currentExerciseIndex >= manager.exerciseCount - 1)
            }
            .padding(.horizontal, Wire.Layout.pad)
            .padding(.vertical, 8)
            .background(Wire.Color.black)
            .overlay(Rectangle().stroke(Wire.Color.white, lineWidth: Wire.Layout.border))
        }
    }

    // MARK: - Tools Row

    private var toolsRow: some View {
        HStack(spacing: Wire.Layout.gap) {
            if let history = manager.lastSessionSummary {
                Text(history.uppercased())
                    .font(Wire.Font.caption)
                    .foregroundColor(Wire.Color.white)
                    .kerning(0.5)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .overlay(Rectangle().stroke(Wire.Color.gray, lineWidth: Wire.Layout.border))
            }

            Spacer()

            Button(action: { Wire.tap(); showPlateCalc = true }) {
                Text("PLATES")
                    .font(Wire.Font.caption)
                    .foregroundColor(Wire.Color.white)
                    .kerning(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .overlay(Rectangle().stroke(Wire.Color.white, lineWidth: Wire.Layout.border))
            }

            Button(action: { Wire.tap(); showWarmup = true }) {
                Text("WARMUP")
                    .font(Wire.Font.caption)
                    .foregroundColor(Wire.Color.white)
                    .kerning(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .overlay(Rectangle().stroke(Wire.Color.white, lineWidth: Wire.Layout.border))
            }

            Button(action: { Wire.tap(); showReorder = true }) {
                Text("REORDER")
                    .font(Wire.Font.caption)
                    .foregroundColor(Wire.Color.white)
                    .kerning(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .overlay(Rectangle().stroke(Wire.Color.white, lineWidth: Wire.Layout.border))
            }
        }
    }

    // MARK: - Sets Section

    private var setsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Set progress indicator
            if let exercise = manager.currentExercise {
                let completed = manager.setsForCurrentExercise.filter { $0.isCompleted && !$0.isSkipped }.count
                let target = exercise.targetSets
                HStack {
                    Text("SETS")
                        .font(Wire.Font.caption)
                        .foregroundColor(Wire.Color.gray)
                        .kerning(1)

                    Spacer()

                    Text("\(completed)/\(target)")
                        .font(Wire.Font.sub)
                        .foregroundColor(completed >= target ? Wire.Color.white : Wire.Color.gray)

                    if completed >= target {
                        Text("DONE")
                            .font(Wire.Font.tiny)
                            .foregroundColor(Wire.Color.black)
                            .kerning(1)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Wire.Color.white)
                    }
                }
                .padding(.bottom, 4)
            }

            let previousSets = manager.previousSetsForCurrentExercise
            ForEach(manager.setsForCurrentExercise, id: \.id) { set in
                let prevSet = previousSets.first(where: { $0.setNumber == set.setNumber })
                setRow(set, previousSet: prevSet)
            }
        }
    }

    private func setRow(_ set: WorkoutSet, previousSet: WorkoutSet? = nil) -> some View {
        VStack(alignment: .leading, spacing: 0) {
        HStack(spacing: 8) {
            Text("\(set.setNumber)")
                .font(Wire.Font.body)
                .foregroundColor(set.isSkipped ? Wire.Color.dark : Wire.Color.gray)
                .frame(width: 20, alignment: .leading)

            if set.isSkipped {
                // Skipped set styling
                Text("[ SKIPPED ]")
                    .font(Wire.Font.caption)
                    .foregroundColor(Wire.Color.gray)
                    .strikethrough(true, color: Wire.Color.dark)

                Spacer()

                Text("⊘")
                    .font(Wire.Font.body)
                    .foregroundColor(Wire.Color.dark)
            } else {
                // Set type tag (non-working only)
                if set.setType != .working {
                    Text(set.setType.rawValue)
                        .font(Wire.Font.tiny)
                        .foregroundColor(Wire.Color.black)
                        .kerning(0.5)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Wire.Color.gray)
                }

                // Normal completed set
                Text("\(Int(set.weight))")
                    .font(Wire.Font.sub)
                    .foregroundColor(Wire.Color.white)

                Text("×")
                    .font(Wire.Font.body)
                    .foregroundColor(Wire.Color.gray)

                Text("\(set.reps)")
                    .font(Wire.Font.sub)
                    .foregroundColor(Wire.Color.white)

                Spacer()

                if let rpe = set.rpe {
                    Text("@\(rpe)")
                        .font(Wire.Font.caption)
                        .foregroundColor(rpe >= 9 ? Wire.Color.danger : Wire.Color.gray)
                }

                if manager.prResults[set.id] != nil {
                    Text("PR")
                        .font(Wire.Font.caption)
                        .foregroundColor(Wire.Color.black)
                        .kerning(1)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Wire.Color.white)
                }

                Text("✓")
                    .font(Wire.Font.body)
                    .foregroundColor(Wire.Color.white)
            }
        }
        .padding(8)
        .background(Wire.Color.black)
        .overlay(Rectangle().stroke(
            manager.prResults[set.id] != nil ? Wire.Color.white : Wire.Color.dark,
            lineWidth: Wire.Layout.border
        ))
        .opacity(set.isSkipped ? 0.6 : 1.0)

            if let prev = previousSet, !prev.isSkipped {
                HStack(spacing: 4) {
                    Text("LAST:")
                        .font(Wire.Font.tiny)
                        .foregroundColor(Wire.Color.dark)
                    Text("\(Int(prev.weight))kg × \(prev.reps)")
                        .font(Wire.Font.tiny)
                        .foregroundColor(Wire.Color.dark)
                    if let rpe = prev.rpe {
                        Text("@\(rpe)")
                            .font(Wire.Font.tiny)
                            .foregroundColor(Wire.Color.dark)
                    }
                }
                .padding(.leading, 28)
                .padding(.top, 2)
            }
        }
    }

    // MARK: - Input Section

    private var currentExerciseDone: Bool {
        guard let exercise = manager.currentExercise else { return false }
        let completed = manager.setsForCurrentExercise.filter { $0.isCompleted && !$0.isSkipped }.count
        return completed >= exercise.targetSets
    }

    private var isLastExercise: Bool {
        manager.currentExerciseIndex >= manager.exerciseCount - 1
    }

    private var inputSection: some View {
        VStack(spacing: Wire.Layout.gap) {
            if currentExerciseDone && !showExtraSetInput {
                exerciseDonePrompt
            } else {
                exerciseInputFields
            }
        }
    }

    private var exerciseDonePrompt: some View {
        VStack(spacing: Wire.Layout.gap) {
            if isLastExercise {
                WireButton("FINISH WORKOUT", inverted: true) {
                    showFinishAlert = true
                }
            } else {
                WireButton("NEXT EXERCISE  \u{25B6}", inverted: true) {
                    manager.nextExercise()
                }
            }

            // Secondary: allow bonus sets
            Button(action: { showExtraSetInput = true }) {
                Text("[ + EXTRA SET ]")
                    .font(Wire.Font.caption)
                    .foregroundColor(Wire.Color.gray)
                    .kerning(1)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .overlay(Rectangle().stroke(Wire.Color.dark, lineWidth: Wire.Layout.border))
            }
        }
    }

    private var exerciseInputFields: some View {
        VStack(spacing: Wire.Layout.gap) {
            HStack {
                Text("SET \(manager.nextSetNumber)")
                    .font(Wire.Font.header)
                    .foregroundColor(Wire.Color.white)
                    .kerning(2)
                Spacer()
            }

            // Previous performance hint for next set
            if let prevSet = manager.previousSetsForCurrentExercise
                .first(where: { $0.setNumber == manager.nextSetNumber }),
               !prevSet.isSkipped {
                HStack(spacing: 4) {
                    Text("LAST:")
                        .font(Wire.Font.tiny)
                        .foregroundColor(Wire.Color.dark)
                    Text("\(Int(prevSet.weight))kg × \(prevSet.reps)")
                        .font(Wire.Font.tiny)
                        .foregroundColor(Wire.Color.dark)
                    if let rpe = prevSet.rpe {
                        Text("@\(rpe)")
                            .font(Wire.Font.tiny)
                            .foregroundColor(Wire.Color.dark)
                    }
                    Spacer()
                }
            }

            // Set Type Selector
            HStack(spacing: 0) {
                ForEach(SetType.allCases, id: \.rawValue) { type in
                    Button(action: {
                        Wire.tap()
                        selectedSetType = type
                    }) {
                        Text(type.rawValue)
                            .font(Wire.Font.tiny)
                            .kerning(1)
                            .foregroundColor(selectedSetType == type ? Wire.Color.black : Wire.Color.gray)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(selectedSetType == type ? Wire.Color.white : Wire.Color.black)
                            .overlay(Rectangle().stroke(
                                selectedSetType == type ? Wire.Color.white : Wire.Color.dark,
                                lineWidth: Wire.Layout.border
                            ))
                    }
                }
            }

            HStack(spacing: Wire.Layout.gap) {
                WireNumField(label: "Weight", value: $manager.weightInput, suffix: "kg")
                WireStepper(label: "Reps", value: $manager.repsInput, range: 1...50)
            }

            WireStepper(label: "RPE", value: $manager.rpeInput, range: 1...10)

            HStack(spacing: Wire.Layout.gap) {
                Button(action: {
                    Wire.tap()
                    manager.skipSet()
                    hideKeyboard()
                }) {
                    Text("[ SKIP ]")
                        .font(Wire.Font.body)
                        .foregroundColor(Wire.Color.gray)
                        .kerning(1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Wire.Color.black)
                        .overlay(Rectangle().stroke(Wire.Color.gray, lineWidth: Wire.Layout.border))
                }

                WireButton("LOG SET", inverted: true) {
                    manager.logSet(setType: selectedSetType)
                    hideKeyboard()
                }
            }
        }
    }

    // MARK: - 1RM Row

    private var oneRMRow: some View {
        WireCell {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("EST 1RM")
                        .font(Wire.Font.caption)
                        .foregroundColor(Wire.Color.gray)
                        .kerning(1)

                    Text("\(Int(manager.estimated1RM)) KG")
                        .font(Wire.Font.sub)
                        .foregroundColor(Wire.Color.white)
                }

                Spacer()

                Text("BRZYCKI")
                    .font(Wire.Font.tiny)
                    .foregroundColor(Wire.Color.gray)
            }
        }
    }

    // MARK: - Bottom Bar (ABORT + FINISH)

    private var bottomBar: some View {
        HStack(spacing: 0) {
            // ABORT BUTTON - Kill Switch
            Button(action: { Wire.tap(); showAbortAlert = true }) {
                Text("[ ABORT ]")
                    .font(Wire.Font.body)
                    .kerning(1)
                    .foregroundColor(Wire.Color.danger)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Wire.Color.black)
                    .overlay(Rectangle().stroke(Wire.Color.danger, lineWidth: Wire.Layout.border))
            }

            // FINISH BUTTON
            Button(action: {
                Wire.tap()
                showFinishAlert = true
            }) {
                Text("FINISH")
                    .font(Wire.Font.body)
                    .kerning(2)
                    .foregroundColor(Wire.Color.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Wire.Color.black)
                    .overlay(Rectangle().stroke(Wire.Color.white, lineWidth: Wire.Layout.border))
            }
        }
    }

    // MARK: - PR Banner

    private var prBanner: some View {
        VStack(spacing: 4) {
            Text("PERSONAL RECORD")
                .font(Wire.Font.header)
                .foregroundColor(Wire.Color.black)
                .kerning(2)

            Text(prLabel(manager.lastPRTypes))
                .font(Wire.Font.caption)
                .foregroundColor(Wire.Color.black)
                .kerning(1)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Wire.Color.white)
        .transition(.move(edge: .top).combined(with: .opacity))
        .allowsHitTesting(false)
        .frame(maxHeight: .infinity, alignment: .top)
        .onChange(of: manager.showPRBanner) {
            guard manager.showPRBanner else { return }
            Task {
                try? await Task.sleep(for: .seconds(2))
                withAnimation { manager.showPRBanner = false }
            }
        }
    }

    private func prLabel(_ types: Set<PRType>) -> String {
        let hasWeight = types.contains(.weight)
        let hasE1RM = types.contains(.estimated1RM)
        if hasWeight && hasE1RM { return "WEIGHT + EST 1RM" }
        if hasWeight { return "WEIGHT" }
        return "EST 1RM"
    }

    // MARK: - Timer Overlay

    private var timerOverlay: some View {
        ZStack {
            Wire.Color.black.opacity(0.95).ignoresSafeArea()

            VStack(spacing: 24) {
                Text("REST")
                    .font(Wire.Font.header)
                    .foregroundColor(Wire.Color.gray)
                    .kerning(4)

                WireTimer(seconds: manager.timerValue)

                WireButton("SKIP") {
                    manager.stopTimer()
                }
                .frame(width: 120)
            }
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// REORDER EXERCISES SHEET
// Drag-to-reorder exercise list during active workout
// ═══════════════════════════════════════════════════════════════════════════

struct ReorderExercisesSheet: View {
    @Environment(\.dismiss) private var dismiss
    var manager: WorkoutManager
    @State private var exercises: [Exercise] = []

    var body: some View {
        ZStack {
            Wire.Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("REORDER EXERCISES")
                        .font(Wire.Font.header)
                        .foregroundColor(Wire.Color.white)
                        .kerning(2)

                    Spacer()

                    Button(action: { Wire.tap(); dismiss() }) {
                        Text("DONE")
                            .font(Wire.Font.body)
                            .foregroundColor(Wire.Color.white)
                            .kerning(1)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .overlay(Rectangle().stroke(Wire.Color.white, lineWidth: Wire.Layout.border))
                    }
                }
                .padding(Wire.Layout.pad)
                .overlay(Rectangle().frame(height: Wire.Layout.border).foregroundColor(Wire.Color.white), alignment: .bottom)

                // Drag-to-reorder list
                List {
                    ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
                        reorderRow(exercise: exercise, index: index)
                            .listRowBackground(Wire.Color.black)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 2, leading: Wire.Layout.pad, bottom: 2, trailing: Wire.Layout.pad))
                    }
                    .onMove { source, destination in
                        exercises.move(fromOffsets: source, toOffset: destination)
                        manager.reorderExercises(from: source, to: destination)
                    }
                }
                .listStyle(.plain)
                .environment(\.editMode, .constant(.active))
                .scrollContentBackground(.hidden)
            }
        }
        .onAppear {
            exercises = manager.session.template?.exercises ?? []
        }
    }

    private func reorderRow(exercise: Exercise, index: Int) -> some View {
        HStack(spacing: Wire.Layout.gap) {
            Text("\(index + 1)")
                .font(Wire.Font.body)
                .foregroundColor(Wire.Color.gray)
                .frame(width: 24, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name.uppercased())
                    .font(Wire.Font.body)
                    .foregroundColor(Wire.Color.white)
                    .kerning(1)

                let completedCount = completedSets(for: exercise)
                Text("\(completedCount)/\(exercise.targetSets) SETS")
                    .font(Wire.Font.tiny)
                    .foregroundColor(completedCount >= exercise.targetSets ? Wire.Color.white : Wire.Color.gray)
                    .kerning(0.5)
            }

            Spacer()

            if index == manager.currentExerciseIndex {
                Text("CURRENT")
                    .font(Wire.Font.tiny)
                    .foregroundColor(Wire.Color.black)
                    .kerning(1)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Wire.Color.white)
            }
        }
        .padding(Wire.Layout.pad)
        .background(Wire.Color.black)
        .overlay(Rectangle().stroke(
            index == manager.currentExerciseIndex ? Wire.Color.white : Wire.Color.dark,
            lineWidth: Wire.Layout.border
        ))
    }

    private func completedSets(for exercise: Exercise) -> Int {
        guard let sets = manager.session.sets else { return 0 }
        return sets.filter { $0.exercise?.id == exercise.id && $0.isCompleted && !$0.isSkipped }.count
    }
}
