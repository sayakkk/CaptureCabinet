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
                    ScrollView {
                        ZigzagPhotoGrid(
                            screenshots: recentScreenshots,
                            folders: Array(folders),
                            onSaveToFolder: saveToFolder
                        )
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.md)
                    }
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

        // Get all saved screenshot asset IDs from Core Data
        let savedAssetIDs = Set(folders.flatMap { folder -> [String] in
            guard let screenshotsSet = folder.screenshots as? Set<Screenshot> else { return [] }
            return screenshotsSet.compactMap { $0.phAssetID }
        })

        assets.enumerateObjects { asset, _, _ in
            // Include screenshots OR test images
            let isScreenshot = (asset.mediaSubtypes.rawValue & PHAssetMediaSubtype.photoScreenshot.rawValue) != 0
            let isRecentTest = asset.creationDate?.timeIntervalSinceNow ?? -Double.greatestFiniteMagnitude > -60 // Created within last 60 seconds

            // Only include if not already saved to a folder
            if (isScreenshot || isRecentTest) && !savedAssetIDs.contains(asset.localIdentifier) {
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

        // Listen for reload requests from screenshot cards
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ReloadRecentScreenshots"),
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
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets([asset] as NSArray)
        }) { success, error in
            DispatchQueue.main.async {
                if success {
                    print("✅ Screenshot deleted from photo library")
                    loadRecentScreenshots()
                } else if let error = error {
                    print("❌ Failed to delete screenshot: \(error)")
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

// MARK: - Zigzag Photo Grid

struct ZigzagPhotoGrid: View {
    let screenshots: [PHAsset]
    let folders: [Folder]
    let onSaveToFolder: (PHAsset, Folder) -> Void

    // Group screenshots into rows of 3
    private var rows: [[PHAsset]] {
        stride(from: 0, to: screenshots.count, by: 3).map { index in
            Array(screenshots[index..<min(index + 3, screenshots.count)])
        }
    }

    // Generate random X offset for each row (-30 ~ -10pt)
    private func rowOffset(for rowIndex: Int) -> CGFloat {
        // Use rowIndex as seed for consistent offset
        let seed = Double(rowIndex)
        let randomValue = sin(seed * 12.9898 + seed * 78.233) * 43758.5453
        let normalized = abs(randomValue - floor(randomValue))
        return -30 + (normalized * 20) // -30 ~ -10pt range
    }

    var body: some View {
        LazyVStack(spacing: Spacing.lg) {
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, rowAssets in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.md) {
                        ForEach(Array(rowAssets.enumerated()), id: \.element.localIdentifier) { itemIndex, asset in
                            ZigzagPhotoCard(
                                asset: asset,
                                index: rowIndex * 3 + itemIndex,
                                folders: folders,
                                onSaveToFolder: onSaveToFolder
                            )
                        }
                    }
                    .padding(.leading, rowOffset(for: rowIndex))
                }
            }
        }
    }
}

// MARK: - Zigzag Photo Card with Context Menu

struct ZigzagPhotoCard: View {
    let asset: PHAsset
    let index: Int
    let folders: [Folder]
    let onSaveToFolder: (PHAsset, Folder) -> Void

    @Environment(\.managedObjectContext) private var viewContext

    @State private var image: UIImage?
    @State private var showingFolderSheet = false
    @State private var isPressed = false
    @State private var showingNewFolderAlert = false
    @State private var newFolderName = ""

    // Consistent card size for all items
    private var cardSize: CGSize {
        return CGSize(width: 120, height: 160)
    }

    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: cardSize.width, height: cardSize.height)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                            .strokeBorder(Color.black.opacity(0.15), lineWidth: 0.5)
                    )
            } else {
                Rectangle()
                    .fill(Color.backgroundSecondary)
                    .frame(width: cardSize.width, height: cardSize.height)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                            .strokeBorder(Color.black.opacity(0.15), lineWidth: 0.5)
                    )
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.8)
                    )
            }
        }
        .scaleEffect(isPressed ? 1.05 : 1.0)
        .animation(AnimationCurve.springBouncy, value: isPressed)
        .onTapGesture {
            // Haptic feedback on tap
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()

            // Brief scale animation
            isPressed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
            }

            // Show folder selection sheet
            showingFolderSheet = true
        }
        .fullScreenCover(isPresented: $showingFolderSheet) {
            FolderSelectionSheet(
                asset: asset,
                folders: folders,
                onSelectFolder: { folder in
                    onSaveToFolder(asset, folder)
                    showingFolderSheet = false
                },
                onCreateNewFolder: {
                    showingFolderSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        showingNewFolderAlert = true
                    }
                },
                onDismiss: {
                    showingFolderSheet = false
                }
            )
            .transition(.move(edge: .bottom))
        }
        .onChange(of: showingFolderSheet) { oldValue, newValue in
            // When modal is dismissed, reload screenshots to reflect changes
            if !newValue {
                // Small delay to ensure Core Data save is complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    NotificationCenter.default.post(name: NSNotification.Name("ReloadRecentScreenshots"), object: nil)
                }
            }
        }
        .alert("새 폴더 만들기", isPresented: $showingNewFolderAlert) {
            TextField("폴더 이름", text: $newFolderName)
            Button("취소", role: .cancel) {
                newFolderName = ""
            }
            Button("만들기") {
                createFolderAndSave()
            }
        } message: {
            Text("새 폴더의 이름을 입력하세요")
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

        let scale = UIScreen.main.scale
        let targetSize = CGSize(width: cardSize.width * scale, height: cardSize.height * scale)

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

    private func createFolderAndSave() {
        guard !newFolderName.trimmingCharacters(in: .whitespaces).isEmpty else {
            newFolderName = ""
            return
        }

        viewContext.perform {
            // Create new folder
            let newFolder = Folder(context: viewContext)
            newFolder.id = UUID()
            newFolder.name = newFolderName.trimmingCharacters(in: .whitespaces)
            newFolder.createdAt = Date()

            // Create screenshot entity
            let screenshot = Screenshot(context: viewContext)
            screenshot.id = UUID()
            screenshot.phAssetID = asset.localIdentifier
            screenshot.createdAt = Date()
            screenshot.folder = newFolder

            // Save
            do {
                try viewContext.save()
                DispatchQueue.main.async {
                    print("✅ New folder created and screenshot saved: \(newFolder.name ?? "Unknown")")
                    // Haptic feedback
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    newFolderName = ""
                }
            } catch {
                DispatchQueue.main.async {
                    print("❌ Failed to create folder and save screenshot: \(error)")
                    newFolderName = ""
                }
            }
        }
    }
}

// MARK: - Legacy Screenshot Card View (kept for compatibility)

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

// MARK: - Folder Selection Sheet

struct FolderSelectionSheet: View {
    let asset: PHAsset
    let folders: [Folder]
    let onSelectFolder: (Folder) -> Void
    let onCreateNewFolder: () -> Void
    let onDismiss: () -> Void

    @State private var previewImage: UIImage?
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            // Grabber area for dismissing
            VStack(spacing: 0) {
                // Grabber indicator
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 36, height: 6)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.height > 0 {
                            dragOffset = value.translation.height
                        }
                    }
                    .onEnded { value in
                        if value.translation.height > 25 {
                            onDismiss()
                        }
                        dragOffset = 0
                    }
            )

            // Navigation bar with X button and title
            HStack {
                // Liquid glass X button (left)
                Button(action: {
                    onDismiss()
                }) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 32, height: 32)
                            .overlay(
                                Circle()
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [.white.opacity(0.3), .white.opacity(0.05)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)

                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.primary)
                    }
                }

                Spacer()

                // Title in center
                Text("폴더 선택")
                    .font(Typography.headline)
                    .foregroundColor(.textPrimary)

                Spacer()

                // Invisible spacer for symmetry
                Color.clear
                    .frame(width: 32, height: 32)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)

            // Header with preview
            VStack(spacing: Spacing.md) {
                // Screenshot preview
                if let previewImage = previewImage {
                    Image(uiImage: previewImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                                .strokeBorder(Color.black.opacity(0.1), lineWidth: 1)
                        )
                        .padding(.horizontal, Spacing.lg)
                }
            }
            .padding(.bottom, Spacing.md)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.height > 0 {
                            dragOffset = value.translation.height
                        }
                    }
                    .onEnded { value in
                        if value.translation.height > 25 {
                            onDismiss()
                        }
                        dragOffset = 0
                    }
            )

            Divider()
                .background(Color.textTertiary.opacity(0.15))

            // Folder list
            ScrollView {
                LazyVStack(spacing: Spacing.sm) {
                    // Existing folders
                    ForEach(folders, id: \.id) { folder in
                        Button(action: {
                            onSelectFolder(folder)
                            // Haptic feedback
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                        }) {
                            HStack(spacing: Spacing.md) {
                                // Folder icon
                                ZStack {
                                    Circle()
                                        .fill(Color.accentPrimary.opacity(0.15))
                                        .frame(width: 44, height: 44)

                                    Image(systemName: "folder.fill")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundStyle(Color.accentPrimary)
                                }

                                // Folder name and count
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(folder.name ?? "Untitled")
                                        .font(Typography.bodyRounded)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.textPrimary)

                                    if let screenshots = folder.screenshots, screenshots.count > 0 {
                                        Text("\(screenshots.count)개의 스크린샷")
                                            .font(Typography.caption1Rounded)
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
                                    .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    // New folder button
                    Button(action: {
                        onCreateNewFolder()
                        // Haptic feedback
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                    }) {
                        HStack(spacing: Spacing.md) {
                            // Plus icon
                            ZStack {
                                Circle()
                                    .fill(Color.success.opacity(0.15))
                                    .frame(width: 44, height: 44)

                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(Color.success)
                            }

                            Text("새 폴더 만들기")
                                .font(Typography.bodyRounded)
                                .fontWeight(.semibold)
                                .foregroundColor(.success)

                            Spacer()
                        }
                        .padding(Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                                .fill(Color.success.opacity(0.05))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                                .strokeBorder(Color.success.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)

                    if folders.isEmpty {
                        VStack(spacing: Spacing.md) {
                            Image(systemName: "folder.badge.plus")
                                .font(.system(size: 48))
                                .foregroundStyle(.tertiary)

                            Text("폴더가 없습니다")
                                .font(Typography.bodyRounded)
                                .foregroundColor(.textSecondary)

                            Text("새 폴더를 만들어 스크린샷을 정리하세요")
                                .font(Typography.caption1Rounded)
                                .foregroundColor(.textTertiary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, Spacing.xxxl)
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
            }
        }
        .background(Color.backgroundPrimary)
        .onAppear {
            loadPreviewImage()
        }
    }

    private func loadPreviewImage() {
        let requestOptions = PHImageRequestOptions()
        requestOptions.isSynchronous = false
        requestOptions.deliveryMode = .highQualityFormat
        requestOptions.resizeMode = .exact

        let targetSize = CGSize(width: 400, height: 300)

        PHImageManager.default().requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: requestOptions
        ) { result, _ in
            DispatchQueue.main.async {
                self.previewImage = result
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
    }
}

#Preview {
    RecentScreenshotsView()
}
