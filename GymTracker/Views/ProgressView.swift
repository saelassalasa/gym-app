import SwiftUI
import SwiftData
import Charts

// ═══════════════════════════════════════════════════════════════════════════
// PROGRESS VIEW
// Wireframe charts. Minimal decoration.
// ═══════════════════════════════════════════════════════════════════════════

struct ProgressView: View {
    @Query private var exercises: [Exercise]
    @Query(sort: \WorkoutSession.date, order: .forward) private var sessions: [WorkoutSession]
    @State private var selectedName: String?
    @State private var chartMode: ChartMode = .weight
    @State private var cachedNames: [String] = []
    @State private var cachedDataPoints: [DataPoint] = []

    enum ChartMode {
        case weight, volume, e1rm
    }

    var body: some View {
        ZStack {
            Wire.Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView {
                    VStack(spacing: Wire.Layout.gap) {
                        selector

                        if selectedName != nil {
                            summaryStats(data: cachedDataPoints)
                            chartPicker
                            chartView(data: cachedDataPoints)
                        } else {
                            emptyState
                        }
                    }
                    .padding(.horizontal, Wire.Layout.pad)
                    .padding(.top, Wire.Layout.gap)
                }

                Spacer(minLength: 0)
            }
        }
        .onAppear {
            updateNames()
            if selectedName == nil { selectedName = cachedNames.first }
            updateDataPoints()
        }
        .onChange(of: exercises.count) {
            updateNames()
        }
        .onChange(of: selectedName) {
            updateDataPoints()
        }
    }

    private var header: some View {
        HStack {
            Text("PROGRESS")
                .font(Wire.Font.header)
                .foregroundColor(Wire.Color.white)
                .kerning(2)
            Spacer()
        }
        .padding(.horizontal, Wire.Layout.pad)
        .padding(.vertical, Wire.Layout.gap)
        .background(Wire.Color.black)
        .overlay(Rectangle().stroke(Wire.Color.white, lineWidth: Wire.Layout.border))
    }

    // MARK: - Exercise Selector (grouped by name)

    private var selector: some View {
        Menu {
            ForEach(cachedNames, id: \.self) { name in
                Button(name.uppercased()) { selectedName = name }
            }
        } label: {
            HStack {
                Text(selectedName?.uppercased() ?? "SELECT")
                    .font(Wire.Font.body)
                    .foregroundColor(Wire.Color.black)
                    .kerning(1)
                Spacer()
                Text("▼")
                    .font(Wire.Font.body)
                    .foregroundColor(Wire.Color.black)
            }
            .padding(Wire.Layout.pad)
            .background(Wire.Color.white)
        }
    }

    // MARK: - Summary Stats

    private func summaryStats(data: [DataPoint]) -> some View {
        HStack(spacing: 0) {
            statCell("BEST", data.map(\.weight).max().map { "\(Int($0))" } ?? "—")
            statCell("EST 1RM", data.map(\.estimated1RM).max().map { "\(Int($0))" } ?? "—")
            statCell("VOLUME", {
                let total = data.map(\.volume).reduce(0, +)
                if total >= 1000 {
                    return String(format: "%.1fK", total / 1000)
                }
                return "\(Int(total))"
            }())
        }
    }

    private func statCell(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(Wire.Font.header)
                .foregroundColor(Wire.Color.white)
            Text(label)
                .font(Wire.Font.tiny)
                .foregroundColor(Wire.Color.gray)
                .kerning(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Wire.Layout.gap)
        .background(Wire.Color.black)
        .overlay(Rectangle().stroke(Wire.Color.white, lineWidth: Wire.Layout.border))
    }

    // MARK: - Chart Mode Picker

    private var chartPicker: some View {
        HStack(spacing: 0) {
            chartTab("WEIGHT", mode: .weight)
            chartTab("VOLUME", mode: .volume)
            chartTab("EST 1RM", mode: .e1rm)
        }
    }

    private func chartTab(_ label: String, mode: ChartMode) -> some View {
        let isSelected = chartMode == mode
        return Button {
            Wire.tap()
            chartMode = mode
        } label: {
            Text(label)
                .font(Wire.Font.caption)
                .kerning(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Wire.Layout.pad)
                .foregroundColor(isSelected ? Wire.Color.black : Wire.Color.white)
                .background(isSelected ? Wire.Color.white : Wire.Color.black)
                .overlay(Rectangle().stroke(Wire.Color.white, lineWidth: Wire.Layout.border))
        }
        .buttonStyle(WireButtonStyle())
    }

    // MARK: - Chart

    private func chartView(data: [DataPoint]) -> some View {
        Group {
            if data.isEmpty {
                Text("NO DATA")
                    .font(Wire.Font.body)
                    .foregroundColor(Wire.Color.gray)
                    .frame(height: 250)
                    .frame(maxWidth: .infinity)
            } else {
                Chart {
                    ForEach(data) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Value", chartValue(for: point))
                        )
                        .foregroundStyle(Wire.Color.white)
                        .symbol {
                            Rectangle()
                                .fill(Wire.Color.white)
                                .frame(width: 6, height: 6)
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [4]))
                            .foregroundStyle(Wire.Color.dark)
                        AxisValueLabel()
                            .foregroundStyle(Wire.Color.gray)
                            .font(Wire.Font.tiny)
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .foregroundStyle(Wire.Color.gray)
                            .font(Wire.Font.tiny)
                    }
                }
                .frame(height: 250)
                .padding(Wire.Layout.pad)
                .background(Wire.Color.black)
                .overlay(Rectangle().stroke(Wire.Color.white, lineWidth: Wire.Layout.border))
            }
        }
    }

    private func chartValue(for point: DataPoint) -> Double {
        switch chartMode {
        case .weight: return point.weight
        case .volume: return point.volume
        case .e1rm: return point.estimated1RM
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack {
            Spacer()
            Text("SELECT EXERCISE")
                .font(Wire.Font.body)
                .foregroundColor(Wire.Color.gray)
            Spacer()
        }
    }

    // MARK: - Cache Helpers

    private func updateNames() {
        let grouped = Dictionary(grouping: exercises, by: { $0.name.lowercased() })
        cachedNames = grouped.keys
            .compactMap { key in grouped[key]?.first?.name }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private func updateDataPoints() {
        guard let name = selectedName else { cachedDataPoints = []; return }
        cachedDataPoints = getDataPoints(forExerciseName: name)
    }

    // MARK: - Data

    struct DataPoint: Identifiable {
        let id = UUID()
        let date: Date
        let weight: Double
        let volume: Double
        let estimated1RM: Double
    }

    func getDataPoints(forExerciseName name: String) -> [DataPoint] {
        let lowered = name.lowercased()
        var points: [DataPoint] = []

        for session in sessions {
            guard let sets = session.sets else { continue }
            let matchingSets = sets.filter { $0.exercise?.name.lowercased() == lowered }
            guard !matchingSets.isEmpty else { continue }

            let maxWeight = matchingSets.map(\.weight).max() ?? 0
            let totalVolume = matchingSets.reduce(0.0) { $0 + Double($1.reps) * $1.weight }
            let bestE1RM = matchingSets.map(\.estimated1RM).max() ?? 0

            points.append(DataPoint(
                date: session.date,
                weight: maxWeight,
                volume: totalVolume,
                estimated1RM: bestE1RM
            ))
        }

        return points.sorted { $0.date < $1.date }
    }
}
