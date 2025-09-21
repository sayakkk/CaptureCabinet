//
//  PlaceholderView.swift
//  CaptureList
//
//  Target: CaptureList
//

import SwiftUI

struct PlaceholderView: View {
    var message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}
