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
    @State private var selected: Exercise?
    
    var body: some View {
        ZStack {
            Wire.Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                header
                selector
                
                if let ex = selected {
                    chartView(for: ex)
                } else {
                    emptyState
                }
                
                Spacer()
            }
        }
        .onAppear {
            if selected == nil { selected = exercises.first }
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
        .padding(.vertical, 8)
        .background(Wire.Color.black)
        .overlay(Rectangle().stroke(Wire.Color.white, lineWidth: Wire.Layout.border))
    }
    
    private var selector: some View {
        Menu {
            ForEach(exercises) { ex in
                Button(ex.name.uppercased()) { selected = ex }
            }
        } label: {
            HStack {
                Text(selected?.name.uppercased() ?? "SELECT")
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
        .padding(Wire.Layout.pad)
    }
    
    private func chartView(for exercise: Exercise) -> some View {
        let data = getDataPoints(for: exercise)
        
        return Group {
            if data.isEmpty {
                Text("NO DATA")
                    .font(Wire.Font.body)
                    .foregroundColor(Wire.Color.gray)
                    .padding()
            } else {
                Chart {
                    ForEach(data) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Weight", point.weight)
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
                .padding(.horizontal, Wire.Layout.pad)
            }
        }
    }
    
    private var emptyState: some View {
        VStack {
            Spacer()
            Text("SELECT EXERCISE")
                .font(Wire.Font.body)
                .foregroundColor(Wire.Color.gray)
            Spacer()
        }
    }
    
    struct DataPoint: Identifiable {
        let id = UUID()
        let date: Date
        let weight: Double
    }
    
    func getDataPoints(for exercise: Exercise) -> [DataPoint] {
        var points: [DataPoint] = []
        for session in sessions {
            if let sets = session.sets {
                let exSets = sets.filter { $0.exercise?.id == exercise.id }
                if let max = exSets.map({ $0.weight }).max() {
                    points.append(DataPoint(date: session.date, weight: max))
                }
            }
        }
        return points
    }
}
