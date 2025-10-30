//
//  DesignSystem.swift
//  CaptureCabinet
//
//  Created by saya lee on 10/1/25.
//

import SwiftUI

// MARK: - Color System
extension Color {
    // Primary Colors
    static let primaryBlue = Color(red: 0.0, green: 0.48, blue: 1.0)
    static let primaryBlueLight = Color(red: 0.0, green: 0.48, blue: 1.0).opacity(0.1)
    static let primaryBlueDark = Color(red: 0.0, green: 0.35, blue: 0.8)
    
    // Background Colors
    static let backgroundPrimary = Color(red: 0.98, green: 0.98, blue: 1.0)
    static let backgroundSecondary = Color(red: 0.95, green: 0.95, blue: 0.97)
    static let surfacePrimary = Color.white
    static let surfaceSecondary = Color(red: 0.97, green: 0.97, blue: 0.99)
    
    // Text Colors
    static let textPrimary = Color(red: 0.1, green: 0.1, blue: 0.1)
    static let textSecondary = Color(red: 0.4, green: 0.4, blue: 0.4)
    static let textTertiary = Color(red: 0.6, green: 0.6, blue: 0.6)
    
    // Swipe Action Colors
    static let swipeDelete = Color.red
    static let swipeArchive = Color.blue
}


// MARK: - Spacing
struct Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let xxxl: CGFloat = 32
}

// MARK: - Corner Radius
struct CornerRadius {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 6
    static let md: CGFloat = 8
    static let lg: CGFloat = 12
    static let xl: CGFloat = 16
    static let xxl: CGFloat = 20
}

// MARK: - Shadow
struct Shadow {
    static let small = Color.black.opacity(0.1)
    static let medium = Color.black.opacity(0.15)
    static let large = Color.black.opacity(0.2)
}

