//
//  MainTabView.swift
//  CaptureCabinet
//
//  Created by saya lee on 10/1/25.
//  Updated with native TabView and modern design
//

import SwiftUI
import Photos

enum Tab: Int {
    case recent = 0
    case folders = 1
}

struct DragItem {
    let assetIds: [String]
    let images: [UIImage]
    let startLocation: CGPoint
    var dragOffset: CGSize = .zero

    var currentLocation: CGPoint {
        CGPoint(x: startLocation.x + dragOffset.width, y: startLocation.y + dragOffset.height)
    }
}

struct MainTabView: View {
    @State private var selectedScreenshots: Set<String> = []
    @State private var isDragging = false

    // Drag state for cross-tab drag functionality
    @State private var dragItem: DragItem? = nil
    @State private var dragOffset: CGSize = .zero
    @State private var hasSwitchedToFolders = false

    var body: some View {
        ZStack {
            // Native TabView with modern design
            TabView {
                RecentScreenshotsView(
                    selectedScreenshots: $selectedScreenshots,
                    isDragging: $isDragging,
                    onDragStart: { item in
                        dragItem = item
                    },
                    onDragChange: { offset, item in
                        dragOffset = offset
                        dragItem = item
                    },
                    onDragEnd: {
                        dragItem = nil
                        dragOffset = .zero
                        hasSwitchedToFolders = false
                    }
                )
                .tabItem {
                    Label("최근", systemImage: "photo.on.rectangle.angled")
                }
                .tag(Tab.recent)

                FoldersView(
                    selectedScreenshots: $selectedScreenshots,
                    isDragging: $isDragging,
                    dragItem: dragItem,
                    dragOffset: dragOffset,
                    onDrop: { assetIds in
                        handleDrop(assetIds: assetIds)
                    }
                )
                .tabItem {
                    Label("폴더", systemImage: "folder")
                }
                .tag(Tab.folders)
            }
            .tint(Color(red: 0.0, green: 0.48, blue: 1.0)) // Modern blue accent

            // Drag item overlay (appears above TabView)
            if let item = dragItem {
                DragItemOverlay(item: item)
                    .zIndex(1000)
                    .allowsHitTesting(false)
            }
        }
    }

    private func handleDrop(assetIds: [String]) {
        dragItem = nil
        dragOffset = .zero
        isDragging = false
    }
}

struct DragItemOverlay: View {
    let item: DragItem
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(Array(item.images.enumerated()), id: \.offset) { index, image in
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 104)
                        .clipped()
                        .cornerRadius(CornerRadius.md)
                        .shadow(color: Shadow.medium, radius: 8, x: 0, y: 4)
                        .position(
                            x: item.currentLocation.x + CGFloat(index) * 8,
                            y: item.currentLocation.y + CGFloat(index) * 8
                        )
                        .opacity(index == 0 ? 1.0 : 0.7)
                }
            }
        }
    }
}

#Preview {
    MainTabView()
}