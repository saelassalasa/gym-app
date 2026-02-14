import SwiftUI

// ═══════════════════════════════════════════════════════════════════════════
//  WIREFRAME PROTOCOL
//  Pure monochrome. Terminal aesthetic. Data density. Zero decoration.
//  NASA Control Panel 1980s. Raw Terminal. Receipt printer.
// ═══════════════════════════════════════════════════════════════════════════

enum Wire {
    
    // ═══════════════════════════════════════════════════════════════════════
    // COLORS - Monochrome Only
    // ═══════════════════════════════════════════════════════════════════════
    enum Color {
        /// OLED Pure Black
        static let black = SwiftUI.Color(hex: "000000")
        
        /// Pure White - Primary
        static let white = SwiftUI.Color(hex: "FFFFFF")
        
        /// Bone White - Slightly warmer
        static let bone = SwiftUI.Color(hex: "F5F5F5")
        
        /// Gray - Secondary text
        static let gray = SwiftUI.Color(hex: "888888")
        
        /// Dark Gray - Tertiary
        static let dark = SwiftUI.Color(hex: "333333")
        
        /// DANGER - Alert Red - ONLY for failure/stop
        static let danger = SwiftUI.Color(hex: "FF0000")
    }
    
    // ═══════════════════════════════════════════════════════════════════════
    // TYPOGRAPHY - 100% Monospaced
    // ═══════════════════════════════════════════════════════════════════════
    enum Font {
        /// Mega numbers - 64pt
        static let mega = SwiftUI.Font.system(size: 64, weight: .black, design: .monospaced)
        
        /// Large numbers - 48pt
        static let large = SwiftUI.Font.system(size: 48, weight: .heavy, design: .monospaced)
        
        /// Header - 20pt
        static let header = SwiftUI.Font.system(size: 20, weight: .bold, design: .monospaced)
        
        /// Subheader - 16pt
        static let sub = SwiftUI.Font.system(size: 16, weight: .semibold, design: .monospaced)
        
        /// Body - 13pt
        static let body = SwiftUI.Font.system(size: 13, weight: .medium, design: .monospaced)
        
        /// Caption - 11pt
        static let caption = SwiftUI.Font.system(size: 11, weight: .regular, design: .monospaced)
        
        /// Tiny - 9pt
        static let tiny = SwiftUI.Font.system(size: 9, weight: .regular, design: .monospaced)
    }
    
    // ═══════════════════════════════════════════════════════════════════════
    // LAYOUT - Dense, Grid-based
    // ═══════════════════════════════════════════════════════════════════════
    enum Layout {
        static let border: CGFloat = 1      // 1px borders
        static let radius: CGFloat = 0      // ZERO. Always.
        static let gap: CGFloat = 8         // Dense spacing
        static let pad: CGFloat = 12        // Standard padding
    }
    
    // ═══════════════════════════════════════════════════════════════════════
    // HAPTICS
    // ═══════════════════════════════════════════════════════════════════════
    static func tap() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }
    
    static func heavy() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }
    
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// HEX COLOR EXTENSION
// ═══════════════════════════════════════════════════════════════════════════
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6: (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default: (r, g, b) = (255, 255, 255)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// WIREFRAME BUTTON
// 1px border. Monospace. Sharp edges. Dense.
// ═══════════════════════════════════════════════════════════════════════════
struct WireButton: View {
    let label: String
    var inverted: Bool = false
    var danger: Bool = false
    let action: () -> Void
    
    init(_ label: String, inverted: Bool = false, danger: Bool = false, action: @escaping () -> Void) {
        self.label = label
        self.inverted = inverted
        self.danger = danger
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            Wire.tap()
            action()
        }) {
            Text(label.uppercased())
                .font(Wire.Font.body)
                .kerning(1.5)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundColor(foreground)
                .background(background)
                .overlay(Rectangle().stroke(stroke, lineWidth: Wire.Layout.border))
        }
        .buttonStyle(WireButtonStyle())
    }
    
    private var foreground: Color {
        if danger { return Wire.Color.danger }
        return inverted ? Wire.Color.black : Wire.Color.white
    }
    
    private var background: Color {
        inverted ? Wire.Color.white : Wire.Color.black
    }
    
    private var stroke: Color {
        danger ? Wire.Color.danger : Wire.Color.white
    }
}

struct WireButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.5 : 1.0)
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// WIREFRAME CELL
// Dense data cell. 1px bordered.
// ═══════════════════════════════════════════════════════════════════════════
struct WireCell<Content: View>: View {
    let content: Content
    var highlight: Bool = false
    
    init(highlight: Bool = false, @ViewBuilder content: () -> Content) {
        self.highlight = highlight
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(Wire.Layout.pad)
            .background(Wire.Color.black)
            .overlay(Rectangle().stroke(highlight ? Wire.Color.white : Wire.Color.dark, lineWidth: Wire.Layout.border))
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// WIREFRAME INPUT
// Terminal-style input. Monospaced. Bordered.
// ═══════════════════════════════════════════════════════════════════════════
struct WireInput: View {
    let label: String
    @Binding var value: String
    var keyboard: UIKeyboardType = .default
    
    init(label: String, value: Binding<String>, keyboard: UIKeyboardType = .default) {
        self.label = label
        self._value = value
        self.keyboard = keyboard
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(Wire.Font.caption)
                .foregroundColor(Wire.Color.gray)
                .kerning(1)
            
            TextField("", text: $value)
                .font(Wire.Font.sub)
                .foregroundColor(Wire.Color.white)
                .keyboardType(keyboard)
                .padding(Wire.Layout.pad)
                .background(Wire.Color.black)
                .overlay(Rectangle().stroke(Wire.Color.white, lineWidth: Wire.Layout.border))
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// WIREFRAME STEPPER
// Dense +/- controls. Minimal.
// ═══════════════════════════════════════════════════════════════════════════
struct WireStepper: View {
    let label: String
    @Binding var value: Int
    var range: ClosedRange<Int> = 1...999
    var step: Int = 1
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(Wire.Font.caption)
                .foregroundColor(Wire.Color.gray)
                .kerning(1)
            
            HStack(spacing: 0) {
                stepButton("-") { if value > range.lowerBound { value -= step } }
                
                Text("\(value)")
                    .font(Wire.Font.header)
                    .foregroundColor(Wire.Color.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Wire.Color.black)
                    .overlay(Rectangle().stroke(Wire.Color.white, lineWidth: Wire.Layout.border))
                
                stepButton("+") { if value < range.upperBound { value += step } }
            }
        }
    }
    
    private func stepButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            Wire.tap()
            action()
        }) {
            Text(symbol)
                .font(Wire.Font.header)
                .foregroundColor(Wire.Color.white)
                .frame(width: 44, height: 44)
                .background(Wire.Color.black)
                .overlay(Rectangle().stroke(Wire.Color.white, lineWidth: Wire.Layout.border))
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// WIREFRAME NUM PAD
// Large number input with suffix
// ═══════════════════════════════════════════════════════════════════════════
struct WireNumField: View {
    let label: String
    @Binding var value: Double
    var suffix: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(Wire.Font.caption)
                .foregroundColor(Wire.Color.gray)
                .kerning(1)
            
            HStack(spacing: 0) {
                TextField("", value: $value, format: .number)
                    .font(Wire.Font.large)
                    .foregroundColor(Wire.Color.white)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .frame(height: 56)
                
                if !suffix.isEmpty {
                    Text(suffix.uppercased())
                        .font(Wire.Font.body)
                        .foregroundColor(Wire.Color.gray)
                        .padding(.trailing, Wire.Layout.pad)
                }
            }
            .background(Wire.Color.black)
            .overlay(Rectangle().stroke(Wire.Color.white, lineWidth: Wire.Layout.border))
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// WIREFRAME TIMER
// Digital countdown. High contrast.
// ═══════════════════════════════════════════════════════════════════════════
struct WireTimer: View {
    let seconds: Int
    
    private var formatted: String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
    
    var body: some View {
        Text(formatted)
            .font(Wire.Font.mega)
            .foregroundColor(seconds <= 10 ? Wire.Color.danger : Wire.Color.white)
            .monospacedDigit()
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// PREVIEW
// ═══════════════════════════════════════════════════════════════════════════
#Preview("Wireframe Protocol") {
    ScrollView {
        VStack(spacing: Wire.Layout.gap) {
            Text("WIREFRAME")
                .font(Wire.Font.header)
                .foregroundColor(Wire.Color.white)
                .kerning(4)
            
            WireButton("PRIMARY", inverted: true) {}
            WireButton("SECONDARY") {}
            WireButton("DANGER", danger: true) {}
            
            WireCell(highlight: true) {
                Text("HIGHLIGHTED CELL")
                    .font(Wire.Font.body)
                    .foregroundColor(Wire.Color.white)
            }
            
            WireInput(label: "Name", value: .constant("SQUAT"))
            WireStepper(label: "Reps", value: .constant(5))
            WireNumField(label: "Weight", value: .constant(100), suffix: "kg")
            WireTimer(seconds: 90)
        }
        .padding(Wire.Layout.pad)
    }
    .background(Wire.Color.black)
}
