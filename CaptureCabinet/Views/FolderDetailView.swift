//
//  FolderDetailView.swift
//  CaptureCabinet
//
//  Modern folder detail view with enhanced visual design
//

import SwiftUI
import CoreData
import Photos

struct FolderDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    var folder: Folder

    @FetchRequest var screenshots: FetchedResults<Screenshot>
    @State private var showingPhotoPicker = false
    @State private var showingPhotoPermissionAlert = false
    @State private var showingFullScreen = false
    @State private var selectedScreenshotIndex = 0

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
                Button(action: {
                    print("Add screenshot functionality")
                }) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.0, green: 0.5, blue: 1.0),
                                        Color(red: 0.3, green: 0.35, blue: 0.9)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 32, height: 32)

                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .shadow(color: Color.blue.opacity(0.3), radius: 6, x: 0, y: 3)
                }
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
