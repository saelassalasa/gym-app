import SwiftUI
import SwiftData

// ═══════════════════════════════════════════════════════════════════════════
// RECOVERY COLORS — Shared across all recovery UI
// ═══════════════════════════════════════════════════════════════════════════

enum RecoveryColor {
    static let ready       = Wire.Color.ready
    static let recovering  = Wire.Color.recovering
    static let fatigued    = Wire.Color.fatigued
    static let atrophy     = Wire.Color.peaked
    static let noData      = Wire.Color.gray

    static func from(_ phase: RecoveryPhase) -> Color {
        switch phase {
        case .ready:        return ready
        case .recovering:   return recovering
        case .fatigued:     return fatigued
        case .atrophyRisk:  return atrophy
        case .noData:       return noData
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// RECOVERY DASHBOARD VIEW
// SRA-based muscle recovery status. Qualitative color-coded states.
// ═══════════════════════════════════════════════════════════════════════════

struct RecoveryDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var statuses: [MuscleStatus] = []

    var body: some View {
        ZStack {
            Wire.Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView {
                    VStack(spacing: Wire.Layout.gap) {
                        legend
                        muscleGrid
                    }
                    .padding(Wire.Layout.pad)
                }
            }
        }
        .task { loadStatuses() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { loadStatuses() }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("RECOVERY")
                .font(Wire.Font.header)
                .foregroundColor(Wire.Color.white)
                .kerning(2)
            Spacer()
            Text("SRA")
                .font(Wire.Font.caption)
                .foregroundColor(Wire.Color.gray)
                .kerning(1)
        }
        .padding(.horizontal, Wire.Layout.pad)
        .padding(.vertical, 8)
        .background(Wire.Color.black)
        .overlay(Rectangle().stroke(Wire.Color.white, lineWidth: Wire.Layout.border))
    }

    // MARK: - Legend

    private var legend: some View {
        HStack(spacing: Wire.Layout.gap) {
            legendItem("READY", RecoveryColor.ready)
            legendItem("RECOVERING", RecoveryColor.recovering)
            legendItem("FATIGUED", RecoveryColor.fatigued)
            legendItem("ATROPHY", RecoveryColor.atrophy)
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
                muscleCard(status)
            }
        }
    }

    private func muscleCard(_ status: MuscleStatus) -> some View {
        let color = RecoveryColor.from(status.phase)

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)

                Text(status.muscle.rawValue.uppercased())
                    .font(Wire.Font.body)
                    .foregroundColor(Wire.Color.white)
                    .kerning(1)

                Spacer()
            }

            Text(status.phase.rawValue)
                .font(Wire.Font.caption)
                .foregroundColor(color)
                .kerning(0.5)

            // Recovery bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Wire.Color.dark)
                        .frame(height: 3)

                    Rectangle()
                        .fill(color)
                        .frame(width: geo.size.width * status.recoveryPercent, height: 3)
                }
            }
            .frame(height: 3)

            if status.hoursUntilReady > 0 {
                Text("\(Int(status.hoursUntilReady))H UNTIL READY")
                    .font(Wire.Font.tiny)
                    .foregroundColor(Wire.Color.gray)
            }
        }
        .padding(Wire.Layout.pad)
        .background(Wire.Color.black)
        .overlay(Rectangle().stroke(color.opacity(0.4), lineWidth: Wire.Layout.border))
    }

    private func loadStatuses() {
        let events = RecoveryEngine.extractRecentEvents(context: modelContext)
        statuses = RecoveryEngine.status(events: events)
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// RECOVERY STRIP — Compact inline version for DashboardView
// Refreshes on scenePhase change (returning from workout).
// ═══════════════════════════════════════════════════════════════════════════

struct RecoveryStripView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var statuses: [MuscleStatus] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("MUSCLE STATUS")
                .font(Wire.Font.caption)
                .foregroundColor(Wire.Color.gray)
                .kerning(1)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 5), spacing: 4) {
                ForEach(statuses) { status in
                    let color = RecoveryColor.from(status.phase)
                    VStack(spacing: 2) {
                        Text(shortName(status.muscle))
                            .font(Wire.Font.tiny)
                            .foregroundColor(color)

                        Circle()
                            .fill(color)
                            .frame(width: 6, height: 6)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .background(Wire.Color.black)
                    .overlay(Rectangle().stroke(color.opacity(0.3), lineWidth: Wire.Layout.border))
                }
            }
        }
        .task { loadStatuses() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { loadStatuses() }
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

    private func loadStatuses() {
        let events = RecoveryEngine.extractRecentEvents(context: modelContext)
        statuses = RecoveryEngine.status(events: events)
    }
}
