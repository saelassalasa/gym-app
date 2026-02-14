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
    
    init(manager: WorkoutManager) {
        _manager = State(initialValue: manager)
    }
    
    var body: some View {
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
        .alert("INCINERATE SESSION?", isPresented: $showAbortAlert) {
            Button("ABORT", role: .destructive) {
                manager.abortSession()
                dismiss()
            }
            Button("CANCEL", role: .cancel) {}
        } message: {
            Text("All logged sets will be permanently destroyed.")
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("DONE") { hideKeyboard() }
                    .font(Wire.Font.body)
                    .foregroundColor(Wire.Color.white)
            }
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { manager.previousExercise() }) {
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
                
                Button(action: { manager.nextExercise() }) {
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
            
            Button(action: { showPlateCalc = true }) {
                Text("PLATES")
                    .font(Wire.Font.caption)
                    .foregroundColor(Wire.Color.white)
                    .kerning(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .overlay(Rectangle().stroke(Wire.Color.white, lineWidth: Wire.Layout.border))
            }
            
            Button(action: { showWarmup = true }) {
                Text("WARMUP")
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
            if !manager.setsForCurrentExercise.isEmpty {
                ForEach(manager.setsForCurrentExercise, id: \.id) { set in
                    setRow(set)
                }
            }
        }
    }
    
    private func setRow(_ set: WorkoutSet) -> some View {
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
                
                Text("✓")
                    .font(Wire.Font.body)
                    .foregroundColor(Wire.Color.white)
            }
        }
        .padding(8)
        .background(Wire.Color.black)
        .overlay(Rectangle().stroke(set.isSkipped ? Wire.Color.dark : Wire.Color.dark, lineWidth: Wire.Layout.border))
        .opacity(set.isSkipped ? 0.6 : 1.0)
    }
    
    // MARK: - Input Section
    
    private var inputSection: some View {
        VStack(spacing: Wire.Layout.gap) {
            HStack {
                Text("SET \(manager.nextSetNumber)")
                    .font(Wire.Font.header)
                    .foregroundColor(Wire.Color.white)
                    .kerning(2)
                Spacer()
            }
            
            HStack(spacing: Wire.Layout.gap) {
                WireNumField(label: "Weight", value: $manager.weightInput, suffix: "kg")
                WireStepper(label: "Reps", value: $manager.repsInput, range: 1...30)
            }
            
            WireStepper(label: "RPE", value: $manager.rpeInput, range: 1...10)
            
            // LOG + SKIP buttons
            HStack(spacing: Wire.Layout.gap) {
                // SKIP BUTTON - Hollow, cautionary style
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
                
                // LOG SET BUTTON
                WireButton("LOG SET", inverted: true) {
                    manager.logSet()
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
                
                Text("EPLEY")
                    .font(Wire.Font.tiny)
                    .foregroundColor(Wire.Color.gray)
            }
        }
    }
    
    // MARK: - Bottom Bar (ABORT + FINISH)
    
    private var bottomBar: some View {
        HStack(spacing: 0) {
            // ABORT BUTTON - Kill Switch
            Button(action: { showAbortAlert = true }) {
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
                manager.finishWorkout()
                dismiss()
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
