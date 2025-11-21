//
//  CaptureCabinetApp.swift
//  CaptureCabinet
//
//  Created by saya lee on 9/21/25.
//  Updated for iOS 18 with Dynamic Island support
//

import SwiftUI
import CoreData

@main
struct CaptureCabinetApp: App {
    let persistenceController = PersistenceController.shared

    init() {
        print("🚀 CaptureCabinetApp: Initializing")
        // Configure screenshot service with Core Data context
        Task { @MainActor in
            print("🔧 CaptureCabinetApp: Configuring ScreenshotCaptureService")
            ScreenshotCaptureService.shared.configure(
                with: PersistenceController.shared.container.viewContext
            )
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .onAppear {
                    print("✅ CaptureCabinet launched with Dynamic Island support")
                }
        }
    }
}

