//
//  MainTabView.swift
//  CaptureCabinet
//
//  Created by saya lee on 10/1/25.
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
    @State private var currentTab: Tab = .recent
    @State private var selectedScreenshots: Set<String> = []
    @State private var isDragging = false
    
    // Drag state for custom tab container
    @State private var dragItem: DragItem? = nil
    @State private var dragOffset: CGSize = .zero
    @State private var hasSwitchedToFolders = false
    
    var body: some View {
        ZStack {
            // Tab content
            if currentTab == .recent {
                RecentScreenshotsView(
                    selectedTab: Binding(
                        get: { currentTab.rawValue },
                        set: { currentTab = Tab(rawValue: $0) ?? .recent }
                    ),
                    selectedScreenshots: $selectedScreenshots,
                    isDragging: $isDragging,
                    onDragStart: { item in
                        dragItem = item
                    },
                    onDragChange: { offset, item in
                        // Update drag offset first
                        dragOffset = offset
                        dragItem = item
                        
                        // Switch to folders tab when dragging right 150px (only once)
                        if offset.width > 150 && currentTab == .recent && !hasSwitchedToFolders {
                            hasSwitchedToFolders = true
                            // Switch tabs asynchronously to avoid blocking
                            DispatchQueue.main.async {
                                currentTab = .folders
                            }
                        }
                    },
                    onDragEnd: {
                        dragItem = nil
                        dragOffset = .zero
                        hasSwitchedToFolders = false
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .leading),
                    removal: .move(edge: .leading)
                ))
            } else if currentTab == .folders {
                FoldersView(
                    selectedScreenshots: $selectedScreenshots,
                    isDragging: $isDragging,
                    dragItem: dragItem,
                    dragOffset: dragOffset,
                    onDrop: { assetIds in
                        handleDrop(assetIds: assetIds)
                    }
                )
                .id("foldersView") // Stable identity for view
            }
            
            // Drag item overlay
            if let item = dragItem {
                DragItemOverlay(item: item)
                    .zIndex(1000)
                    .allowsHitTesting(false)
            }
            
            // Custom tab bar
            VStack {
                Spacer()
                CustomTabBar(
                    currentTab: $currentTab,
                    isDragging: isDragging
                )
            }
            .zIndex(100)
        }
        .onChange(of: currentTab) { oldTab, newTab in
            // Clear selection when switching tabs, but only if not dragging
            // Use async to avoid blocking during drag
            if !isDragging && oldTab != newTab {
                DispatchQueue.main.async {
                    selectedScreenshots.removeAll()
                }
            }
        }
    }
    
    private func handleDrop(assetIds: [String]) {
        // Drop handling is done in FoldersView
        dragItem = nil
        dragOffset = .zero
        isDragging = false
    }
}

struct CustomTabBar: View {
    @Binding var currentTab: Tab
    let isDragging: Bool
    
    var body: some View {
        HStack(spacing: 0) {
            TabButton(
                icon: "photo.on.rectangle.angled",
                selectedIcon: "photo.on.rectangle.angled.fill",
                title: "최근",
                isSelected: currentTab == .recent,
                isDisabled: isDragging
            ) {
                if !isDragging {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        currentTab = .recent
                    }
                }
            }
            
            TabButton(
                icon: "folder",
                selectedIcon: "folder.fill",
                title: "폴더",
                isSelected: currentTab == .folders,
                isDisabled: isDragging
            ) {
                if !isDragging {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        currentTab = .folders
                    }
                }
            }
        }
        .frame(height: 60)
        .background(
            Color.surfacePrimary
                .shadow(color: Shadow.small, radius: 8, x: 0, y: -2)
        )
    }
}

struct TabButton: View {
    let icon: String
    let selectedIcon: String
    let title: String
    let isSelected: Bool
    let isDisabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: isSelected ? selectedIcon : icon)
                    .font(.system(size: 20))
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .foregroundColor(isSelected ? .primaryBlue : .textSecondary)
            .opacity(isDisabled ? 0.5 : 1.0)
        }
        .disabled(isDisabled)
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