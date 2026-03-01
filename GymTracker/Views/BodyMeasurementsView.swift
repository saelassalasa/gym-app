import SwiftUI
import SwiftData
import Charts

// MARK: - Body Stats Strip (Dashboard compact preview)
struct BodyStatsStripView: View {
    @Query(sort: \BodyMeasurement.date, order: .reverse)
    private var measurements: [BodyMeasurement]

    var body: some View {
        HStack(spacing: 0) {
            stripCell("WEIGHT", latestWeight)
            stripCell("BF%", latestBF)
            stripCell("WAIST", latestWaist)
        }
    }

    private var latestWeight: String {
        guard let w = measurements.first?.bodyWeight else { return "--" }
        return String(format: "%.1f", w)
    }

    private var latestBF: String {
        guard let bf = measurements.first?.bodyFatPercent else { return "--" }
        return String(format: "%.1f", bf)
    }

    private var latestWaist: String {
        guard let w = measurements.first?.waist else { return "--" }
        return String(format: "%.1f", w)
    }

    private func stripCell(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(Wire.Font.sub)
                .foregroundColor(Wire.Color.white)
            Text(label)
                .font(Wire.Font.tiny)
                .foregroundColor(Wire.Color.gray)
                .kerning(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Wire.Color.black)
        .overlay(Rectangle().stroke(Wire.Color.dark, lineWidth: Wire.Layout.border))
    }
}

// MARK: - Body Measurements View (Full page)
struct BodyMeasurementsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BodyMeasurement.date, order: .reverse)
    private var measurements: [BodyMeasurement]

    @State private var showAddSheet = false
    @State private var measurementToDelete: BodyMeasurement?
    @State private var showDeleteAlert = false

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        ZStack {
            Wire.Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Weight chart
                if measurements.count >= 2 {
                    weightChart
                        .padding(Wire.Layout.pad)
                }

                // Measurement list
                if measurements.isEmpty {
                    Spacer()
                    Text("NO MEASUREMENTS YET")
                        .font(Wire.Font.body)
                        .foregroundColor(Wire.Color.gray)
                        .kerning(1)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: Wire.Layout.gap) {
                            ForEach(measurements) { m in
                                measurementRow(m)
                            }
                        }
                        .padding(Wire.Layout.pad)
                    }
                }

                // Add button
                WireButton("ADD MEASUREMENT", inverted: true) {
                    showAddSheet = true
                }
                .padding(Wire.Layout.pad)
            }
        }
        .navigationTitle("BODY")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $showAddSheet) {
            AddMeasurementSheet()
        }
        .alert("DELETE MEASUREMENT?", isPresented: $showDeleteAlert) {
            Button("DELETE", role: .destructive) {
                if let m = measurementToDelete {
                    modelContext.delete(m)
                    modelContext.saveSafe()
                    measurementToDelete = nil
                }
            }
            Button("CANCEL", role: .cancel) {
                measurementToDelete = nil
            }
        }
    }

    // MARK: - Weight Chart

    private var weightChart: some View {
        let sorted = measurements
            .filter { $0.bodyWeight != nil }
            .sorted { $0.date < $1.date }

        return Chart(sorted) { m in
            LineMark(
                x: .value("DATE", m.date),
                y: .value("KG", m.bodyWeight ?? 0)
            )
            .foregroundStyle(Wire.Color.white)
            .interpolationMethod(.catmullRom)

            PointMark(
                x: .value("DATE", m.date),
                y: .value("KG", m.bodyWeight ?? 0)
            )
            .foregroundStyle(Wire.Color.white)
            .symbolSize(20)
        }
        .chartXAxis {
            AxisMarks(values: .automatic) { _ in
                AxisGridLine().foregroundStyle(Wire.Color.dark)
                AxisValueLabel().foregroundStyle(Wire.Color.gray).font(Wire.Font.tiny)
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic) { _ in
                AxisGridLine().foregroundStyle(Wire.Color.dark)
                AxisValueLabel().foregroundStyle(Wire.Color.gray).font(Wire.Font.tiny)
            }
        }
        .chartPlotStyle { plot in
            plot.background(Wire.Color.black)
        }
        .frame(height: 180)
        .padding(Wire.Layout.pad)
        .overlay(Rectangle().stroke(Wire.Color.dark, lineWidth: Wire.Layout.border))
    }

    // MARK: - Measurement Row

    private func measurementRow(_ m: BodyMeasurement) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(Self.dateFormatter.string(from: m.date).uppercased())
                    .font(Wire.Font.caption)
                    .foregroundColor(Wire.Color.gray)
                    .kerning(1)
                Spacer()
                Button {
                    Wire.tap()
                    measurementToDelete = m
                    showDeleteAlert = true
                } label: {
                    Text("X")
                        .font(Wire.Font.caption)
                        .foregroundColor(Wire.Color.danger)
                }
            }

            HStack(spacing: Wire.Layout.gap) {
                if let w = m.bodyWeight {
                    dataTag("WT", String(format: "%.1f", w), "KG")
                }
                if let bf = m.bodyFatPercent {
                    dataTag("BF", String(format: "%.1f", bf), "%")
                }
                if let c = m.chest {
                    dataTag("CH", String(format: "%.1f", c), "CM")
                }
                if let w = m.waist {
                    dataTag("WA", String(format: "%.1f", w), "CM")
                }
                if let a = m.arms {
                    dataTag("AR", String(format: "%.1f", a), "CM")
                }
                if let l = m.legs {
                    dataTag("LG", String(format: "%.1f", l), "CM")
                }
            }

            if !m.notes.isEmpty {
                Text(m.notes.uppercased())
                    .font(Wire.Font.tiny)
                    .foregroundColor(Wire.Color.gray)
                    .lineLimit(1)
            }
        }
        .padding(Wire.Layout.pad)
        .background(Wire.Color.black)
        .overlay(Rectangle().stroke(Wire.Color.dark, lineWidth: Wire.Layout.border))
    }

    private func dataTag(_ label: String, _ value: String, _ unit: String) -> some View {
        VStack(spacing: 1) {
            Text(label)
                .font(Wire.Font.tiny)
                .foregroundColor(Wire.Color.gray)
                .kerning(1)
            HStack(spacing: 2) {
                Text(value)
                    .font(Wire.Font.body)
                    .foregroundColor(Wire.Color.white)
                Text(unit)
                    .font(Wire.Font.tiny)
                    .foregroundColor(Wire.Color.gray)
            }
        }
    }
}

// MARK: - Add Measurement Sheet

struct AddMeasurementSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var bodyWeight: Double = 0
    @State private var bodyFatPercent: Double = 0
    @State private var chest: Double = 0
    @State private var waist: Double = 0
    @State private var arms: Double = 0
    @State private var legs: Double = 0
    @State private var notes: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Wire.Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Wire.Layout.gap) {
                        Text("NEW MEASUREMENT")
                            .font(Wire.Font.header)
                            .foregroundColor(Wire.Color.white)
                            .kerning(2)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        WireNumField(label: "Body Weight", value: $bodyWeight, suffix: "kg")
                        WireNumField(label: "Body Fat", value: $bodyFatPercent, suffix: "%")
                        WireNumField(label: "Chest", value: $chest, suffix: "cm")
                        WireNumField(label: "Waist", value: $waist, suffix: "cm")
                        WireNumField(label: "Arms", value: $arms, suffix: "cm")
                        WireNumField(label: "Legs", value: $legs, suffix: "cm")

                        WireInput(label: "Notes", value: $notes)

                        WireButton("SAVE", inverted: true) {
                            saveMeasurement()
                        }

                        WireButton("CANCEL", danger: true) {
                            dismiss()
                        }
                    }
                    .padding(Wire.Layout.pad)
                }
            }
            .navigationBarHidden(true)
        }
    }

    private func saveMeasurement() {
        let m = BodyMeasurement(
            bodyWeight: bodyWeight > 0 ? bodyWeight : nil,
            bodyFatPercent: bodyFatPercent > 0 ? bodyFatPercent : nil,
            chest: chest > 0 ? chest : nil,
            waist: waist > 0 ? waist : nil,
            arms: arms > 0 ? arms : nil,
            legs: legs > 0 ? legs : nil,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        modelContext.insert(m)
        modelContext.saveSafe()
        Wire.success()
        dismiss()
    }
}

#Preview {
    NavigationStack {
        BodyMeasurementsView()
    }
    .modelContainer(for: BodyMeasurement.self, inMemory: true)
}
