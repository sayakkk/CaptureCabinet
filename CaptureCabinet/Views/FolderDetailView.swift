//
//  FolderDetailView.swift
//  CaptureCabinet
//
//  Modern folder detail view with enhanced visual design
//

import SwiftUI
import CoreData
import Photos
import PhotosUI

struct FolderDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    var folder: Folder

    @FetchRequest var screenshots: FetchedResults<Screenshot>
    @State private var showingPhotoPicker = false
    @State private var showingPhotoPermissionAlert = false
    @State private var showingFullScreen = false
    @State private var selectedScreenshotIndex = 0
    @State private var selectedPhotos: [PhotosPickerItem] = []

    init(folder: Folder) {
        self.folder = folder
        _screenshots = FetchRequest(
            entity: Screenshot.entity(),
            sortDescriptors: [NSSortDescriptor(keyPath: \Screenshot.createdAt, ascending: false)],
            predicate: NSPredicate(format: "folder == %@", folder),
            animation: .default
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            if screenshots.isEmpty {
                PlaceholderView(message: "이 폴더에 스크린샷이 없습니다", icon: "photo.stack")
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [
                            GridItem(.adaptive(minimum: 100, maximum: 120), spacing: 12)
                        ],
                        spacing: 12
                    ) {
                        ForEach(Array(screenshots.enumerated()), id: \.element.id) { index, screenshot in
                            ScreenshotView(screenshot: screenshot)
                                .onTapGesture {
                                    selectedScreenshotIndex = index
                                    showingFullScreen = true
                                }
                                .onLongPressGesture {
                                    print("Schedule reminder tapped")
                                }
                        }
                    }
                    .padding(Spacing.lg)
                }
            }
        }
        .background(Color.backgroundPrimary)
        .navigationTitle(folder.name ?? "Folder")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                PhotosPicker(
                    selection: $selectedPhotos,
                    maxSelectionCount: nil,
                    matching: .images
                ) {
                    ZStack {
                        // iOS 26 liquid glass background
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 36, height: 36)
                            .overlay(
                                Circle()
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [
                                                .white.opacity(0.4),
                                                .white.opacity(0.1)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1.5
                                    )
                            )
                            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)

                        // Plus icon with gradient
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color.accentPrimary,
                                        Color.accentSecondary
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }
            }
        }
        .onChange(of: selectedPhotos) { oldValue, newValue in
            guard !newValue.isEmpty else { return }
            Task {
                await addPhotosToFolder(newValue)
            }
        }
        .alert("Photo Permission Required", isPresented: $showingPhotoPermissionAlert) {
            Button("Settings") {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please grant photo access in Settings to add screenshots.")
        }
        .fullScreenCover(isPresented: $showingFullScreen) {
            FullScreenImageView(
                isPresented: $showingFullScreen,
                currentIndex: selectedScreenshotIndex,
                screenshots: Array(screenshots)
            )
        }
    }
    
    private func checkPhotoPermission() {
        let status = PHPhotoLibrary.authorizationStatus()
        switch status {
        case .authorized, .limited:
            showingPhotoPicker = true
        case .denied, .restricted:
            showingPhotoPermissionAlert = true
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { newStatus in
                DispatchQueue.main.async {
                    if newStatus == .authorized || newStatus == .limited {
                        showingPhotoPicker = true
                    } else {
                        showingPhotoPermissionAlert = true
                    }
                }
            }
        @unknown default:
            break
        }
    }

    private func addPhotosToFolder(_ photoItems: [PhotosPickerItem]) async {
        print("📸 Starting to add \(photoItems.count) photos to folder: \(folder.name ?? "Unknown")")
        print("🔍 PhotoItems received: \(photoItems)")

        for (index, item) in photoItems.enumerated() {
            print("\n🔄 Processing photo \(index + 1)/\(photoItems.count)")
            print("📦 PhotosPickerItem: \(item)")

            // Try to get the asset identifier
            if let assetIdentifier = item.itemIdentifier {
                print("🆔 Item identifier found: \(assetIdentifier)")

                // Fetch PHAsset using identifier
                let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)

                if let asset = fetchResult.firstObject {
                    print("✓ Found PHAsset with localIdentifier: \(asset.localIdentifier)")

                    // Add to Core Data on main thread
                    await MainActor.run {
                        do {
                            // Check if already exists in this folder
                            let fetchRequest: NSFetchRequest<Screenshot> = Screenshot.fetchRequest()
                            fetchRequest.predicate = NSPredicate(format: "phAssetID == %@ AND folder == %@", asset.localIdentifier, folder)

                            let existingScreenshots = try viewContext.fetch(fetchRequest)

                            if existingScreenshots.isEmpty {
                                print("➕ Creating new screenshot entity...")

                                // Create new screenshot entity
                                let screenshot = Screenshot(context: viewContext)
                                screenshot.id = UUID()
                                screenshot.phAssetID = asset.localIdentifier
                                screenshot.createdAt = Date()
                                screenshot.folder = folder

                                print("💾 Saving to Core Data...")
                                try viewContext.save()

                                print("✅ Successfully saved photo \(index + 1) to folder")

                                // Trigger haptic feedback for success
                                let generator = UINotificationFeedbackGenerator()
                                generator.notificationOccurred(.success)
                            } else {
                                print("ℹ️ Photo \(index + 1) already exists in this folder, skipping")
                            }
                        } catch {
                            print("❌ Failed to add photo \(index + 1): \(error)")
                            print("❌ Error details: \(error.localizedDescription)")
                        }
                    }
                } else {
                    print("❌ PHAsset not found for identifier: \(assetIdentifier)")
                }
            } else {
                print("❌ No asset identifier for item \(index + 1)")
                print("⚠️ Trying alternative approach: saving to photo library first...")

                // Alternative approach: load the image and save to photo library
                do {
                    if let data = try await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        print("✓ Loaded image data: \(data.count) bytes")

                        // Save to photo library and get the asset
                        let assetID = await saveImageToPhotoLibrary(image)

                        if let assetID = assetID {
                            print("✓ Saved to photo library with ID: \(assetID)")

                            // Now add this asset to the folder
                            await MainActor.run {
                                do {
                                    let screenshot = Screenshot(context: viewContext)
                                    screenshot.id = UUID()
                                    screenshot.phAssetID = assetID
                                    screenshot.createdAt = Date()
                                    screenshot.folder = folder

                                    try viewContext.save()
                                    print("✅ Successfully saved photo \(index + 1) to folder")

                                    // Trigger haptic feedback for success
                                    let generator = UINotificationFeedbackGenerator()
                                    generator.notificationOccurred(.success)
                                } catch {
                                    print("❌ Failed to save to Core Data: \(error)")
                                }
                            }
                        } else {
                            print("❌ Failed to save image to photo library")
                        }
                    } else {
                        print("❌ Failed to load transferable data or create image")
                    }
                } catch {
                    print("❌ Error loading transferable: \(error)")
                }
            }
        }

        // Clear selection after processing
        await MainActor.run {
            selectedPhotos.removeAll()
            print("\n✅ Finished processing all photos. Selection cleared.")

            // Post notification to refresh views
            NotificationCenter.default.post(name: NSNotification.Name("ReloadRecentScreenshots"), object: nil)
            print("📢 Posted reload notification")
        }
    }

    private func saveImageToPhotoLibrary(_ image: UIImage) async -> String? {
        return await withCheckedContinuation { continuation in
            var localIdentifier: String?

            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetChangeRequest.creationRequestForAsset(from: image)
                localIdentifier = request.placeholderForCreatedAsset?.localIdentifier
            }) { success, error in
                if success, let identifier = localIdentifier {
                    print("✓ Image saved to photo library: \(identifier)")
                    continuation.resume(returning: identifier)
                } else {
                    print("❌ Failed to save image to photo library: \(error?.localizedDescription ?? "Unknown error")")
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}

struct ScreenshotView: View {
    var screenshot: Screenshot
    @State private var image: UIImage?
    @State private var asset: PHAsset?

    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 100, height: 130)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.gray.opacity(0.15),
                                Color.gray.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 130)
                    .overlay(
                        ProgressView()
                            .tint(Color.blue.opacity(0.6))
                            .scaleEffect(0.9)
                    )
            }
        }
        .shadow(
            color: Color.black.opacity(0.08),
            radius: 8,
            x: 0,
            y: 4
        )
        .onAppear {
            loadAssetAndImage()
        }
    }
    
    private func loadAssetAndImage() {
        guard let assetID = screenshot.phAssetID else { return }
        
        // PHAsset 찾기
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil)
        guard let phAsset = fetchResult.firstObject else { return }
        
        asset = phAsset
        
        // 이미지 로드
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .opportunistic
        options.resizeMode = .exact
        
        manager.requestImage(
            for: phAsset,
            targetSize: CGSize(width: 200, height: 200),
            contentMode: .aspectFill,
            options: options
        ) { result, _ in
            DispatchQueue.main.async {
                self.image = result
            }
        }
    }
}
