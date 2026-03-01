import SwiftUI

// ═══════════════════════════════════════════════════════════════════════════
// PLATE CALCULATOR
// Visual plate loading display. Shows exactly what to put on the bar.
// ═══════════════════════════════════════════════════════════════════════════

struct PlateCalculatorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var targetWeight: Double = 100
    @State private var barWeight: Double = 20
    
    // Plate inventory (kg) - Ordered large to small
    let plates: [Double] = [25, 20, 15, 10, 5, 2.5, 1.25]
    
    // Calculate plates needed per side
    private var platesPerSide: [Double] {
        guard targetWeight.isFinite, barWeight.isFinite,
              targetWeight >= 0, barWeight >= 0,
              targetWeight >= barWeight, targetWeight <= 2000 else { return [] }
        var remaining = (targetWeight - barWeight) / 2

        var result: [Double] = []
        for plate in plates {
            while remaining >= plate {
                result.append(plate)
                remaining -= plate
                remaining = (remaining * 100).rounded() / 100
            }
        }
        return result
    }
    
    private var totalPerSide: Double {
        platesPerSide.reduce(0, +)
    }
    
    private var achievedWeight: Double {
        barWeight + (totalPerSide * 2)
    }
    
    private var isExact: Bool {
        abs(achievedWeight - targetWeight) < 0.01
    }
    
    var body: some View {
        ZStack {
            Wire.Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                header
                
                ScrollView {
                    VStack(spacing: Wire.Layout.gap) {
                        inputSection
                        plateVisualization
                        summary
                    }
                    .padding(Wire.Layout.pad)
                }
            }
        }
    }
    
    private var header: some View {
        HStack {
            Text("PLATE CALC")
                .font(Wire.Font.header)
                .foregroundColor(Wire.Color.white)
                .kerning(2)
            
            Spacer()
            
            Button(action: { dismiss() }) {
                Text("×")
                    .font(Wire.Font.header)
                    .foregroundColor(Wire.Color.gray)
            }
        }
        .padding(Wire.Layout.pad)
        .background(Wire.Color.black)
        .overlay(Rectangle().stroke(Wire.Color.white, lineWidth: Wire.Layout.border))
    }
    
    private var inputSection: some View {
        HStack(spacing: Wire.Layout.gap) {
            WireNumField(label: "Target", value: $targetWeight, suffix: "kg")
            
            VStack(alignment: .leading, spacing: 4) {
                Text("BAR")
                    .font(Wire.Font.caption)
                    .foregroundColor(Wire.Color.gray)
                    .kerning(1)
                
                HStack(spacing: 0) {
                    barButton(20)
                    barButton(15)
                    barButton(10)
                }
            }
        }
    }
    
    private func barButton(_ weight: Double) -> some View {
        Button(action: {
            Wire.tap()
            barWeight = weight
        }) {
            Text("\(Int(weight))")
                .font(Wire.Font.body)
                .foregroundColor(barWeight == weight ? Wire.Color.black : Wire.Color.white)
                .frame(width: 40, height: 44)
                .background(barWeight == weight ? Wire.Color.white : Wire.Color.black)
                .overlay(Rectangle().stroke(Wire.Color.white, lineWidth: Wire.Layout.border))
        }
    }
    
    private var plateVisualization: some View {
        WireCell(highlight: true) {
            VStack(spacing: Wire.Layout.gap) {
                Text("PER SIDE")
                    .font(Wire.Font.caption)
                    .foregroundColor(Wire.Color.gray)
                    .kerning(1)
                
                if platesPerSide.isEmpty && targetWeight >= barWeight && targetWeight > 0 && barWeight >= 0 {
                    Text("BAR ONLY")
                        .font(Wire.Font.large)
                        .foregroundColor(Wire.Color.white)
                } else if platesPerSide.isEmpty {
                    Text("—")
                        .font(Wire.Font.large)
                        .foregroundColor(Wire.Color.gray)
                } else {
                    // Visual stack
                    HStack(spacing: 4) {
                        // Bar representation
                        Rectangle()
                            .fill(Wire.Color.gray)
                            .frame(width: 20, height: 120)
                        
                        // Plates (visual blocks)
                        ForEach(Array(platesPerSide.enumerated()), id: \.offset) { index, plate in
                            plateBlock(weight: plate)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 140)
                    
                    // Text list
                    Text(platesPerSide.map { formatPlate($0) }.joined(separator: " + "))
                        .font(Wire.Font.body)
                        .foregroundColor(Wire.Color.white)
                        .kerning(1)
                }
            }
        }
    }
    
    private func plateBlock(weight: Double) -> some View {
        let height = plateHeight(for: weight)
        let width = plateWidth(for: weight)
        
        return VStack(spacing: 2) {
            Rectangle()
                .fill(Wire.Color.white)
                .frame(width: width, height: height)
            
            Text(formatPlate(weight))
                .font(Wire.Font.tiny)
                .foregroundColor(Wire.Color.gray)
        }
    }
    
    private func plateHeight(for weight: Double) -> CGFloat {
        switch weight {
        case 25: return 100
        case 20: return 90
        case 15: return 80
        case 10: return 70
        case 5: return 50
        case 2.5: return 40
        case 1.25: return 30
        default: return 60
        }
    }
    
    private func plateWidth(for weight: Double) -> CGFloat {
        switch weight {
        case 25, 20: return 20
        case 15, 10: return 16
        case 5: return 12
        case 2.5, 1.25: return 8
        default: return 14
        }
    }
    
    private func formatWeight(_ weight: Double) -> String {
        weight.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(weight))"
            : String(format: "%.1f", weight)
    }

    private func formatPlate(_ weight: Double) -> String {
        if weight == floor(weight) {
            return "\(Int(weight))"
        }
        return String(format: "%.2g", weight)
    }
    
    private var summary: some View {
        WireCell {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("TOTAL")
                        .font(Wire.Font.caption)
                        .foregroundColor(Wire.Color.gray)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(formatWeight(achievedWeight))
                            .font(Wire.Font.large)
                            .foregroundColor(isExact ? Wire.Color.white : Wire.Color.danger)
                        
                        Text("KG")
                            .font(Wire.Font.body)
                            .foregroundColor(Wire.Color.gray)
                    }
                }
                
                Spacer()
                
                if !isExact && targetWeight > 0 {
                    Text("≠ \(formatWeight(targetWeight))")
                        .font(Wire.Font.body)
                        .foregroundColor(Wire.Color.danger)
                }
            }
        }
    }
}

#Preview {
    PlateCalculatorView()
}
