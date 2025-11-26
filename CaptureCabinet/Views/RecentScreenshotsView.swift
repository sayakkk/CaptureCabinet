//
//  RecentScreenshotsView.swift
//  CaptureCabinet
//
//  Created by saya lee on 10/1/25.
//  Screenshot list with swipe actions
//

import SwiftUI
import Photos
import CoreData

struct RecentScreenshotsView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Folder.createdAt, ascending: true)],
        animation: .default
    )
    private var folders: FetchedResults<Folder>

    @State private var recentScreenshots: [PHAsset] = []
    @State private var showingPhotoPermissionAlert = false
    @State private var appLaunchTime: Date = Date().addingTimeInterval(-86400) // 24시간 전
    @State private var showingAllFolders = false
    @State private var selectedAssetForFolder: PHAsset?

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Modern Header
                HStack {
                    Text("최근 스크린샷")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color.textPrimary,
                                    Color.textPrimary.opacity(0.9)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Spacer()

                    Button(action: {
                        addTestPhoto()
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
                                .frame(width: 40, height: 40)

                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.md)

                Divider()
                    .background(Color.textTertiary.opacity(0.15))

                if recentScreenshots.isEmpty {
                    PlaceholderView(message: "최근 스크린샷이 없습니다")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(Array(recentScreenshots.enumerated()), id: \.element.localIdentifier) { index, asset in
                            ScreenshotCardView(asset: asset)
                                .listRowInsets(EdgeInsets(top: 9, leading: 0, bottom: 9, trailing: 0))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    // 오른쪽 스와이프: 삭제 (왼쪽에 나타남)
                                    Button(role: .destructive) {
                                        deleteScreenshot(asset: asset)
                                    } label: {
                                        Label("삭제", systemImage: "trash")
                                    }
                                    .tint(Color.red)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    // 왼쪽 스와이프: 폴더 선택 (오른쪽에 나타남)
                                    // 버튼은 역순으로 표시되므로 뒤에서부터 추가

                                    // 폴더가 5개 이상일 때: 4, 5번째 폴더 표시
                                    if folders.count > 5 {
                                        ForEach(Array(folders.dropFirst(3).prefix(2)), id: \.id) { folder in
                                            Button {
                                                saveToFolder(asset: asset, folder: folder)
                                            } label: {
                                                VStack(spacing: 4) {
                                                    Image(systemName: "folder.fill")
                                                    Text(folder.name ?? "")
                                                        .font(.caption2)
                                                        .lineLimit(1)
                                                }
                                            }
                                            .tint(Color.orange)
                                        }
                                    }

                                    // "..." 버튼 (폴더가 5개 이상일 때) - 4번째 위치
                                    if folders.count > 5 {
                                        Button {
                                            selectedAssetForFolder = asset
                                            showingAllFolders = true
                                        } label: {
                                            VStack(spacing: 4) {
                                                Image(systemName: "ellipsis.circle.fill")
                                                Text("더보기")
                                                    .font(.caption2)
                                            }
                                        }
                                        .tint(Color.gray)
                                    }

                                    // 처음 3개 (또는 5개 이하면 모든) 폴더
                                    ForEach(folders.prefix(folders.count > 5 ? 3 : min(folders.count, 5)), id: \.id) { folder in
                                        Button {
                                            saveToFolder(asset: asset, folder: folder)
                                        } label: {
                                            VStack(spacing: 4) {
                                                Image(systemName: "folder.fill")
                                                Text(folder.name ?? "")
                                                    .font(.caption2)
                                                    .lineLimit(1)
                                            }
                                        }
                                        .tint(Color.orange)
                                    }
                                }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color.backgroundPrimary)
            .navigationBarHidden(true)
        }
        .onAppear {
            checkPhotoPermission()
            setupBackgroundNotifications()
        }
        .alert("사진 권한 필요", isPresented: $showingPhotoPermissionAlert) {
            Button("설정") {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
            Button("취소", role: .cancel) { }
        } message: {
            Text("스크린샷을 보려면 설정에서 사진 접근 권한을 허용해주세요.")
        }
        .sheet(isPresented: $showingAllFolders) {
            AllFoldersSheet(
                asset: selectedAssetForFolder,
                folders: Array(folders),
                onSelectFolder: { folder in
                    if let asset = selectedAssetForFolder {
                        saveToFolder(asset: asset, folder: folder)
                    }
                    showingAllFolders = false
                }
            )
        }
    }

    private func checkPhotoPermission() {
        let status = PHPhotoLibrary.authorizationStatus()
        switch status {
        case .authorized, .limited:
            loadRecentScreenshots()
        case .denied, .restricted:
            showingPhotoPermissionAlert = true
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { newStatus in
                DispatchQueue.main.async {
                    if newStatus == .authorized || newStatus == .limited {
                        self.loadRecentScreenshots()
                    } else {
                        self.showingPhotoPermissionAlert = true
                    }
                }
            }
        @unknown default:
            showingPhotoPermissionAlert = true
        }
    }

    private func loadRecentScreenshots() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        // Only screenshots since appLaunchTime
        let datePredicate = NSPredicate(format: "creationDate >= %@", appLaunchTime as NSDate)

        // Fetch all recent images first
        fetchOptions.predicate = datePredicate
        let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        var screenshots: [PHAsset] = []

        assets.enumerateObjects { asset, _, _ in
            // Include screenshots OR test images
            let isScreenshot = (asset.mediaSubtypes.rawValue & PHAssetMediaSubtype.photoScreenshot.rawValue) != 0
            let isRecentTest = asset.creationDate?.timeIntervalSinceNow ?? -Double.greatestFiniteMagnitude > -60 // Created within last 60 seconds

            if isScreenshot || isRecentTest {
                screenshots.append(asset)
            }
        }

        recentScreenshots = screenshots
    }

    private func setupBackgroundNotifications() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            loadRecentScreenshots()
        }
    }

    private func addTestPhoto() {
        // Create a test image
        let size = CGSize(width: 300, height: 400)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            let text = "Test Screenshot"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            let textSize = text.size(withAttributes: attributes)
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2.0,
                y: (size.height - textSize.height) / 2.0,
                width: textSize.width,
                height: textSize.height
            )
            text.draw(in: textRect, withAttributes: attributes)
        }

        // Save to photo library
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)

        // Refresh the list
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            loadRecentScreenshots()
        }
    }

    // MARK: - Swipe Actions

    private func deleteScreenshot(asset: PHAsset) {
        // Remove from UI immediately to prevent List update crash
        withAnimation {
            recentScreenshots.removeAll { $0.localIdentifier == asset.localIdentifier }
        }

        // Delete from photo library
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets([asset] as NSArray)
        }) { success, error in
            DispatchQueue.main.async {
                if success {
                    print("✅ Screenshot deleted from photo library")
                } else if let error = error {
                    print("❌ Failed to delete screenshot: \(error)")
                    // If deletion failed, reload to restore the asset
                    loadRecentScreenshots()
                }
            }
        }
    }

    private func saveToFolder(asset: PHAsset, folder: Folder) {
        let assetID = asset.localIdentifier

        viewContext.perform {
            // Create screenshot entity
            let screenshot = Screenshot(context: viewContext)
            screenshot.id = UUID()
            screenshot.phAssetID = assetID
            screenshot.createdAt = Date()
            screenshot.folder = folder

            // Save
            do {
                try viewContext.save()
                DispatchQueue.main.async {
                    print("✅ Screenshot saved to folder: \(folder.name ?? "Unknown")")
                }
            } catch {
                DispatchQueue.main.async {
                    print("❌ Failed to save screenshot: \(error)")
                }
            }
        }
    }
}

// MARK: - Simple Screenshot Card View

struct ScreenshotCardView: View {
    let asset: PHAsset
    @State private var image: UIImage?

    var body: some View {
        HStack {
            Spacer()

            // Screenshot Image
            Group {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 120, height: 156)
                        .clipped()
                        .cornerRadius(CornerRadius.md)
                        .shadow(color: Shadow.small, radius: 3, x: 0, y: 2)
                } else {
                    Rectangle()
                        .fill(Color.backgroundSecondary)
                        .frame(width: 120, height: 156)
                        .cornerRadius(CornerRadius.md)
                        .shadow(color: Shadow.small, radius: 3, x: 0, y: 2)
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.8)
                        )
                }
            }

            Spacer()
        }
        .onAppear {
            loadImage()
        }
    }

    private func loadImage() {
        let requestOptions = PHImageRequestOptions()
        requestOptions.isSynchronous = false
        requestOptions.deliveryMode = .highQualityFormat
        requestOptions.resizeMode = .exact

        let targetSize = CGSize(width: 120 * UIScreen.main.scale, height: 156 * UIScreen.main.scale)

        PHImageManager.default().requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: requestOptions
        ) { result, _ in
            DispatchQueue.main.async {
                self.image = result
            }
        }
    }
}

// MARK: - All Folders Sheet

struct AllFoldersSheet: View {
    let asset: PHAsset?
    let folders: [Folder]
    let onSelectFolder: (Folder) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("폴더 선택")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundColor(.textPrimary)

                    Spacer()

                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.md)

                Divider()
                    .background(Color.textTertiary.opacity(0.15))

                if folders.isEmpty {
                    PlaceholderView(message: "폴더가 없습니다", icon: "folder")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: Spacing.sm) {
                            ForEach(folders, id: \.id) { folder in
                                Button(action: {
                                    onSelectFolder(folder)
                                }) {
                                    HStack(spacing: Spacing.md) {
                                        // Folder icon
                                        ZStack {
                                            Circle()
                                                .fill(
                                                    LinearGradient(
                                                        colors: [
                                                            Color(red: 1.0, green: 0.58, blue: 0.0),
                                                            Color(red: 1.0, green: 0.45, blue: 0.0)
                                                        ],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                                .frame(width: 44, height: 44)

                                            Image(systemName: "folder.fill")
                                                .font(.system(size: 20, weight: .semibold))
                                                .foregroundStyle(.white)
                                        }

                                        // Folder name and count
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(folder.name ?? "Untitled")
                                                .font(.system(.body, design: .rounded, weight: .semibold))
                                                .foregroundColor(.textPrimary)

                                            if let screenshots = folder.screenshots, screenshots.count > 0 {
                                                Text("\(screenshots.count)개의 스크린샷")
                                                    .font(.system(.caption, design: .rounded))
                                                    .foregroundColor(.textSecondary)
                                            }
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(.tertiary)
                                    }
                                    .padding(Spacing.md)
                                    .background(
                                        RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                                            .fill(Color.surfacePrimary)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                                            .strokeBorder(Color.textTertiary.opacity(0.1), lineWidth: 1)
                                    )
                                    .shadow(color: Shadow.small, radius: 2, x: 0, y: 1)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.md)
                    }
                }
            }
            .background(Color.backgroundPrimary)
            .navigationBarHidden(true)
        }
    }
}

#Preview {
    RecentScreenshotsView()
}
