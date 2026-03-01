import SwiftUI
import SwiftData

// ═══════════════════════════════════════════════════════════════════════════
// FREQUENCY TRACKER VIEW
// Weekly per-muscle training frequency analysis with recovery-aware tips.
// ═══════════════════════════════════════════════════════════════════════════

struct FrequencyTrackerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var statuses: [MuscleFrequencyStatus] = []
    @State private var suggestions: [String] = []
    @State private var selectedFrequency: Int = FrequencyEngine.userPreferredFrequency

    var body: some View {
        ZStack {
            Wire.Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(spacing: Wire.Layout.gap) {
                        frequencySelector
                        legend
                        muscleGrid
                        if !suggestions.isEmpty {
                            suggestionsSection
                        }
                    }
                    .padding(Wire.Layout.pad)
                }
            }
        }
        .task { loadData() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { loadData() }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("FREQUENCY")
                .font(Wire.Font.header)
                .foregroundColor(Wire.Color.white)
                .kerning(2)
            Spacer()
            Text("THIS WEEK")
                .font(Wire.Font.caption)
                .foregroundColor(Wire.Color.gray)
                .kerning(1)
        }
        .padding(.horizontal, Wire.Layout.pad)
        .padding(.vertical, 8)
        .background(Wire.Color.black)
        .overlay(Rectangle().stroke(Wire.Color.white, lineWidth: Wire.Layout.border))
    }

    // MARK: - Frequency Selector

    private var frequencySelector: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("OPTIMAL TARGET")
                .font(Wire.Font.caption)
                .foregroundColor(Wire.Color.gray)
                .kerning(1)

            HStack(spacing: 0) {
                ForEach([2, 3, 4], id: \.self) { freq in
                    Button {
                        Wire.tap()
                        selectedFrequency = freq
                        FrequencyEngine.userPreferredFrequency = freq
                        loadData()
                    } label: {
                        Text("\(freq)x/WEEK")
                            .font(Wire.Font.caption)
                            .foregroundColor(selectedFrequency == freq ? Wire.Color.black : Wire.Color.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(selectedFrequency == freq ? Wire.Color.white : Wire.Color.black)
                            .overlay(Rectangle().stroke(Wire.Color.white, lineWidth: Wire.Layout.border))
                    }
                }
            }
        }
    }

    // MARK: - Legend

    private var legend: some View {
        HStack(spacing: Wire.Layout.gap) {
            legendItem("OPTIMAL", verdictColor(.optimal))
            legendItem("UNDER", verdictColor(.undertrained))
            legendItem("OVER", verdictColor(.overtrained))
            legendItem("N/A", verdictColor(.noData))
        }
    }

    private func legendItem(_ label: String, _ color: Color) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(Wire.Font.tiny)
                .foregroundColor(Wire.Color.gray)
        }
    }

    // MARK: - Muscle Grid

    private var muscleGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Wire.Layout.gap) {
            ForEach(statuses) { status in
                frequencyCard(status)
            }
        }
    }

    private func frequencyCard(_ status: MuscleFrequencyStatus) -> some View {
        let color = verdictColor(status.verdict)

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(status.muscle.rawValue.uppercased())
                    .font(Wire.Font.body)
                    .foregroundColor(Wire.Color.white)
                    .kerning(1)
                Spacer()
                Text("\(status.sessionsThisWeek)/\(status.optimalFrequency)x")
                    .font(Wire.Font.body)
                    .foregroundColor(color)
            }

            // Sets progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Wire.Color.dark)
                        .frame(height: 3)
                    Rectangle()
                        .fill(color)
                        .frame(
                            width: geo.size.width * min(1.0, Double(status.setsThisWeek) / Double(max(status.optimalSets, 1))),
                            height: 3
                        )
                }
            }
            .frame(height: 3)

            HStack {
                Text("\(status.setsThisWeek)/\(status.optimalSets) SETS")
                    .font(Wire.Font.tiny)
                    .foregroundColor(Wire.Color.gray)
                Spacer()
                Text(status.verdict.rawValue)
                    .font(Wire.Font.tiny)
                    .foregroundColor(color)
            }
        }
        .padding(Wire.Layout.pad)
        .background(Wire.Color.black)
        .overlay(Rectangle().stroke(color.opacity(0.4), lineWidth: Wire.Layout.border))
    }

    // MARK: - Suggestions

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("// SUGGESTIONS")
                .font(Wire.Font.caption)
                .foregroundColor(Wire.Color.gray)
                .kerning(1)

            ForEach(suggestions, id: \.self) { suggestion in
                Text(suggestion)
                    .font(Wire.Font.tiny)
                    .foregroundColor(Wire.Color.bone)
                    .padding(Wire.Layout.pad)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(Rectangle().stroke(Wire.Color.dark, lineWidth: Wire.Layout.border))
            }
        }
    }

    // MARK: - Helpers

    private func verdictColor(_ verdict: FrequencyVerdict) -> Color {
        switch verdict {
        case .optimal:      return Wire.Color.ready
        case .undertrained: return Wire.Color.recovering
        case .overtrained:  return Wire.Color.fatigued
        case .noData:       return Wire.Color.gray
        }
    }

    private func loadData() {
        statuses = FrequencyEngine.weeklyStatus(context: modelContext)
        let recoveryEvents = RecoveryEngine.extractRecentEvents(context: modelContext)
        let recoveryStatuses = RecoveryEngine.status(events: recoveryEvents)
        suggestions = FrequencyEngine.smartSuggestions(
            frequencyStatuses: statuses,
            recoveryStatuses: recoveryStatuses
        )
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// FREQUENCY STRIP — Compact inline version for DashboardView
// ═══════════════════════════════════════════════════════════════════════════

struct FrequencyStripView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var statuses: [MuscleFrequencyStatus] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("WEEKLY FREQUENCY")
                .font(Wire.Font.caption)
                .foregroundColor(Wire.Color.gray)
                .kerning(1)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 5), spacing: 4) {
                ForEach(statuses) { status in
                    let color = verdictColor(status.verdict)
                    VStack(spacing: 2) {
                        Text(shortName(status.muscle))
                            .font(Wire.Font.tiny)
                            .foregroundColor(color)

                        Text("\(status.sessionsThisWeek)/\(status.optimalFrequency)")
                            .font(Wire.Font.tiny)
                            .foregroundColor(Wire.Color.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .background(Wire.Color.black)
                    .overlay(Rectangle().stroke(color.opacity(0.3), lineWidth: Wire.Layout.border))
                }
            }
        }
        .task { loadData() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { loadData() }
        }
    }

    private func shortName(_ muscle: MuscleGroup) -> String {
        switch muscle {
        case .chest:      return "CHST"
        case .back:       return "BACK"
        case .quads:      return "QUAD"
        case .hamstrings: return "HAMS"
        case .glutes:     return "GLUT"
        case .shoulders:  return "SHLD"
        case .biceps:     return "BICS"
        case .triceps:    return "TRIS"
        case .calves:     return "CALV"
        case .core:       return "CORE"
        }
    }

    private func verdictColor(_ verdict: FrequencyVerdict) -> Color {
        switch verdict {
        case .optimal:      return Wire.Color.ready
        case .undertrained: return Wire.Color.recovering
        case .overtrained:  return Wire.Color.fatigued
        case .noData:       return Wire.Color.gray
        }
    }

    private func loadData() {
        statuses = FrequencyEngine.weeklyStatus(context: modelContext)
    }
}
