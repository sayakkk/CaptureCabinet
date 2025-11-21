//
//  RecentScreenshotsView.swift
//  CaptureCabinet
//
//  Created by saya lee on 10/1/25.
//

import SwiftUI
import Photos
import UniformTypeIdentifiers
import CoreData

struct RecentScreenshotsView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @State private var recentScreenshots: [PHAsset] = []
    @State private var showingPhotoPermissionAlert = false
    @State private var appLaunchTime: Date = Date().addingTimeInterval(-86400) // 24시간 전

    @State private var isSelectionMode = false
    @State private var selectedIndices: Set<Int> = []

    @Binding var selectedScreenshots: Set<String>
    @Binding var isDragging: Bool

    // Drag callbacks for cross-tab drag functionality
    let onDragStart: ((DragItem) -> Void)?
    let onDragChange: ((CGSize, DragItem) -> Void)?
    let onDragEnd: (() -> Void)?
    
    // New drag state
    @State private var dragPosition: CGPoint = .zero
    @State private var isInDragMode = false
    @State private var dragTargetIndex: Int? = nil
    @State private var dragImages: [UIImage] = []
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Modern Header with enhanced design
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

                    if isSelectionMode {
                        Button("취소") {
                            isSelectionMode = false
                            selectedScreenshots.removeAll()
                        }
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.0, green: 0.5, blue: 1.0),
                                    Color(red: 0.3, green: 0.35, blue: 0.9)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    } else {
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
                        LazyVStack(spacing: 18) {
                            ForEach(Array(recentScreenshots.enumerated()), id: \.element.localIdentifier) { index, asset in
                                ScreenshotCardView(
                                    asset: asset,
                                    index: index,
                                    isSelected: selectedScreenshots.contains(asset.localIdentifier),
                                    isSelectionMode: isSelectionMode,
                                    selectedIndices: selectedIndices,
                                    selectedIds: selectedScreenshots,
                                    isDragging: $isDragging,
                                    isInDragMode: $isInDragMode,
                                    dragPosition: $dragPosition,
                                    dragTargetIndex: $dragTargetIndex,
                                    onTap: {
                                        handleScreenshotTap(asset.localIdentifier, index: index)
                                    },
                                    onSwipeLeft: {
                                        deleteScreenshot(at: index)
                                    },
                                    onDragStart: { targetIndex, startLocation in
                                        startDragMode(targetIndex: targetIndex, startLocation: startLocation)
                                    },
                                    onDragChanged: { translation, currentLocation in
                                        handleDragChanged(translation: translation, currentLocation: currentLocation)
                                    },
                                    onDragEnded: {
                                        handleDragEnded()
                                    }
                                )
                                .zIndex(isInDragMode && selectedScreenshots.contains(asset.localIdentifier) ? 1000 : 0)
                                .padding(.horizontal, Spacing.lg)
                            }
                        }
                        .padding(.vertical, Spacing.lg)
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
    }
    
    private func handleScreenshotTap(_ assetID: String, index: Int) {
        if isSelectionMode {
            if selectedScreenshots.contains(assetID) {
                selectedScreenshots.remove(assetID)
                selectedIndices.remove(index)
                if selectedScreenshots.isEmpty {
                    isSelectionMode = false
                    selectedIndices.removeAll()
                }
            } else {
                selectedScreenshots.insert(assetID)
                selectedIndices.insert(index)
            }
        } else {
            isSelectionMode = true
            selectedScreenshots.insert(assetID)
            selectedIndices.insert(index)
        }
    }
    
    @State private var dragStartLocation: CGPoint = .zero
    
    private func startDragMode(targetIndex: Int, startLocation: CGPoint) {
        dragTargetIndex = targetIndex
        isInDragMode = true
        isDragging = true
        dragStartLocation = startLocation
        
        // Load images for selected screenshots
        loadDragImages { images in
            self.dragImages = images
            let assetIds = Array(selectedScreenshots)
            let dragItem = DragItem(
                assetIds: assetIds,
                images: images,
                startLocation: startLocation,
                dragOffset: .zero
            )
            onDragStart?(dragItem)
        }
    }
    
    private func handleDragChanged(translation: CGSize, currentLocation: CGPoint) {
        guard isInDragMode else { return }
        
        dragPosition = CGPoint(x: translation.width, y: translation.height)
        
        // Create updated drag item with current offset
        guard let onDragChange = onDragChange else { return }
        
        let assetIds = Array(selectedScreenshots)
        let updatedItem = DragItem(
            assetIds: assetIds,
            images: dragImages,
            startLocation: dragStartLocation,
            dragOffset: translation
        )
        onDragChange(translation, updatedItem)
    }
    
    private func handleDragEnded() {
        isInDragMode = false
        isDragging = false
        dragPosition = .zero
        dragTargetIndex = nil
        dragImages = []
        dragStartLocation = .zero
        onDragEnd?()
    }
    
    private func loadDragImages(completion: @escaping ([UIImage]) -> Void) {
        let assetIds = Array(selectedScreenshots)
        var loadedImages: [UIImage] = []
        var loadedCount = 0
        
        for assetId in assetIds {
            if let asset = recentScreenshots.first(where: { $0.localIdentifier == assetId }) {
                let options = PHImageRequestOptions()
                options.isSynchronous = false
                options.deliveryMode = .highQualityFormat
                
                PHImageManager.default().requestImage(
                    for: asset,
                    targetSize: CGSize(width: 200, height: 260),
                    contentMode: .aspectFill,
                    options: options
                ) { image, _ in
                    if let image = image {
                        loadedImages.append(image)
                    }
                    loadedCount += 1
                    if loadedCount == assetIds.count {
                        completion(loadedImages)
                    }
                }
            } else {
                loadedCount += 1
                if loadedCount == assetIds.count {
                    completion(loadedImages)
                }
            }
        }
    }
    
    private func deleteScreenshot(at index: Int) {
        guard index < recentScreenshots.count else { return }
        
        let asset = recentScreenshots[index]
        selectedScreenshots.remove(asset.localIdentifier)
        
        // Remove from array
        recentScreenshots.remove(at: index)
        
        // Reset selection mode if no more screenshots
        if recentScreenshots.isEmpty {
            isSelectionMode = false
            selectedScreenshots.removeAll()
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
            // Include screenshots OR test images (check by checking if it's a screenshot subtype)
            // For test images, we'll include them if they were created recently (within last minute)
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
}

struct ScreenshotCardView: View {
    let asset: PHAsset
    let index: Int
    let isSelected: Bool
    let isSelectionMode: Bool
    let selectedIndices: Set<Int>
    let selectedIds: Set<String>
    @Binding var isDragging: Bool
    @Binding var isInDragMode: Bool
    @Binding var dragPosition: CGPoint
    @Binding var dragTargetIndex: Int?
    let onTap: () -> Void
    let onSwipeLeft: () -> Void
    let onDragStart: (Int, CGPoint) -> Void
    let onDragChanged: (CGSize, CGPoint) -> Void
    let onDragEnded: () -> Void
    
    @State private var image: UIImage?
    @State private var dragTranslation: CGSize = .zero
    
    private var offsetY: CGFloat {
        guard !selectedIndices.isEmpty else { return 0 }
        
        // 선택된 사진들 중에서 현재 사진보다 위에 있는 것들
        let selectedAbove = selectedIndices.filter { $0 < index }
        
        // 선택된 사진들 중에서 현재 사진보다 아래에 있는 것들
        let selectedBelow = selectedIndices.filter { $0 > index }
        
        var totalOffset: CGFloat = 0
        
        // 위쪽 선택된 사진들로 인해 아래로 밀림 (각각 18px씩)
        for _ in selectedAbove {
            totalOffset += 18.0
        }
        
        // 아래쪽 선택된 사진들로 인해 위로 밀림 (각각 18px씩)
        for _ in selectedBelow {
            totalOffset -= 18.0
        }
        
        return totalOffset
    }
    
    private var isDragTarget: Bool {
        isInDragMode && dragTargetIndex == index
    }
    
    private var shouldShowStacked: Bool {
        isInDragMode && isSelected && dragTargetIndex != nil
    }
    
    private var stackedOffset: CGSize {
        guard shouldShowStacked, let targetIndex = dragTargetIndex else { return .zero }
        
        // If this is the drag target, use actual drag position
        if isDragTarget {
            return CGSize(width: dragPosition.x, height: dragPosition.y)
        }
        
        // Calculate offset to stack selected items on drag target
        // Use the index difference to calculate relative offset
        let relativeOffset = index - targetIndex
        
        return CGSize(
            width: dragPosition.x + CGFloat(relativeOffset) * 8,
            height: dragPosition.y + CGFloat(relativeOffset) * 8
        )
    }
    
    var body: some View {
        HStack {
            Spacer()
            
            // Screenshot Image
            Group {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 120, height: 156) // 1.5배 크기, 1:1.3 비율
                        .clipped()
                        .cornerRadius(CornerRadius.md)
                        .shadow(color: Shadow.small, radius: 3, x: 0, y: 2)
                } else {
                    Rectangle()
                        .fill(Color.backgroundSecondary)
                        .frame(width: 120, height: 156) // 1.5배 크기, 1:1.3 비율
                        .cornerRadius(CornerRadius.md)
                        .shadow(color: Shadow.small, radius: 3, x: 0, y: 2)
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.8)
                        )
                }
            }
            .overlay(
                // Selection border
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: CornerRadius.md)
                            .stroke(Color.primaryBlue, lineWidth: 3)
                    }
                }
            )
            .overlay(
                // Swipe indicators
                HStack {
                    if dragTranslation.width < -50 {
                        VStack {
                            Image(systemName: "trash")
                                .font(.title2)
                                .foregroundColor(.white)
                            Text("삭제")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                        .frame(width: 60)
                        .background(Color.swipeDelete)
                        .cornerRadius(CornerRadius.md)
                        .opacity(min(abs(dragTranslation.width) / 100.0, 1.0))
                    }
                    
                    Spacer()
                    
                    if dragTranslation.width > 50 {
                        VStack {
                            Image(systemName: "folder")
                                .font(.title2)
                                .foregroundColor(.white)
                            Text("이동")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                        .frame(width: 60)
                        .background(Color.swipeArchive)
                        .cornerRadius(CornerRadius.md)
                        .opacity(min(dragTranslation.width / 100.0, 1.0))
                    }
                }
                .padding(.horizontal, Spacing.sm)
            )
            
            Spacer()
        }
        .offset(x: shouldShowStacked ? stackedOffset.width : dragTranslation.width, 
                y: shouldShowStacked ? stackedOffset.height : (offsetY + dragTranslation.height))
        .scaleEffect(isSelected && !isInDragMode ? 1.2 : (shouldShowStacked ? 0.9 : 1.0))
        .opacity(isInDragMode ? 0 : (shouldShowStacked ? (isDragTarget ? 1.0 : 0.7) : 1.0))
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isInDragMode)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: dragTranslation)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isSelected)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: selectedIndices)
        // Force update when dragPosition changes - no animation for instant following
        .onChange(of: dragPosition) { _, _ in
            // This triggers view refresh
        }
        .onAppear {
            loadImage()
        }
        .onTapGesture {
            if !isInDragMode {
                onTap()
            }
        }
        .gesture(
            // Drag gesture for moving to folders (when in selection mode and selected)
            isSelectionMode && isSelected && !selectedIds.isEmpty ? DragGesture(minimumDistance: 10)
                .onChanged { value in
                    // Start drag mode on first drag if not already started
                    if !isInDragMode {
                        // Start drag mode with this card as target
                        let startLocation = value.startLocation
                        onDragStart(index, startLocation)
                    }
                    
                    // Handle drag movement
                    let absoluteLocation = CGPoint(
                        x: value.startLocation.x + value.translation.width,
                        y: value.startLocation.y + value.translation.height
                    )
                    onDragChanged(value.translation, absoluteLocation)
                }
                .onEnded { _ in
                    onDragEnded()
                } : nil
        )
        .simultaneousGesture(
            // Swipe gesture for delete (only when not in drag mode)
            !isInDragMode && isSelectionMode ? DragGesture()
                .onChanged { value in
                    dragTranslation = value.translation
                }
                .onEnded { value in
                    if value.translation.width < -100 {
                        // Left swipe - Delete
                        withAnimation(.easeInOut(duration: 0.3)) {
                            dragTranslation = CGSize(width: -UIScreen.main.bounds.width, height: 0)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onSwipeLeft()
                            dragTranslation = .zero
                        }
                    } else {
                        // Return to original position
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            dragTranslation = .zero
                        }
                    }
                } : nil
        )
        .onDrag {
            // Only enable drag for selected items in drag mode
            guard isInDragMode, isSelected, !selectedIds.isEmpty else {
                // Return empty provider if not in drag mode
                let emptyPayload = "" as NSString
                return NSItemProvider(item: emptyPayload, typeIdentifier: UTType.text.identifier)
            }
            
            let ids = Array(selectedIds)
            let payload = ids.joined(separator: ",") as NSString
            return NSItemProvider(item: payload, typeIdentifier: UTType.text.identifier)
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

#Preview {
    RecentScreenshotsView(
        selectedScreenshots: .constant(Set<String>()),
        isDragging: .constant(false),
        onDragStart: { _ in },
        onDragChange: { _, _ in },
        onDragEnd: nil
    )
}