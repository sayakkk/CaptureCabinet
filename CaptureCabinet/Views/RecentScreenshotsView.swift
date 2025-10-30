//
//  RecentScreenshotsView.swift
//  CaptureCabinet
//
//  Created by saya lee on 10/1/25.
//

import SwiftUI
import Photos
import CoreData

struct RecentScreenshotsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var recentScreenshots: [PHAsset] = []
    @State private var showingPhotoPermissionAlert = false
    @State private var appLaunchTime: Date = Date().addingTimeInterval(-86400) // 24시간 전
    
    @State private var isSelectionMode = false
    @State private var selectedIndices: Set<Int> = []
    
    @Binding var selectedTab: Int
    @Binding var selectedScreenshots: Set<String>
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("최근 스크린샷")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.textPrimary)
                    
                    Spacer()
                    
                    if isSelectionMode {
                        Button("취소") {
                            isSelectionMode = false
                            selectedScreenshots.removeAll()
                        }
                        .foregroundColor(.primaryBlue)
                    } else {
                        Button(action: {
                            addTestPhoto()
                        }) {
                            Image(systemName: "plus")
                                .font(.title3)
                                .foregroundColor(.primaryBlue)
                        }
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
                
                Divider()
                    .background(Color.textTertiary.opacity(0.3))
                
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
                                    onTap: {
                                        handleScreenshotTap(asset.localIdentifier, index: index)
                                    },
                                    onSwipeLeft: {
                                        deleteScreenshot(at: index)
                                    },
                                    onSwipeRight: {
                                        moveToFolders()
                                    }
                                )
                                .zIndex(0) // 모든 사진을 같은 Z축 레벨에 배치
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
    
    private func moveToFolders() {
        if !selectedScreenshots.isEmpty {
            selectedTab = 1
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
        let screenshotSubtypeValue = PHAssetMediaSubtype.photoScreenshot.rawValue
        let screenshotPredicate = NSPredicate(format: "(mediaSubtype & %d) != 0", screenshotSubtypeValue)
        fetchOptions.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [datePredicate, screenshotPredicate])
        
        let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        var screenshots: [PHAsset] = []
        
        assets.enumerateObjects { asset, _, _ in
            screenshots.append(asset)
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
    let onTap: () -> Void
    let onSwipeLeft: () -> Void
    let onSwipeRight: () -> Void
    
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
        .offset(x: dragTranslation.width, y: offsetY)
        .scaleEffect(isSelected ? 1.2 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: dragTranslation)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isSelected)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: selectedIndices)
        .onAppear {
            loadImage()
        }
        .onTapGesture {
            onTap()
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    if isSelectionMode {
                        dragTranslation = value.translation
                    }
                }
                .onEnded { value in
                    if isSelectionMode {
                        if value.translation.width < -100 {
                            // Left swipe - Delete
                            withAnimation(.easeInOut(duration: 0.3)) {
                                dragTranslation = CGSize(width: -UIScreen.main.bounds.width, height: 0)
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                onSwipeLeft()
                            }
                        } else if value.translation.width > 100 {
                            // Right swipe - Move to folders
                            withAnimation(.easeInOut(duration: 0.3)) {
                                dragTranslation = CGSize(width: UIScreen.main.bounds.width, height: 0)
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                onSwipeRight()
                            }
                        } else {
                            // Return to original position
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                dragTranslation = .zero
                            }
                        }
                    }
                }
        )
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
    RecentScreenshotsView(selectedTab: .constant(0), selectedScreenshots: .constant(Set<String>()))
}