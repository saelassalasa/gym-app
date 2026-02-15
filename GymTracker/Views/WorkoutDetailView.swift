import SwiftUI
import SwiftData

// ═══════════════════════════════════════════════════════════════════════════
// WORKOUT DETAIL VIEW - DEEP HISTORY INSPECTION
// Read-only view of a completed workout session with full set details
// ═══════════════════════════════════════════════════════════════════════════

struct WorkoutDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let session: WorkoutSession
    @State private var prMap: [UUID: Set<PRType>] = [:]
    
    // Group sets by exercise
    private var exerciseGroups: [(exercise: Exercise, sets: [WorkoutSet])] {
        guard let sets = session.sets else { return [] }
        
        var groups: [UUID: (exercise: Exercise, sets: [WorkoutSet])] = [:]
        
        for set in sets {
            guard let exercise = set.exercise else { continue }
            if groups[exercise.id] == nil {
                groups[exercise.id] = (exercise, [])
            }
            groups[exercise.id]?.sets.append(set)
        }
        
        // Sort sets within each group by set number
        return groups.values
            .map { (exercise: $0.exercise, sets: $0.sets.sorted { $0.setNumber < $1.setNumber }) }
            .sorted { $0.exercise.name < $1.exercise.name }
    }
    
    // Total volume (excluding skipped)
    private var totalVolume: Double {
        guard let sets = session.sets else { return 0 }
        return sets
            .filter { !$0.isSkipped && $0.isCompleted }
            .reduce(0) { $0 + (Double($1.reps) * $1.weight) }
    }
    
    // Set counts
    private var completedSets: Int {
        session.sets?.filter { $0.isCompleted && !$0.isSkipped }.count ?? 0
    }
    
    private var skippedSets: Int {
        session.sets?.filter { $0.isSkipped }.count ?? 0
    }
    
    var body: some View {
        ZStack {
            Wire.Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                header
                
                ScrollView {
                    VStack(spacing: Wire.Layout.gap) {
                        statsCard
                        
                        ForEach(exerciseGroups, id: \.exercise.id) { group in
                            exerciseCard(group.exercise, sets: group.sets)
                        }
                    }
                    .padding(Wire.Layout.pad)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            prMap = PRService.detectPRsForSession(session, context: modelContext)
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(session.template?.name.uppercased() ?? "WORKOUT")
                .font(Wire.Font.header)
                .foregroundColor(Wire.Color.white)
                .kerning(2)
            
            Text(formatFullDate(session.date))
                .font(Wire.Font.caption)
                .foregroundColor(Wire.Color.gray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Wire.Layout.pad)
        .background(Wire.Color.black)
        .overlay(Rectangle().stroke(Wire.Color.white, lineWidth: Wire.Layout.border))
    }
    
    // MARK: - Stats Card
    
    private var statsCard: some View {
        WireCell(highlight: true) {
            HStack(spacing: Wire.Layout.gap) {
                statItem(value: formatVolume(totalVolume), label: "VOLUME")
                Divider().frame(height: 40).background(Wire.Color.dark)
                statItem(value: "\(completedSets)", label: "SETS")
                Divider().frame(height: 40).background(Wire.Color.dark)
                statItem(value: formatDuration(session.duration), label: "TIME")
                if skippedSets > 0 {
                    Divider().frame(height: 40).background(Wire.Color.dark)
                    statItem(value: "\(skippedSets)", label: "SKIPPED")
                }
            }
        }
    }
    
    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(Wire.Font.sub)
                .foregroundColor(Wire.Color.white)
            Text(label)
                .font(Wire.Font.tiny)
                .foregroundColor(Wire.Color.gray)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Exercise Card
    
    private func exerciseCard(_ exercise: Exercise, sets: [WorkoutSet]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Exercise Header
            HStack {
                Text(exercise.name.uppercased())
                    .font(Wire.Font.sub)
                    .foregroundColor(Wire.Color.white)
                    .kerning(1)
                
                Spacer()
                
                Text(exercise.category.rawValue)
                    .font(Wire.Font.tiny)
                    .foregroundColor(Wire.Color.gray)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .overlay(Rectangle().stroke(Wire.Color.dark, lineWidth: 1))
            }
            
            // Sets List
            ForEach(sets, id: \.id) { set in
                setRow(set)
            }
        }
        .padding(Wire.Layout.pad)
        .background(Wire.Color.black)
        .overlay(Rectangle().stroke(Wire.Color.white, lineWidth: Wire.Layout.border))
    }
    
    // MARK: - Set Row
    
    private func setRow(_ set: WorkoutSet) -> some View {
        HStack(spacing: 12) {
            // Set number
            Text("\(set.setNumber)")
                .font(Wire.Font.body)
                .foregroundColor(set.isSkipped ? Wire.Color.dark : Wire.Color.gray)
                .frame(width: 24)
            
            if set.isSkipped {
                // Skipped indicator
                Text("[ SKIPPED ]")
                    .font(Wire.Font.caption)
                    .foregroundColor(Wire.Color.gray)
                    .strikethrough(true, color: Wire.Color.gray)
                
                Spacer()
            } else {
                // Weight
                Text("\(Int(set.weight))kg")
                    .font(Wire.Font.body)
                    .foregroundColor(Wire.Color.white)
                
                Text("×")
                    .font(Wire.Font.body)
                    .foregroundColor(Wire.Color.gray)
                
                // Reps
                Text("\(set.reps)")
                    .font(Wire.Font.body)
                    .foregroundColor(Wire.Color.white)
                
                Spacer()
                
                // RPE (if logged)
                if let rpe = set.rpe {
                    Text("RPE \(rpe)")
                        .font(Wire.Font.caption)
                        .foregroundColor(Wire.Color.gray)
                }
                
                // Estimated 1RM
                if set.reps > 1 && set.reps <= 10 {
                    Text("→ \(Int(set.estimated1RM))kg")
                        .font(Wire.Font.caption)
                        .foregroundColor(Wire.Color.gray)
                }

                // PR Badge
                if let prs = prMap[set.id] {
                    Text(prBadgeLabel(prs))
                        .font(Wire.Font.caption)
                        .foregroundColor(Wire.Color.black)
                        .kerning(0.5)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Wire.Color.white)
                }
            }
        }
        .padding(.vertical, 4)
        .opacity(set.isSkipped ? 0.5 : 1.0)
    }
    
    // MARK: - PR Badge

    private func prBadgeLabel(_ types: Set<PRType>) -> String {
        let hasWeight = types.contains(.weight)
        let hasE1RM = types.contains(.estimated1RM)
        if hasWeight && hasE1RM { return "PR:WT+1RM" }
        if hasWeight { return "PR:WT" }
        return "PR:1RM"
    }

    // MARK: - Formatters
    
    private func formatFullDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, dd MMMM yyyy 'at' HH:mm"
        return f.string(from: date).uppercased()
    }
    
    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1000 {
            return String(format: "%.1fT", volume / 1000)
        }
        return "\(Int(volume))kg"
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let mins = Int(duration) / 60
        if mins >= 60 {
            return "\(mins / 60)h \(mins % 60)m"
        }
        return "\(mins)m"
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// PREVIEW
// ═══════════════════════════════════════════════════════════════════════════

#Preview {
    NavigationStack {
        WorkoutDetailView(session: WorkoutSession(
            date: Date(),
            duration: 3600,
            isCompleted: true
        ))
    }
}
