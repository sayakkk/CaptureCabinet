//
//  CaptureCabinetApp.swift
//  CaptureCabinet
//
//  Created by saya lee on 9/21/25.
//

import SwiftUI
import CoreData

@main
struct CaptureCabinetApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
