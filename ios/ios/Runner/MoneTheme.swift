import SwiftUI

// MARK: - Color Hex Extension
public extension Color {
    init(hex: String) {
        let cleanHex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleanHex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch cleanHex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Mone Bespoke Theme Tokens
public struct MoneTheme {
    // Backgrounds
    public static let bgDeepVoid = Color(hex: "08090C")
    public static let bgSecondary = Color(hex: "10121A")
    public static let bgCard = Color(hex: "161922")
    
    // Accents
    public static let emerald = Color(hex: "10B981")
    public static let rose = Color(hex: "F43F5E")
    public static let indigo = Color(hex: "6366F1")
    public static let violet = Color(hex: "8B5CF6")
    public static let cyan = Color(hex: "06B6D4")
    public static let amber = Color(hex: "F59E0B")
    
    // Glass Surface Gradients
    public static let glassGlow = LinearGradient(
        colors: [Color.white.opacity(0.12), Color.white.opacity(0.03)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    public static let heroBalanceGradient = LinearGradient(
        colors: [Color(hex: "181B26"), Color(hex: "11131C")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Tactile Haptics Manager
public struct MoneHaptics {
    public static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
    
    public static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
    
    public static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType = .success) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
}

// MARK: - Bespoke Glass Card View Modifier
public struct GlassCardModifier: ViewModifier {
    public var cornerRadius: CGFloat = 24
    public var padding: CGFloat = 16
    public var borderColor: Color = Color.white.opacity(0.14)
    
    public func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                    
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color(hex: "12141D").opacity(0.65))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.20),
                                Color.white.opacity(0.04)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.35), radius: 12, x: 0, y: 6)
    }
}

public extension View {
    func glassCard(cornerRadius: CGFloat = 24, padding: CGFloat = 16) -> some View {
        self.modifier(GlassCardModifier(cornerRadius: cornerRadius, padding: padding))
    }
}
