//
//  ScreenshotCaptureService.swift
//  CaptureCabinet
//
//  Screenshot detection and Dynamic Island management
//  iOS 18
//

import SwiftUI
import Combine
import ActivityKit
import CoreData
import Photos

// MARK: - Screenshot Capture Service

@MainActor
class ScreenshotCaptureService: ObservableObject {
    static let shared = ScreenshotCaptureService()

    @Published var currentActivity: Activity<ScreenshotWidgetAttributes>?
    @Published var latestScreenshotAssetID: String?

    private var viewContext: NSManagedObjectContext?
    private var screenshotObserver: NSObjectProtocol?
    private var folderSelectionObserver: NSObjectProtocol?

    private init() {}

    // MARK: - Setup

    func configure(with context: NSManagedObjectContext) {
        self.viewContext = context
        print("🔧 ScreenshotCaptureService: Configuring with context")
        setupScreenshotDetection()
        setupFolderSelectionListener()
        print("✅ ScreenshotCaptureService: Configuration complete")
    }

    private func setupScreenshotDetection() {
        print("👂 ScreenshotCaptureService: Setting up screenshot detection")

        // Listen for screenshot notifications
        screenshotObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.userDidTakeScreenshotNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            print("📸 Screenshot notification received!")
            Task {
                await self?.handleScreenshotCaptured()
            }
        }

        print("✅ ScreenshotCaptureService: Screenshot observer registered")
    }

    private func setupFolderSelectionListener() {
        // Listen for folder selection from Widget
        folderSelectionObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("SaveScreenshotToFolder"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let folderID = notification.userInfo?["folderID"] as? String else { return }
            Task {
                await self?.selectFolder(folderID: folderID)
            }
        }
    }

    // MARK: - Screenshot Detection

    private func handleScreenshotCaptured() async {
        print("📸 Screenshot detected!")

        // Wait a moment for screenshot to be saved to photo library
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        // Get the latest screenshot
        guard let latestScreenshot = await fetchLatestScreenshot() else {
            print("❌ Could not fetch latest screenshot")
            return
        }

        latestScreenshotAssetID = latestScreenshot.localIdentifier
        print("✅ Latest screenshot ID: \(latestScreenshot.localIdentifier)")

        // Start Live Activity
        await startLiveActivity()
    }

    private func fetchLatestScreenshot() async -> PHAsset? {
        return await withCheckedContinuation { continuation in
            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            fetchOptions.fetchLimit = 1

            // Fetch only screenshots
            let predicate = NSPredicate(format: "(mediaSubtype & %d) != 0", PHAssetMediaSubtype.photoScreenshot.rawValue)
            fetchOptions.predicate = predicate

            let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
            continuation.resume(returning: assets.firstObject)
        }
    }

    // MARK: - Live Activity Management

    func startLiveActivity() async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("❌ Live Activities not enabled")
            return
        }

        // End any existing activity
        await endCurrentActivity()

        // Fetch folders from Core Data
        let folders = await fetchFolders()

        // Create initial state
        let initialState = ScreenshotWidgetAttributes.ContentState(
            screenshotAssetID: latestScreenshotAssetID,
            screenshotTimestamp: Date(),
            folders: folders,
            selectedFolderID: nil,
            isSaving: false,
            savedSuccessfully: nil
        )

        // Create attributes
        let attributes = ScreenshotWidgetAttributes(sessionID: UUID().uuidString)

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )

            self.currentActivity = activity
            print("✅ Live Activity started: \(activity.id)")

            // Auto-dismiss after 30 seconds if no folder selected
            Task {
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
                await self.endCurrentActivity()
            }

        } catch {
            print("❌ Failed to start Live Activity: \(error)")
        }
    }

    func endCurrentActivity() async {
        guard let activity = currentActivity else { return }

        let finalState = ScreenshotWidgetAttributes.ContentState(
            screenshotAssetID: latestScreenshotAssetID,
            screenshotTimestamp: Date(),
            folders: [],
            selectedFolderID: nil,
            isSaving: false,
            savedSuccessfully: nil
        )

        await activity.end(
            .init(state: finalState, staleDate: nil),
            dismissalPolicy: .immediate
        )

        self.currentActivity = nil
        self.latestScreenshotAssetID = nil
        print("🔚 Live Activity ended")
    }

    // MARK: - Folder Selection

    func selectFolder(folderID: String) async {
        guard let activity = currentActivity,
              let context = viewContext,
              let assetID = latestScreenshotAssetID else {
            print("❌ Cannot select folder: missing activity or context")
            return
        }

        // Update state to show saving
        var updatedState = activity.content.state
        updatedState.selectedFolderID = folderID
        updatedState.isSaving = true

        await activity.update(.init(state: updatedState, staleDate: nil))

        // Save screenshot to folder
        let success = await saveScreenshotToFolder(assetID: assetID, folderID: folderID, context: context)

        // Update state with result
        updatedState.isSaving = false
        updatedState.savedSuccessfully = success
        await activity.update(.init(state: updatedState, staleDate: nil))

        // End activity after 2 seconds
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        await endCurrentActivity()
    }

    private func saveScreenshotToFolder(assetID: String, folderID: String, context: NSManagedObjectContext) async -> Bool {
        return await context.perform {
            // Fetch the folder
            let fetchRequest: NSFetchRequest<Folder> = Folder.fetchRequest()
            if let uuid = UUID(uuidString: folderID) {
                fetchRequest.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
            } else {
                print("❌ Invalid folder UUID")
                return false
            }

            guard let folder = try? context.fetch(fetchRequest).first else {
                print("❌ Folder not found")
                return false
            }

            // Create screenshot entity
            let screenshot = Screenshot(context: context)
            screenshot.id = UUID()
            screenshot.phAssetID = assetID
            screenshot.createdAt = Date()
            screenshot.folder = folder

            // Save
            do {
                try context.save()
                print("✅ Screenshot saved to folder: \(folder.name ?? "Unknown")")
                return true
            } catch {
                print("❌ Failed to save screenshot: \(error)")
                return false
            }
        }
    }

    // MARK: - Fetch Folders

    private func fetchFolders() async -> [ScreenshotWidgetAttributes.FolderData] {
        guard let context = viewContext else { return [] }

        return await context.perform {
            let fetchRequest: NSFetchRequest<Folder> = Folder.fetchRequest()
            fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Folder.createdAt, ascending: true)]

            guard let folders = try? context.fetch(fetchRequest) else {
                return []
            }

            return folders.map { folder in
                ScreenshotWidgetAttributes.FolderData(
                    id: folder.id?.uuidString ?? UUID().uuidString,
                    name: folder.name ?? "Untitled",
                    screenshotCount: folder.screenshots?.count ?? 0
                )
            }
        }
    }

    // MARK: - Cleanup

    deinit {
        if let observer = screenshotObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = folderSelectionObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
