//
//  MainTabView.swift
//  CaptureCabinet
//
//  Created by saya lee on 10/1/25.
//  Simplified version - Dynamic Island only
//

import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            RecentScreenshotsView()
                .tabItem {
                    Label("최근", systemImage: "photo.on.rectangle.angled")
                }
                .tag(0)

            FoldersView()
                .tabItem {
                    Label("폴더", systemImage: "folder")
                }
                .tag(1)
        }
        .tint(Color(red: 0.0, green: 0.48, blue: 1.0)) // Modern blue accent
    }
}

#Preview {
    MainTabView()
}
