//
//  SelectFolderIntent.swift
//  ScreenshotWidget
//
//  App Intent for Dynamic Island folder selection
//

import AppIntents
import Foundation

// MARK: - Select Folder Intent

struct SelectFolderIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Select Folder"
    static var description: IntentDescription = "Save screenshot to the selected folder"

    @Parameter(title: "Folder ID")
    var folderID: String

    init() {
        self.folderID = ""
    }

    init(folderID: String) {
        self.folderID = folderID
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        // Handle folder selection through the main app
        // The service will be called via app group or URL scheme
        print("📂 Folder selected: \(folderID)")

        // Notify the main app to save the screenshot
        NotificationCenter.default.post(
            name: NSNotification.Name("SaveScreenshotToFolder"),
            object: nil,
            userInfo: ["folderID": folderID]
        )

        return .result()
    }
}
