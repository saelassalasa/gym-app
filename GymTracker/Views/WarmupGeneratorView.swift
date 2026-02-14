import SwiftUI

// ═══════════════════════════════════════════════════════════════════════════
// WARMUP GENERATOR
// Auto-generate warmup sets based on working weight.
// Standard pyramid: Bar → 40% → 60% → 80% → Work
// ═══════════════════════════════════════════════════════════════════════════

struct WarmupGeneratorView: View {
    @Environment(\.dismiss) private var dismiss
    
    let workWeight: Double
    let workReps: Int
    let exerciseName: String
    let onComplete: ([WarmupSet]) -> Void
    
    private var warmupSets: [WarmupSet] {
        generateWarmups()
    }
    
    var body: some View {
        ZStack {
            Wire.Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                header
                
                ScrollView {
                    VStack(spacing: Wire.Layout.gap) {
                        exerciseInfo
                        warmupList
                    }
                    .padding(Wire.Layout.pad)
                }
                
                completeButton
            }
        }
    }
    
    private var header: some View {
        HStack {
            Text("WARMUP GEN")
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
    
    private var exerciseInfo: some View {
        WireCell(highlight: true) {
            VStack(alignment: .leading, spacing: 4) {
                Text(exerciseName.uppercased())
                    .font(Wire.Font.sub)
                    .foregroundColor(Wire.Color.white)
                    .kerning(1)
                
                HStack {
                    Text("WORKING SET:")
                        .font(Wire.Font.caption)
                        .foregroundColor(Wire.Color.gray)
                    
                    Text("\(Int(workWeight)) KG × \(workReps)")
                        .font(Wire.Font.body)
                        .foregroundColor(Wire.Color.white)
                }
            }
        }
    }
    
    private var warmupList: some View {
        VStack(alignment: .leading, spacing: Wire.Layout.gap) {
            Text("GENERATED PYRAMID")
                .font(Wire.Font.caption)
                .foregroundColor(Wire.Color.gray)
                .kerning(1)
            
            ForEach(Array(warmupSets.enumerated()), id: \.offset) { index, set in
                warmupRow(set: set, index: index)
            }
            
            // Working set row
            workingSetRow
        }
    }
    
    private func warmupRow(set: WarmupSet, index: Int) -> some View {
        WireCell {
            HStack {
                // Set number
                Text("\(index + 1)")
                    .font(Wire.Font.body)
                    .foregroundColor(Wire.Color.gray)
                    .frame(width: 24, alignment: .leading)
                
                // Percentage
                Text("\(Int(set.percentage))%")
                    .font(Wire.Font.caption)
                    .foregroundColor(Wire.Color.gray)
                    .frame(width: 40, alignment: .leading)
                
                // Weight x Reps
                HStack(spacing: 4) {
                    Text("\(Int(set.weight))")
                        .font(Wire.Font.sub)
                        .foregroundColor(Wire.Color.white)
                    
                    Text("KG")
                        .font(Wire.Font.caption)
                        .foregroundColor(Wire.Color.gray)
                    
                    Text("×")
                        .foregroundColor(Wire.Color.gray)
                    
                    Text("\(set.reps)")
                        .font(Wire.Font.sub)
                        .foregroundColor(Wire.Color.white)
                }
                
                Spacer()
            }
        }
    }
    
    private var workingSetRow: some View {
        WireCell(highlight: true) {
            HStack {
                Text("→")
                    .font(Wire.Font.body)
                    .foregroundColor(Wire.Color.white)
                    .frame(width: 24, alignment: .leading)
                
                Text("WORK")
                    .font(Wire.Font.caption)
                    .foregroundColor(Wire.Color.white)
                    .frame(width: 40, alignment: .leading)
                
                HStack(spacing: 4) {
                    Text("\(Int(workWeight))")
                        .font(Wire.Font.sub)
                        .foregroundColor(Wire.Color.white)
                    
                    Text("KG")
                        .font(Wire.Font.caption)
                        .foregroundColor(Wire.Color.gray)
                    
                    Text("×")
                        .foregroundColor(Wire.Color.gray)
                    
                    Text("\(workReps)")
                        .font(Wire.Font.sub)
                        .foregroundColor(Wire.Color.white)
                }
                
                Spacer()
            }
        }
    }
    
    private var completeButton: some View {
        WireButton("USE THESE WARMUPS", inverted: true) {
            onComplete(warmupSets)
            dismiss()
        }
        .padding(Wire.Layout.pad)
    }
    
    // ═══════════════════════════════════════════════════════════════════════
    // WARMUP GENERATION LOGIC
    // ═══════════════════════════════════════════════════════════════════════
    
    private func generateWarmups() -> [WarmupSet] {
        var sets: [WarmupSet] = []
        
        // Bar only (20kg)
        if workWeight >= 40 {
            sets.append(WarmupSet(percentage: 0, weight: 20, reps: 10))
        }
        
        // 40% of working weight
        if workWeight >= 60 {
            let weight40 = roundToNearest(workWeight * 0.4, nearest: 2.5)
            if weight40 > 20 {
                sets.append(WarmupSet(percentage: 40, weight: weight40, reps: 5))
            }
        }
        
        // 60% of working weight
        if workWeight >= 80 {
            let weight60 = roundToNearest(workWeight * 0.6, nearest: 2.5)
            sets.append(WarmupSet(percentage: 60, weight: weight60, reps: 3))
        }
        
        // 80% of working weight
        if workWeight >= 60 {
            let weight80 = roundToNearest(workWeight * 0.8, nearest: 2.5)
            sets.append(WarmupSet(percentage: 80, weight: weight80, reps: 2))
        }
        
        return sets
    }
    
    private func roundToNearest(_ value: Double, nearest: Double) -> Double {
        (value / nearest).rounded() * nearest
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// WARMUP SET MODEL
// ═══════════════════════════════════════════════════════════════════════════
struct WarmupSet {
    let percentage: Int
    let weight: Double
    let reps: Int
}

#Preview {
    WarmupGeneratorView(
        workWeight: 100,
        workReps: 5,
        exerciseName: "Squat"
    ) { _ in }
}
