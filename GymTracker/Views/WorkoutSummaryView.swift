import SwiftUI

// MARK: - Workout Summary View

struct WorkoutSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: WorkoutSummaryViewModel

    var body: some View {
        ZStack {
            Wire.Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView {
                    VStack(spacing: Wire.Layout.gap) {
                        hologramSection
                        if !viewModel.prSummaries.isEmpty {
                            prSection
                        }
                        insightsSection
                        if !viewModel.recoveryDeltas.isEmpty {
                            recoverySection
                        }
                    }
                    .padding(Wire.Layout.pad)
                }

                dismissButton
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("DEBRIEF")
                    .font(Wire.Font.header)
                    .foregroundColor(Wire.Color.white)
                    .kerning(4)

                Text(viewModel.session.template?.displayName.uppercased() ?? "SESSION")
                    .font(Wire.Font.caption)
                    .foregroundColor(Wire.Color.gray)
                    .kerning(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(viewModel.durationFormatted)
                    .font(Wire.Font.header)
                    .foregroundColor(Wire.Color.white)

                Text("DURATION")
                    .font(Wire.Font.tiny)
                    .foregroundColor(Wire.Color.gray)
                    .kerning(1)
            }
        }
        .padding(.horizontal, Wire.Layout.pad)
        .padding(.vertical, 10)
        .background(Wire.Color.black)
        .overlay(Rectangle().stroke(Wire.Color.white, lineWidth: Wire.Layout.border))
    }

    // MARK: - Hologram

    private var hologramSection: some View {
        WireCell(highlight: true) {
            VStack(spacing: 4) {
                Text("MUSCLE ACTIVATION")
                    .font(Wire.Font.caption)
                    .foregroundColor(Wire.Color.gray)
                    .kerning(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HologramBodyView(muscleVolumes: viewModel.muscleVolumes)
                    .frame(height: 300)
            }
        }
    }

    // MARK: - PR Section

    private var prSection: some View {
        VStack(alignment: .leading, spacing: Wire.Layout.gap) {
            Text("PERSONAL RECORDS")
                .font(Wire.Font.caption)
                .foregroundColor(Wire.Color.gray)
                .kerning(1)

            ForEach(viewModel.prSummaries) { pr in
                WireCell(highlight: true) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pr.exerciseName.uppercased())
                                .font(Wire.Font.sub)
                                .foregroundColor(Wire.Color.white)
                                .kerning(1)

                            Text("\(Int(pr.weight)) KG")
                                .font(Wire.Font.caption)
                                .foregroundColor(Wire.Color.gray)
                        }

                        Spacer()

                        HStack(spacing: 4) {
                            if pr.types.contains(.weight) {
                                prBadge("WEIGHT PR")
                            }
                            if pr.types.contains(.estimated1RM) {
                                prBadge("1RM PR")
                            }
                        }
                    }
                }
            }
        }
    }

    private func prBadge(_ text: String) -> some View {
        Text(text)
            .font(Wire.Font.tiny)
            .foregroundColor(Wire.Color.black)
            .kerning(1)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Wire.Color.white)
    }

    // MARK: - Insights

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: Wire.Layout.gap) {
            Text("INSIGHTS")
                .font(Wire.Font.caption)
                .foregroundColor(Wire.Color.gray)
                .kerning(1)

            effectiveVolumeCard
            intensityDistributionCard
            sessionDensityCard
        }
    }

    private var effectiveVolumeCard: some View {
        WireCell {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("EFFECTIVE VOLUME")
                        .font(Wire.Font.caption)
                        .foregroundColor(Wire.Color.gray)
                        .kerning(1)
                    Spacer()
                    Text("\(Int(viewModel.effectivePercent * 100))%")
                        .font(Wire.Font.header)
                        .foregroundColor(Wire.Color.white)
                }

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Wire.Color.dark)
                            .frame(height: 4)

                        Rectangle()
                            .fill(Wire.Color.white)
                            .frame(width: geo.size.width * viewModel.effectivePercent, height: 4)
                    }
                }
                .frame(height: 4)

                Text("\(viewModel.effectiveSets) OF \(viewModel.totalSets) SETS EFFECTIVE (RPE 8+)")
                    .font(Wire.Font.tiny)
                    .foregroundColor(Wire.Color.gray)
                    .kerning(0.5)
            }
        }
    }

    private var intensityDistributionCard: some View {
        WireCell {
            VStack(alignment: .leading, spacing: 6) {
                Text("INTENSITY DISTRIBUTION")
                    .font(Wire.Font.caption)
                    .foregroundColor(Wire.Color.gray)
                    .kerning(1)

                // Segmented bar
                GeometryReader { geo in
                    HStack(spacing: 1) {
                        ForEach(viewModel.intensityZones) { zone in
                            if zone.count > 0 {
                                Rectangle()
                                    .fill(zoneColor(zone.label))
                                    .frame(width: max(geo.size.width * zone.fraction - 1, 2))
                            }
                        }
                    }
                }
                .frame(height: 8)

                // Legend
                HStack(spacing: 8) {
                    ForEach(viewModel.intensityZones) { zone in
                        if zone.count > 0 {
                            HStack(spacing: 3) {
                                Circle()
                                    .fill(zoneColor(zone.label))
                                    .frame(width: 6, height: 6)
                                Text("\(zone.label) \(zone.count)")
                                    .font(Wire.Font.tiny)
                                    .foregroundColor(Wire.Color.gray)
                            }
                        }
                    }
                }
            }
        }
    }

    private func zoneColor(_ label: String) -> Color {
        switch label {
        case "WARM-UP":  return Wire.Color.dark
        case "MODERATE": return Wire.Color.gray
        case "HARD":     return Wire.Color.white
        case "MAX":      return Wire.Color.danger
        default:         return Wire.Color.gray
        }
    }

    private var sessionDensityCard: some View {
        WireCell {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SESSION DENSITY")
                        .font(Wire.Font.caption)
                        .foregroundColor(Wire.Color.gray)
                        .kerning(1)

                    Text("\(Int(viewModel.totalVolume)) KG TOTAL")
                        .font(Wire.Font.tiny)
                        .foregroundColor(Wire.Color.gray)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.0f", viewModel.sessionDensity))
                        .font(Wire.Font.header)
                        .foregroundColor(Wire.Color.white)

                    Text("KG/MIN")
                        .font(Wire.Font.tiny)
                        .foregroundColor(Wire.Color.gray)
                        .kerning(1)
                }
            }
        }
    }

    // MARK: - Recovery Impact

    private var recoverySection: some View {
        VStack(alignment: .leading, spacing: Wire.Layout.gap) {
            Text("RECOVERY IMPACT")
                .font(Wire.Font.caption)
                .foregroundColor(Wire.Color.gray)
                .kerning(1)

            ForEach(viewModel.recoveryDeltas) { delta in
                WireCell {
                    HStack {
                        Text(delta.muscle.rawValue.uppercased())
                            .font(Wire.Font.body)
                            .foregroundColor(Wire.Color.white)
                            .kerning(1)

                        Spacer()

                        HStack(spacing: 6) {
                            Circle()
                                .fill(RecoveryColor.from(delta.phaseBefore))
                                .frame(width: 8, height: 8)

                            Text(delta.phaseBefore.rawValue)
                                .font(Wire.Font.tiny)
                                .foregroundColor(Wire.Color.gray)

                            Text(">")
                                .font(Wire.Font.caption)
                                .foregroundColor(Wire.Color.dark)

                            Circle()
                                .fill(RecoveryColor.from(delta.phaseAfter))
                                .frame(width: 8, height: 8)

                            Text(delta.phaseAfter.rawValue)
                                .font(Wire.Font.tiny)
                                .foregroundColor(Wire.Color.gray)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Dismiss

    private var dismissButton: some View {
        WireButton("DISMISS", inverted: true) {
            dismiss()
        }
        .padding(Wire.Layout.pad)
    }
}
