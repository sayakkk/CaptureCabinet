//
//  DesignSystem.swift
//  CaptureCabinet
//
//  Created by saya lee on 10/1/25.
//  Updated for Latest Apple HIG - Modern iOS Design
//

import SwiftUI

// MARK: - Modern iOS Color System (Latest HIG)
extension Color {
    // Primary Accent Colors - Enhanced Vibrancy
    static let accentPrimary = Color(red: 0.0, green: 0.47, blue: 1.0) // Vibrant blue
    static let accentSecondary = Color(red: 0.35, green: 0.31, blue: 0.85) // Deep purple
    static let accentTertiary = Color(red: 0.0, green: 0.77, blue: 0.76) // Bright teal
    static let accentQuaternary = Color(red: 1.0, green: 0.27, blue: 0.23) // Vibrant red

    // Gradient Accents
    static let accentGradient = LinearGradient(
        colors: [accentPrimary, accentSecondary],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let tealGradient = LinearGradient(
        colors: [accentTertiary, accentPrimary],
        startPoint: .top,
        endPoint: .bottom
    )

    // Dynamic Backgrounds - Adapts to light/dark mode
    static let backgroundPrimary = Color(UIColor.systemBackground)
    static let backgroundSecondary = Color(UIColor.secondarySystemBackground)
    static let backgroundTertiary = Color(UIColor.tertiarySystemBackground)

    // Grouped Backgrounds - For lists and cards
    static let groupedBackground = Color(UIColor.systemGroupedBackground)
    static let groupedBackgroundSecondary = Color(UIColor.secondarySystemGroupedBackground)

    // Surface & Materials
    static let surfacePrimary = Color(UIColor.systemBackground)
    static let surfaceElevated = Color(UIColor.secondarySystemBackground)
    static let surfaceOverlay = Color.black.opacity(0.3)

    // Text Colors - System adaptive
    static let textPrimary = Color(UIColor.label)
    static let textSecondary = Color(UIColor.secondaryLabel)
    static let textTertiary = Color(UIColor.tertiaryLabel)
    static let textQuaternary = Color(UIColor.quaternaryLabel)

    // Semantic Colors - iOS 18 Style
    static let destructive = Color(UIColor.systemRed)
    static let warning = Color(UIColor.systemOrange)
    static let success = Color(UIColor.systemGreen)
    static let info = Color(UIColor.systemBlue)

    // Fill Colors - For backgrounds of controls
    static let fillPrimary = Color(UIColor.systemFill)
    static let fillSecondary = Color(UIColor.secondarySystemFill)
    static let fillTertiary = Color(UIColor.tertiarySystemFill)
    static let fillQuaternary = Color(UIColor.quaternarySystemFill)

    // Separator Colors
    static let separator = Color(UIColor.separator)
    static let separatorOpaque = Color(UIColor.opaqueSeparator)

    // Legacy compatibility
    static let primaryBlue = accentPrimary
    static let swipeDelete = destructive
    static let swipeArchive = info
}

// MARK: - Modern Typography System (Latest HIG)
struct Typography {
    // Display - For hero sections
    static let display = Font.system(size: 48, weight: .bold, design: .rounded)

    // Large Titles - Enhanced readability
    static let largeTitle = Font.system(.largeTitle, design: .rounded, weight: .bold)
    static let title1 = Font.system(.title, design: .rounded, weight: .bold)
    static let title2 = Font.system(.title2, design: .rounded, weight: .bold)
    static let title3 = Font.system(.title3, design: .rounded, weight: .semibold)

    // Headlines - SF Pro Rounded
    static let headline = Font.system(.headline, design: .rounded, weight: .semibold)
    static let headlineEmphasized = Font.system(.headline, design: .rounded, weight: .bold)
    static let subheadline = Font.system(.subheadline, design: .rounded, weight: .medium)

    // Body - Default & Rounded
    static let body = Font.body
    static let bodyRounded = Font.system(.body, design: .rounded)
    static let bodyEmphasized = Font.body.weight(.semibold)
    static let callout = Font.callout

    // Captions - Smaller text
    static let caption1 = Font.caption
    static let caption1Rounded = Font.system(.caption, design: .rounded)
    static let caption2 = Font.caption2
    static let footnote = Font.footnote
    static let footnoteRounded = Font.system(.footnote, design: .rounded)
}

// MARK: - iOS 18 Spacing System
struct Spacing {
    // Micro spacing
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8

    // Standard spacing
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20

    // Large spacing
    static let xxl: CGFloat = 24
    static let xxxl: CGFloat = 32
    static let huge: CGFloat = 40
    static let massive: CGFloat = 48

    // Semantic spacing for specific use cases
    static let cardPadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 24
    static let screenPadding: CGFloat = 20
}

// MARK: - iOS 18 Corner Radius
struct CornerRadius {
    static let xs: CGFloat = 6
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24

    // Continuous corner radius (iOS style)
    static let continuous: RoundedCornerStyle = .continuous
}

// MARK: - iOS 18 Shadows & Elevation
struct Elevation {
    // Shadow configurations for different elevation levels
    struct ShadowConfig {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }

    static let none = ShadowConfig(color: .clear, radius: 0, x: 0, y: 0)
    static let small = ShadowConfig(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
    static let medium = ShadowConfig(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
    static let large = ShadowConfig(color: Color.black.opacity(0.16), radius: 16, x: 0, y: 8)
    static let extraLarge = ShadowConfig(color: Color.black.opacity(0.20), radius: 24, x: 0, y: 12)
}

// MARK: - Legacy Shadow Support
struct Shadow {
    static let small = Color.black.opacity(0.08)
    static let medium = Color.black.opacity(0.12)
    static let large = Color.black.opacity(0.16)
}

// MARK: - Modern Animation System (Latest HIG)
struct AnimationCurve {
    // Spring Animations - Fluid & Natural
    static let spring = Animation.spring(response: 0.35, dampingFraction: 0.75, blendDuration: 0.2)
    static let springBouncy = Animation.spring(response: 0.45, dampingFraction: 0.65, blendDuration: 0.2)
    static let springSmooth = Animation.smooth(duration: 0.35, extraBounce: 0.1)
    static let springSnappy = Animation.snappy(duration: 0.3, extraBounce: 0.05)

    // Interactive Springs - For gestures
    static let interactive = Animation.interactiveSpring(response: 0.3, dampingFraction: 0.8, blendDuration: 0.15)
    static let interactiveBouncy = Animation.interactiveSpring(response: 0.4, dampingFraction: 0.65, blendDuration: 0.2)

    // Standard Animations
    static let easeInOut = Animation.easeInOut(duration: 0.3)
    static let easeOut = Animation.easeOut(duration: 0.25)
    static let quick = Animation.easeInOut(duration: 0.2)
    static let smooth = Animation.smooth(duration: 0.4)

    // Keyframe Animations
    static func keyframe(duration: Double = 0.6) -> Animation {
        .spring(response: duration, dampingFraction: 0.7, blendDuration: 0.2)
    }
}

// MARK: - Material Blur Styles
enum BlurStyle {
    case systemThin
    case systemMaterial
    case systemThick
    case systemChromeMaterial
    case systemUltraThinMaterial

    var material: Material {
        switch self {
        case .systemThin: return .thin
        case .systemMaterial: return .regular
        case .systemThick: return .thick
        case .systemChromeMaterial: return .bar
        case .systemUltraThinMaterial: return .ultraThin
        }
    }
}

// MARK: - Modern View Modifiers (Latest HIG)
extension View {
    /// Applies modern card style with enhanced vibrancy
    func modernCardStyle(elevation: Elevation.ShadowConfig = Elevation.small) -> some View {
        self
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
            .shadow(color: elevation.color, radius: elevation.radius, x: elevation.x, y: elevation.y)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
            )
    }

    /// Applies elevated card with strong material
    func elevatedCardStyle() -> some View {
        self
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
            .shadow(color: Elevation.medium.color, radius: Elevation.medium.radius, x: Elevation.medium.x, y: Elevation.medium.y)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
            )
    }

    /// Applies modern primary button style with gradient
    func modernPrimaryButton() -> some View {
        self
            .font(Typography.headline)
            .foregroundStyle(.white)
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.md + 2)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                    .fill(Color.accentGradient)
            )
            .shadow(color: Color.accentPrimary.opacity(0.3), radius: 12, x: 0, y: 6)
    }

    /// Applies modern secondary button style
    func modernSecondaryButton() -> some View {
        self
            .font(Typography.headline)
            .foregroundStyle(Color.accentPrimary)
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.md + 2)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                    .strokeBorder(Color.accentPrimary.opacity(0.3), lineWidth: 1.5)
            )
    }

    /// Applies modern glass morphism effect
    func glassEffect() -> some View {
        self
            .background(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.3), .white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
            .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
    }

    /// Applies interactive scale animation
    func interactiveScale(isPressed: Bool) -> some View {
        self
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .animation(AnimationCurve.interactive, value: isPressed)
    }

    /// Applies modern haptic feedback
    func withHapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) -> some View {
        self.simultaneousGesture(
            TapGesture().onEnded {
                let generator = UIImpactFeedbackGenerator(style: style)
                generator.impactOccurred()
            }
        )
    }
}

