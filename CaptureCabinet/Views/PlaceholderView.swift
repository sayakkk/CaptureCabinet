//
//  PlaceholderView.swift
//  CaptureCabinet
//
//  Modern placeholder with enhanced visual design
//

import SwiftUI

struct PlaceholderView: View {
    var message: String
    var icon: String = "photo.on.rectangle.angled"

    var body: some View {
        VStack(spacing: 20) {
            // Modern gradient icon background
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.gray.opacity(0.12),
                                Color.gray.opacity(0.06)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: icon)
                    .font(.system(size: 44, weight: .medium, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color.gray.opacity(0.6),
                                Color.gray.opacity(0.4)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            Text(message)
                .font(.system(.body, design: .rounded, weight: .medium))
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(Spacing.xxxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
