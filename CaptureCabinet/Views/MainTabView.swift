//
//  MainTabView.swift
//  CaptureCabinet
//
//  Created by saya lee on 10/1/25.
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var selectedScreenshots: Set<String> = []
    
    var body: some View {
        TabView(selection: $selectedTab) {
            RecentScreenshotsView(selectedTab: $selectedTab, selectedScreenshots: $selectedScreenshots)
                .tabItem {
                    Image(systemName: selectedTab == 0 ? "photo.on.rectangle.angled.fill" : "photo.on.rectangle.angled")
                    Text("최근")
                }
                .tag(0)
            
            FoldersView(selectedScreenshots: $selectedScreenshots)
                .tabItem {
                    Image(systemName: selectedTab == 1 ? "folder.fill" : "folder")
                    Text("폴더")
                }
                .tag(1)
        }
        .accentColor(.primaryBlue)
        .onChange(of: selectedTab) { _, newTab in
            // Clear selection when switching tabs
            selectedScreenshots.removeAll()
        }
    }
}

#Preview {
    MainTabView()
}