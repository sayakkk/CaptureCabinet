//
//  MainView.swift
//  CaptureList
//
//  Target: CaptureList
//

import SwiftUI
import Photos
import CoreData

struct MainView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Folder.createdAt, ascending: true)],
        animation: .default
    )
    private var folders: FetchedResults<Folder>

    @State private var recentScreenshots: [PHAsset] = []
    @State private var showingPhotoPermissionAlert = false
    @State private var draggedAssetID: String?
    @State private var refreshID = UUID()
    @State private var appLaunchTime: Date = Date().addingTimeInterval(-86400) // 24시간 전
    
    // 폴더 편집 관련 상태
    @State private var editingFolder: Folder? = nil
    @State private var editingText: String = ""
    @State private var showingDeleteAlert = false
    @State private var folderToDelete: Folder? = nil

    var body: some View {
        NavigationView {
            VStack(alignment: .leading) {
                HStack {
                    Text("Recent Captures")
                        .font(.headline)
                    Spacer()
                    Button("Add Test Photo") {
                        addTestPhoto()
                    }
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        if recentScreenshots.isEmpty {
                            PlaceholderView(message: "No recent screenshots found")
                        } else {
                            ForEach(recentScreenshots, id: \.localIdentifier) { asset in
                                ScreenshotThumbnail(asset: asset, draggedAssetID: $draggedAssetID)
                            }
                        }
                    }.padding(.horizontal)
                }
                .id(refreshID)

                Divider().padding(.vertical, 8)

                Text("Folders")
                    .font(.headline)
                    .padding(.leading)

                List {
                    ForEach(folders, id: \.id) { folder in
                        NavigationLink(destination: FolderDetailView(folder: folder)) {
                            if editingFolder?.id == folder.id {
                                TextField("Folder Name", text: $editingText)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .onSubmit {
                                        saveFolderName()
                                    }
                            } else {
                                Text(folder.name ?? "Untitled")
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .contentShape(Rectangle())
                        .allowsHitTesting(true)
                        .onDrop(of: [.text], isTargeted: nil) { providers in
                            print("🎯 DROP DETECTED on folder: \(folder.name ?? "Unknown")")
                            print("📦 Providers count: \(providers.count)")
                            return handleDropToFolder(providers: providers, folder: folder)
                        }
                        .overlay(
                            draggedAssetID != nil ?
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.blue, lineWidth: 2)
                                .background(Color.blue.opacity(0.1))
                            : nil
                        )
                        .contextMenu {
                            Button("이름 바꾸기") {
                                startEditing(folder: folder)
                            }
                            
                            Button("복제하기") {
                                duplicateFolder(folder: folder)
                            }
                            
                            Button("삭제하기", role: .destructive) {
                                folderToDelete = folder
                                showingDeleteAlert = true
                            }
                        }
                    }
                    .onDelete(perform: deleteFolders)
                }
                .listRowSpacing(12)
            }
//            .onTapGesture {
//                // 편집 모드에서 다른 곳을 터치하면 편집 취소
//                if editingFolder != nil {
//                    editingFolder = nil
//                    editingText = ""
//                }
//            }
            .navigationTitle("캡비넷")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add Folder") {
                        addFolder()
                    }
                }
            }
            .onAppear {
                checkPhotoPermission()
                setupBackgroundNotifications()
            }
            .alert("Photo Permission Required", isPresented: $showingPhotoPermissionAlert) {
                Button("Settings") {
                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsURL)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Please grant photo access in Settings to view your screenshots.")
            }
            .alert("폴더 삭제", isPresented: $showingDeleteAlert) {
                Button("삭제하기", role: .destructive) {
                    if let folder = folderToDelete {
                        deleteFolder(folder: folder)
                    }
                }
                Button("취소하기", role: .cancel) { }
            } message: {
                Text("정말로 삭제하시겠어요? 완전히 삭제됩니다.")
            }
        }
    }

    private func checkPhotoPermission() {
        let status = PHPhotoLibrary.authorizationStatus()
        switch status {
        case .authorized, .limited:
            fetchRecentScreenshots()
        case .denied, .restricted:
            showingPhotoPermissionAlert = true
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { newStatus in
                DispatchQueue.main.async {
                    if newStatus == .authorized || newStatus == .limited {
                        fetchRecentScreenshots()
                    } else {
                        showingPhotoPermissionAlert = true
                    }
                }
            }
        @unknown default:
            break
        }
    }

    private func fetchRecentScreenshots() {
        print("📱 Fetching screenshots from last 24 hours: \(appLaunchTime)")
        print("🕐 Current time: \(Date())")
        
        // 스크린샷만 필터링하는 옵션 설정
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = 100
        
        // 스크린샷만 가져오는 predicate (24시간 내)
        let screenshotPredicate = NSPredicate(format: "mediaSubtypes & %d != 0 AND creationDate >= %@", 
                                            PHAssetMediaSubtype.photoScreenshot.rawValue, 
                                            appLaunchTime as NSDate)
        fetchOptions.predicate = screenshotPredicate
        
        let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        var result: [PHAsset] = []
        
        print("🔍 Total screenshots found in last 24 hours: \(assets.count)")
        
        // 이미 폴더로 이동된 스크린샷의 ID 목록 가져오기
        let movedScreenshotIDs = getMovedScreenshotIDs()
        print("📦 Already moved screenshot IDs: \(movedScreenshotIDs)")
        
        assets.enumerateObjects { obj, _, _ in
            print("📸 Screenshot: \(obj.localIdentifier), Created: \(obj.creationDate ?? Date.distantPast)")
            
            // 이미 폴더로 이동되지 않은 스크린샷만 포함
            if !movedScreenshotIDs.contains(obj.localIdentifier) {
                result.append(obj)
            }
        }
        
        print("✅ Found \(result.count) new screenshots available for organization")
        print("📊 Total screenshots: \(assets.count), Already moved: \(movedScreenshotIDs.count), Available: \(result.count)")
        recentScreenshots = result
    }
    
    private func getMovedScreenshotIDs() -> Set<String> {
        let request: NSFetchRequest<Screenshot> = Screenshot.fetchRequest()
        do {
            let screenshots = try viewContext.fetch(request)
            let movedIDs = Set(screenshots.compactMap { $0.phAssetID })
            print("🗂️ Found \(movedIDs.count) screenshots already in folders")
            return movedIDs
        } catch {
            print("❌ Error fetching moved screenshots: \(error)")
            return Set()
        }
    }
    
    private func setupBackgroundNotifications() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            print("🔄 App entering foreground - refreshing screenshots")
            fetchRecentScreenshots()
        }
    }
    
    private func addTestPhoto() {
        print("📸 Adding test photo to Photos library")
        
        // 간단한 테스트 이미지 생성
        let size = CGSize(width: 400, height: 600)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            // 배경색
            UIColor.systemBlue.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // 텍스트 추가
            let text = "Test Photo\n\(Date())"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            let textSize = text.size(withAttributes: attributes)
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            text.draw(in: textRect, withAttributes: attributes)
        }
        
        // Photos 라이브러리에 저장
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }) { success, error in
            DispatchQueue.main.async {
                if success {
                    print("✅ Test photo added successfully")
                    self.fetchRecentScreenshots()
                } else {
                    print("❌ Failed to add test photo: \(error?.localizedDescription ?? "Unknown error")")
                }
            }
        }
    }
    
    private func addFolder() {
        withAnimation {
            let newFolder = Folder(context: viewContext)
            newFolder.id = UUID()
            newFolder.name = "New Folder"
            newFolder.createdAt = Date()
            
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    private func deleteFolders(offsets: IndexSet) {
        withAnimation {
            offsets.map { folders[$0] }.forEach(viewContext.delete)
            
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    private func handleDropToFolder(providers: [NSItemProvider], folder: Folder) -> Bool {
        print("🎯 handleDropToFolder called for folder: \(folder.name ?? "Unknown")")
        guard let provider = providers.first else {
            print("❌ No provider found")
            return false
        }
        
        provider.loadDataRepresentation(forTypeIdentifier: "public.text") { data, error in
            if let error = error {
                print("❌ Error loading data: \(error)")
                return
            }
            
            guard let data = data,
                  let assetID = String(data: data, encoding: .utf8) else {
                print("❌ Could not convert data to string")
                return
            }
            
            print("📦 Loaded assetID: \(assetID)")
            
            DispatchQueue.main.async {
                saveScreenshotToFolder(assetID: assetID, folder: folder)
                draggedAssetID = nil
                print("🧹 Dragged asset ID cleared")
            }
        }
        
        return true
    }
    
    private func saveScreenshotToFolder(assetID: String, folder: Folder) {
        print("🔄 saveScreenshotToFolder called with assetID: \(assetID)")
        print("📊 Current recentScreenshots count: \(recentScreenshots.count)")
        
        // PHAsset을 찾기
        guard let asset = recentScreenshots.first(where: { $0.localIdentifier == assetID }) else {
            print("❌ Asset not found in recentScreenshots")
            return
        }
        
        print("✅ Asset found: \(asset.localIdentifier)")
        
        // Core Data에 Screenshot 엔티티 생성
        let screenshot = Screenshot(context: viewContext)
        screenshot.id = UUID()
        screenshot.phAssetID = assetID
        screenshot.createdAt = Date()
        screenshot.folder = folder
        
        // Core Data 저장
        do {
            try viewContext.save()
            print("💾 Core Data saved successfully")
            
            // 최근 스크린샷 목록에서 제거 - 새로운 배열 생성
            let filteredScreenshots = recentScreenshots.filter { $0.localIdentifier != assetID }
            recentScreenshots = filteredScreenshots
            
            print("🗑️ Removed from recentScreenshots. New count: \(recentScreenshots.count)")
            
            // UI 강제 업데이트
            refreshID = UUID()
            print("🔄 UI refresh triggered")
            
        } catch {
            let nsError = error as NSError
            print("❌ Core Data save error: \(nsError)")
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }
    
    // MARK: - 폴더 편집 관련 함수들
    
    private func startEditing(folder: Folder) {
        editingFolder = folder
        editingText = folder.name ?? "Untitled"
    }
    
    private func saveFolderName() {
        guard let folder = editingFolder else { return }
        
        folder.name = editingText.isEmpty ? "Untitled" : editingText
        
        do {
            try viewContext.save()
            editingFolder = nil
            editingText = ""
        } catch {
            let nsError = error as NSError
            print("❌ Error saving folder name: \(nsError)")
        }
    }
    
    private func duplicateFolder(folder: Folder) {
        withAnimation {
            // 새 폴더 생성
            let newFolder = Folder(context: viewContext)
            newFolder.id = UUID()
            newFolder.name = "\(folder.name ?? "Untitled") Copy"
            newFolder.createdAt = Date().addingTimeInterval(-1) // 바로 위에 배치하기 위해 1초 전으로 설정
            
            // 기존 폴더의 스크린샷들을 복제
            if let screenshots = folder.screenshots {
                for screenshot in screenshots {
                    if let screenshot = screenshot as? Screenshot {
                        let newScreenshot = Screenshot(context: viewContext)
                        newScreenshot.id = UUID()
                        newScreenshot.phAssetID = screenshot.phAssetID
                        newScreenshot.createdAt = Date()
                        newScreenshot.folder = newFolder
                    }
                }
            }
            
            do {
                try viewContext.save()
                print("✅ Folder duplicated successfully")
            } catch {
                let nsError = error as NSError
                print("❌ Error duplicating folder: \(nsError)")
            }
        }
    }
    
    private func deleteFolder(folder: Folder) {
        withAnimation {
            viewContext.delete(folder)
            
            do {
                try viewContext.save()
                print("✅ Folder deleted successfully")
            } catch {
                let nsError = error as NSError
                print("❌ Error deleting folder: \(nsError)")
            }
        }
    }
}

struct ScreenshotThumbnail: View {
    var asset: PHAsset
    @Binding var draggedAssetID: String?
    @State private var image: UIImage?
    @State private var isDragging = false
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 80)
                    .clipped()
                    .cornerRadius(8)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 80, height: 80)
                    .cornerRadius(8)
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.8)
                    )
            }
        }
        .scaleEffect(isDragging ? 1.1 : 1.0)
        .opacity(isDragging ? 0.8 : 1.0)
        .onAppear {
            loadImage()
        }
        .draggable(asset.localIdentifier) {
            Group {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .clipped()
                        .cornerRadius(6)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 60, height: 60)
                        .cornerRadius(6)
                }
            }
        }
        .onDrag {
            print("🚀 DRAG STARTED for asset: \(asset.localIdentifier)")
            print("🎯 Setting draggedAssetID: \(asset.localIdentifier)")
            isDragging = true
            draggedAssetID = asset.localIdentifier
            let provider = NSItemProvider()
            provider.registerDataRepresentation(forTypeIdentifier: "public.text", visibility: .all) { completion in
                let data = asset.localIdentifier.data(using: .utf8)
                print("📤 Providing data for asset: \(asset.localIdentifier)")
                completion(data, nil)
                return nil
            }
            return provider
        }
        .onDrop(of: [.text], isTargeted: nil) { _ in
            // 드래그가 끝났을 때 상태를 명확히 초기화
            isDragging = false
            draggedAssetID = nil
            print("🧹 Drag ended (onDrop): isDragging = false, draggedAssetID = nil")
            return false
        }
        .onChange(of: draggedAssetID) {
            // draggedAssetID가 nil이 되면 드래그 상태 해제
            if draggedAssetID == nil {
                isDragging = false
                print("🧹 Drag ended (onChange): isDragging = false")
            }
        }
    }
    
    private func loadImage() {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .opportunistic
        options.resizeMode = .exact
        
        manager.requestImage(
            for: asset,
            targetSize: CGSize(width: 80, height: 80),
            contentMode: .aspectFill,
            options: options
        ) { result, _ in
            DispatchQueue.main.async {
                self.image = result
            }
        }
    }
}
