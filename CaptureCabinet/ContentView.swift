//
//  ContentView.swift
//  CaptureCabinet
//
//  Created by saya lee on 9/21/25.
//

import SwiftUI
import CoreData

struct ContentView: View {
    var body: some View {
        MainTabView()
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
}
