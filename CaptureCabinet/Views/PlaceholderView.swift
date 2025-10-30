//
//  PlaceholderView.swift
//  CaptureList
//
//  Target: CaptureList
//

import SwiftUI

struct PlaceholderView: View {
    var message: String
    var icon: String = "photo.on.rectangle.angled"

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.textTertiary)
            
            Text(message)
                .font(.body)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(Spacing.xxxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
