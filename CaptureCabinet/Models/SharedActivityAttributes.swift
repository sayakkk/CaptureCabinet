//
//  SharedActivityAttributes.swift
//  CaptureCabinet
//
//  Shared types between main app and Widget Extension
//

import Foundation
import ActivityKit

// MARK: - Shared Activity Attributes

public struct ScreenshotWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Screenshot information
        public var screenshotAssetID: String?
        public var screenshotTimestamp: Date

        // Folder data
        public var folders: [FolderData]

        // Selection state
        public var selectedFolderID: String?
        public var isSaving: Bool
        public var savedSuccessfully: Bool?

        public init(screenshotAssetID: String?, screenshotTimestamp: Date, folders: [FolderData], selectedFolderID: String?, isSaving: Bool, savedSuccessfully: Bool?) {
            self.screenshotAssetID = screenshotAssetID
            self.screenshotTimestamp = screenshotTimestamp
            self.folders = folders
            self.selectedFolderID = selectedFolderID
            self.isSaving = isSaving
            self.savedSuccessfully = savedSuccessfully
        }
    }

    // Folder data structure
    public struct FolderData: Codable, Hashable, Identifiable {
        public var id: String
        public var name: String
        public var screenshotCount: Int

        public init(id: String, name: String, screenshotCount: Int = 0) {
            self.id = id
            self.name = name
            self.screenshotCount = screenshotCount
        }
    }

    // Fixed properties - capture session ID
    public var sessionID: String

    public init(sessionID: String) {
        self.sessionID = sessionID
    }
}
