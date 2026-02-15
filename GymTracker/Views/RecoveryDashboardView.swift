import SwiftUI
import SwiftData

// ═══════════════════════════════════════════════════════════════════════════
// RECOVERY DASHBOARD VIEW
// SRA-based muscle recovery status. Banister fatigue decay model.
// ═══════════════════════════════════════════════════════════════════════════

struct RecoveryDashboardView: View {
    @Environment(\.modelContext) private var modelContext
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
            legendItem("PEAKED", Wire.Color.white)
            legendItem("READY", Wire.Color.gray)
            legendItem("RECOVERING", Wire.Color.dark)
            legendItem("FATIGUED", Wire.Color.danger)
        }
    }

    private func legendItem(_ label: String, _ color: Color) -> some View {
        HStack(spacing: 4) {
            Rectangle()
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
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(status.muscle.rawValue.uppercased())
                    .font(Wire.Font.body)
                    .foregroundColor(Wire.Color.white)
                    .kerning(1)

                Spacer()

                Text(status.phase.rawValue)
                    .font(Wire.Font.tiny)
                    .foregroundColor(phaseColor(status.phase))
                    .kerning(0.5)
            }

            // Recovery bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Wire.Color.dark)
                        .frame(height: 4)

                    Rectangle()
                        .fill(phaseColor(status.phase))
                        .frame(width: geo.size.width * status.recoveryPercent, height: 4)
                }
            }
            .frame(height: 4)

            HStack {
                Text("\(Int(status.recoveryPercent * 100))%")
                    .font(Wire.Font.caption)
                    .foregroundColor(Wire.Color.white)

                Spacer()

                if status.hoursUntilReady > 0 {
                    Text("\(Int(status.hoursUntilReady))h")
                        .font(Wire.Font.caption)
                        .foregroundColor(Wire.Color.gray)
                }
            }
        }
        .padding(Wire.Layout.pad)
        .background(Wire.Color.black)
        .overlay(Rectangle().stroke(phaseColor(status.phase).opacity(0.5), lineWidth: Wire.Layout.border))
    }

    // MARK: - Helpers

    private func phaseColor(_ phase: RecoveryPhase) -> Color {
        switch phase {
        case .peaked:     return Wire.Color.white
        case .ready:      return Wire.Color.gray
        case .recovering: return Wire.Color.dark
        case .fatigued:   return Wire.Color.danger
        }
    }

    private func loadStatuses() {
        let events = RecoveryEngine.extractRecentEvents(context: modelContext)
        statuses = RecoveryEngine.status(events: events)
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// RECOVERY STRIP — Compact inline version for DashboardView
// ═══════════════════════════════════════════════════════════════════════════

struct RecoveryStripView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var statuses: [MuscleStatus] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("MUSCLE STATUS")
                .font(Wire.Font.caption)
                .foregroundColor(Wire.Color.gray)
                .kerning(1)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 5), spacing: 4) {
                ForEach(statuses) { status in
                    VStack(spacing: 2) {
                        Text(shortName(status.muscle))
                            .font(Wire.Font.tiny)
                            .foregroundColor(stripColor(status.phase))

                        Text("\(Int(status.recoveryPercent * 100))")
                            .font(Wire.Font.caption)
                            .foregroundColor(Wire.Color.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .background(Wire.Color.black)
                    .overlay(Rectangle().stroke(stripColor(status.phase).opacity(0.4), lineWidth: Wire.Layout.border))
                }
            }
        }
        .task { loadStatuses() }
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

    private func stripColor(_ phase: RecoveryPhase) -> Color {
        switch phase {
        case .peaked:     return Wire.Color.white
        case .ready:      return Wire.Color.gray
        case .recovering: return Wire.Color.dark
        case .fatigued:   return Wire.Color.danger
        }
    }

    private func loadStatuses() {
        let events = RecoveryEngine.extractRecentEvents(context: modelContext)
        statuses = RecoveryEngine.status(events: events)
    }
}
