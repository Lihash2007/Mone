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
    // 1. Ice-Blue / Pastel Frost Canvas & Surfaces (Exact Replication of Reference Images)
    public static let bgCanvas = Color(hex: "EDF4F9")
    public static let bgCanvasGradient = LinearGradient(
        colors: [Color(hex: "F6F9FB"), Color(hex: "EAF2F8")],
        startPoint: .top,
        endPoint: .bottom
    )
    public static let bgCardWhite = Color.white
    public static let bgCardBlue = Color(hex: "D8EBF7")
    public static let bgCardMint = Color(hex: "E4F5EB")
    public static let bgCardYellow = Color(hex: "F8F296")
    public static let bgSegmentContainer = Color(hex: "E2EDF5")
    
    // Core Contrast Accents
    public static let deepBlack = Color(hex: "12141A")
    public static let textPrimary = Color(hex: "10141D")
    public static let textSecondary = Color(hex: "68768A")
    public static let textMuted = Color(hex: "94A3B8")
    
    // Semantic Badges
    public static let badgeGreenBg = Color(hex: "DDF7E8")
    public static let badgeGreenText = Color(hex: "0D9488")
    public static let badgeRedBg = Color(hex: "FFEBEA")
    public static let badgeRedText = Color(hex: "E11D48")
    public static let badgeBlueBg = Color(hex: "CCE7F8")
    public static let badgeBlueText = Color(hex: "0284C7")
    
    // Dynamic Dark & Light Mode Color Helpers
    public static func bgCanvas(isDark: Bool) -> Color {
        isDark ? Color(hex: "090B10") : Color(hex: "EDF4F9")
    }
    
    public static func bgCanvasGradient(isDark: Bool) -> LinearGradient {
        isDark 
            ? LinearGradient(colors: [Color(hex: "0E1119"), Color(hex: "07090F")], startPoint: .top, endPoint: .bottom)
            : LinearGradient(colors: [Color(hex: "F6F9FB"), Color(hex: "EAF2F8")], startPoint: .top, endPoint: .bottom)
    }
    
    public static func cardBg(isDark: Bool) -> Color {
        isDark ? Color(hex: "131722") : Color.white
    }
    
    public static func cardBorder(isDark: Bool) -> Color {
        isDark ? Color.white.opacity(0.08) : Color.clear
    }
    
    public static func textPrimary(isDark: Bool) -> Color {
        isDark ? Color(hex: "F3F6FA") : Color(hex: "10141D")
    }
    
    public static func textSecondary(isDark: Bool) -> Color {
        isDark ? Color(hex: "94A3B8") : Color(hex: "68768A")
    }
    
    public static func textMuted(isDark: Bool) -> Color {
        isDark ? Color(hex: "64748B") : Color(hex: "94A3B8")
    }
    
    public static func bgCardBlue(isDark: Bool) -> Color {
        isDark ? Color(hex: "172435") : Color(hex: "D8EBF7")
    }
    
    public static func bgSegmentContainer(isDark: Bool) -> Color {
        isDark ? Color(hex: "1B212D") : Color(hex: "E2EDF5")
    }
    
    public static func activePillBg(isDark: Bool) -> Color {
        isDark ? Color.white : Color(hex: "12141A")
    }
    
    public static func activePillText(isDark: Bool) -> Color {
        isDark ? Color(hex: "10141D") : Color.white
    }
    
    public static func dockBg(isDark: Bool) -> Color {
        isDark ? Color(hex: "131722") : Color.white
    }
    
    // Legacy Dark Void Tokens (Preserved for compatibility)
    public static let bgDeepVoid = Color(hex: "08090C")
    public static let bgSecondary = Color(hex: "10121A")
    public static let bgCard = Color(hex: "161922")
    public static let emerald = Color(hex: "10B981")
    public static let rose = Color(hex: "FF2E63")
    public static let indigo = Color(hex: "6366F1")
    public static let violet = Color(hex: "A855F7")
    public static let cyan = Color(hex: "00D2FF")
    public static let amber = Color(hex: "F59E0B")
    
    // Glass Surface Gradients
    public static let glassGlow = LinearGradient(
        colors: [Color.white.opacity(0.16), Color.white.opacity(0.03)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    public static let heroBalanceGradient = LinearGradient(
        colors: [Color(hex: "181C26"), Color(hex: "0F1118")],
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

// MARK: - iOS 26 Volumetric Spatial Glass Modifier
public struct SpatialGlassModifier: ViewModifier {
    public var cornerRadius: CGFloat = 26
    public var padding: CGFloat = 18
    public var glowColor: Color = Color.clear
    public var glowRadius: CGFloat = 0
    public var strokeOpacity: Double = 0.22
    
    public func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                ZStack {
                    if glowRadius > 0 {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(glowColor, lineWidth: 2)
                            .blur(radius: glowRadius)
                            .opacity(0.7)
                    }
                    
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                    
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color(hex: "0E1119").opacity(0.72))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(strokeOpacity),
                                Color.white.opacity(0.08),
                                Color.white.opacity(0.02)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.42), radius: 18, x: 0, y: 10)
            .shadow(color: glowColor.opacity(glowRadius > 0 ? 0.25 : 0), radius: glowRadius, x: 0, y: 4)
    }
}

public extension View {
    func glassCard(cornerRadius: CGFloat = 24, padding: CGFloat = 16) -> some View {
        self.modifier(SpatialGlassModifier(cornerRadius: cornerRadius, padding: padding))
    }
    
    func spatialGlass(cornerRadius: CGFloat = 26, padding: CGFloat = 18, glow: Color = .clear, glowRadius: CGFloat = 0) -> some View {
        self.modifier(SpatialGlassModifier(cornerRadius: cornerRadius, padding: padding, glowColor: glow, glowRadius: glowRadius))
    }
    
    func whiteCard(cornerRadius: CGFloat = 24, padding: CGFloat = 18, shadowRadius: CGFloat = 12) -> some View {
        self.modifier(WhiteCardModifier(cornerRadius: cornerRadius, padding: padding, shadowRadius: shadowRadius))
    }
}

// MARK: - Reference Design White Card Modifier
public struct WhiteCardModifier: ViewModifier {
    public var cornerRadius: CGFloat = 24
    public var padding: CGFloat = 18
    public var shadowRadius: CGFloat = 12
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    
    public func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(isDarkMode ? Color(hex: "131722") : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(isDarkMode ? Color.white.opacity(0.08) : Color.clear, lineWidth: 1)
            )
            .shadow(
                color: isDarkMode ? Color.black.opacity(0.35) : Color(hex: "0D2040").opacity(0.06),
                radius: shadowRadius,
                x: 0,
                y: isDarkMode ? 4 : 5
            )
    }
}

// MARK: - Reference Design Black Pill Segmented Control (Exact Screen 1 Replication)
public struct BlackPillSegmentedControl<T: Hashable>: View {
    public let items: [FluidSegmentItem<T>]
    @Binding public var selection: T
    @Namespace private var segmentAnimation
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    
    public init(items: [FluidSegmentItem<T>], selection: Binding<T>) {
        self.items = items
        self._selection = selection
    }
    
    public var body: some View {
        HStack(spacing: 4) {
            ForEach(items) { item in
                let isSelected = selection == item.id
                Button {
                    MoneHaptics.selection()
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.75)) {
                        selection = item.id
                    }
                } label: {
                    HStack(spacing: 6) {
                        if let icon = item.icon {
                            Image(systemName: icon)
                                .font(.system(size: 13, weight: .bold))
                        }
                        Text(item.title)
                            .font(.system(size: 13, weight: isSelected ? .bold : .semibold, design: .rounded))
                    }
                    .foregroundColor(isSelected ? (isDarkMode ? Color(hex: "10141D") : .white) : (isDarkMode ? Color(hex: "94A3B8") : MoneTheme.textSecondary))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        ZStack {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(isDarkMode ? Color.white : MoneTheme.deepBlack)
                                    .matchedGeometryEffect(id: "BLACK_ACTIVE_PILL", in: segmentAnimation)
                                    .shadow(color: (isDarkMode ? Color.white : MoneTheme.deepBlack).opacity(0.25), radius: 6, x: 0, y: 2)
                            }
                        }
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(isDarkMode ? Color(hex: "1B212D") : MoneTheme.bgSegmentContainer)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}


// MARK: - iOS 26 Fluid Magnetic Capsule Segmented Control
public struct FluidSegmentItem<T: Hashable>: Identifiable {
    public let id: T
    public let title: String
    public let icon: String?
    public let accentColor: Color
    
    public init(id: T, title: String, icon: String? = nil, accentColor: Color = MoneTheme.indigo) {
        self.id = id
        self.title = title
        self.icon = icon
        self.accentColor = accentColor
    }
}

public struct FluidSegmentedControl<T: Hashable>: View {
    public let items: [FluidSegmentItem<T>]
    @Binding public var selection: T
    @Namespace private var segmentAnimation
    
    public init(items: [FluidSegmentItem<T>], selection: Binding<T>) {
        self.items = items
        self._selection = selection
    }
    
    public var body: some View {
        HStack(spacing: 4) {
            ForEach(items) { item in
                let isSelected = selection == item.id
                Button {
                    MoneHaptics.impact(.light)
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                        selection = item.id
                    }
                } label: {
                    HStack(spacing: 6) {
                        if let icon = item.icon {
                            Image(systemName: icon)
                                .font(.system(size: 13, weight: .bold))
                        }
                        Text(item.title)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(isSelected ? .white : .white.opacity(0.55))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        ZStack {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                item.accentColor.opacity(0.85),
                                                item.accentColor.opacity(0.65)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .matchedGeometryEffect(id: "FLUID_ACTIVE_PILL", in: segmentAnimation)
                                    .shadow(color: item.accentColor.opacity(0.5), radius: 10, x: 0, y: 3)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(
                                                LinearGradient(
                                                    colors: [Color.white.opacity(0.40), Color.white.opacity(0.05)],
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                ),
                                                lineWidth: 1
                                            )
                                    )
                            }
                        }
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(hex: "0B0D14").opacity(0.85))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.18), Color.white.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

