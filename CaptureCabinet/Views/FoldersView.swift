//
//  FoldersView.swift
//  CaptureCabinet
//
//  Created by saya lee on 10/1/25.
//

import SwiftUI
import CoreData
import UniformTypeIdentifiers

struct FoldersView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Folder.createdAt, ascending: true)],
        animation: nil
    )
    private var folders: FetchedResults<Folder>
    
    @State private var editingFolder: Folder? = nil
    @State private var editingText: String = ""
    @State private var showingDeleteAlert = false
    @State private var folderToDelete: Folder? = nil
    @State private var showingAddFolder = false
    @State private var showingRenameAlert = false
    
    // Selected screenshots from RecentScreenshotsView
    @Binding var selectedScreenshots: Set<String>
    @Binding var isDragging: Bool
    
    // Drag state from custom tab container
    let dragItem: DragItem?
    let dragOffset: CGSize
    let onDrop: ([String]) -> Void
    
    @State private var selectedFolderForDrop: Folder? = nil
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Modern Header with enhanced design
                HStack {
                    Text("폴더")
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
                        showingAddFolder = true
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
                
                if folders.isEmpty {
                    PlaceholderView(message: "폴더가 없습니다")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.md), count: 3), spacing: Spacing.md) {
                            ForEach(folders, id: \.id) { folder in
                                FolderCardView(
                                    folder: folder,
                                    editingFolder: $editingFolder,
                                    editingText: $editingText,
                                    isSelected: selectedFolderForDrop?.id == folder.id,
                                    isDragging: isDragging,
                                    onTap: {
                                        if !selectedScreenshots.isEmpty && !isDragging {
                                            saveScreenshotsToFolder(folder: folder, clearSelection: true)
                                        }
                                    },
                                    onEdit: {
                                        startEditing(folder: folder)
                                    },
                                    onDuplicate: {
                                        duplicateFolder(folder: folder)
                                    },
                                    onDelete: {
                                        folderToDelete = folder
                                        showingDeleteAlert = true
                                    },
                                    onDropItems: { ids in
                                        onDrop(ids)
                                        saveScreenshotsToFolder(folder: folder, assetIDs: ids, clearSelection: true)
                                        selectedFolderForDrop = nil
                                    },
                                    onDragEnter: {
                                        if isDragging {
                                            selectedFolderForDrop = folder
                                        }
                                    },
                                    onDragExit: {
                                        if isDragging {
                                            selectedFolderForDrop = nil
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.lg)
                    }
                }
            }
            .background(Color.backgroundPrimary)
            .navigationBarHidden(true)
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
        .alert("새 폴더", isPresented: $showingAddFolder) {
            TextField("폴더 이름", text: $editingText)
            Button("생성") {
                createNewFolder()
            }
            Button("취소", role: .cancel) {
                editingText = ""
            }
        } message: {
            Text("새 폴더의 이름을 입력하세요.")
        }
#if os(iOS) && !targetEnvironment(macCatalyst)
        .alert("이름 변경", isPresented: $showingRenameAlert) {
            TextField("폴더 이름", text: $editingText)
            Button("변경") {
                saveFolderName()
            }
            Button("취소", role: .cancel) {
                editingText = ""
                editingFolder = nil
            }
        } message: {
            Text("새로운 이름을 입력하세요")
        }
#else
        .sheet(isPresented: $showingRenameAlert) {
            RenameDialogView(
                name: $editingText,
                onCancel: {
                    editingText = ""
                    editingFolder = nil
                    showingRenameAlert = false
                },
                onConfirm: {
                    saveFolderName()
                    showingRenameAlert = false
                }
            )
            .presentationDetents([.height(220)])
            .presentationDragIndicator(.hidden)
        }
#endif
        .tint(.blue)
    }
    
    private func createNewFolder() {
        let newFolder = Folder(context: viewContext)
        newFolder.id = UUID()
        newFolder.name = editingText.isEmpty ? "새 폴더" : editingText
        newFolder.createdAt = Date()
        
        do {
            try viewContext.save()
            editingText = ""
        } catch {
            let nsError = error as NSError
            print("❌ Core Data save error: \(nsError)")
        }
    }
    
    private func saveScreenshotsToFolder(folder: Folder, assetIDs: [String]? = nil, clearSelection: Bool = false) {
        let idsToSave = assetIDs ?? Array(selectedScreenshots)
        
        for assetID in idsToSave {
            let screenshot = Screenshot(context: viewContext)
            screenshot.id = UUID()
            screenshot.phAssetID = assetID
            screenshot.createdAt = Date()
            screenshot.folder = folder
        }
        
        do {
            try viewContext.save()
            if clearSelection {
                selectedScreenshots.removeAll()
            }
        } catch {
            let nsError = error as NSError
            print("❌ Core Data save error: \(nsError)")
        }
    }
    
    private func startEditing(folder: Folder) {
        editingFolder = folder
        editingText = folder.name ?? ""
        showingRenameAlert = true
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
            print("❌ Core Data save error: \(nsError)")
        }
    }
    
    private func duplicateFolder(folder: Folder) {
        let newFolder = Folder(context: viewContext)
        newFolder.id = UUID()
        newFolder.name = "\(folder.name ?? "Untitled") Copy"
        newFolder.createdAt = Date()
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            print("❌ Core Data save error: \(nsError)")
        }
    }
    
    private func deleteFolder(folder: Folder) {
        viewContext.delete(folder)
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            print("❌ Core Data save error: \(nsError)")
        }
    }
}

struct FolderCardView: View {
    let folder: Folder
    @Environment(\.managedObjectContext) private var viewContext
    
    @Binding var editingFolder: Folder?
    @Binding var editingText: String
    let isSelected: Bool
    let isDragging: Bool
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void
    let onDropItems: ([String]) -> Void
    let onDragEnter: () -> Void
    let onDragExit: () -> Void
    
    @State private var isHovered = false
    @State private var isDropTargeted = false
    
    var body: some View {
        NavigationLink(destination: FolderDetailView(folder: folder)) {
            VStack(spacing: 12) {
                // Modern folder icon with gradient
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
                        .frame(width: 50, height: 50)

                    Image(systemName: "folder.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .shadow(color: Color.orange.opacity(0.3), radius: 8, x: 0, y: 4)

                VStack(spacing: 4) {
                    Text(folder.name ?? "Untitled")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)

                    // Screenshot count badge
                    if let screenshots = folder.screenshots, screenshots.count > 0 {
                        Text("\(screenshots.count)")
                            .font(.system(.caption2, design: .rounded, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(Color.gray.opacity(0.12))
                            )
                    }
                }
            }
            .frame(width: 100, height: 120)
            .padding(Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        isSelected && isDragging
                            ? LinearGradient(
                                colors: [
                                    Color.blue.opacity(0.15),
                                    Color.blue.opacity(0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [
                                    Color.surfacePrimary,
                                    Color.surfacePrimary.opacity(0.95)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        isSelected && isDragging
                            ? LinearGradient(
                                colors: [
                                    Color.blue.opacity(0.6),
                                    Color.blue.opacity(0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [
                                    Color.white.opacity(0.3),
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                        lineWidth: isSelected && isDragging ? 2 : 1
                    )
            )
            .shadow(
                color: isSelected && isDragging ? Color.blue.opacity(0.3) : Color.black.opacity(0.06),
                radius: isSelected && isDragging ? 12 : 6,
                x: 0,
                y: isSelected && isDragging ? 6 : 3
            )
            .scaleEffect(isHovered ? 1.05 : 1.0)
            .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.8), value: isHovered)
            .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.8), value: isSelected)
        }
        .buttonStyle(.plain)
        .onTapGesture {
            onTap()
        }
        .contextMenu {
            Button("이름 바꾸기") {
                onEdit()
            }
            
            Button("복제하기") {
                onDuplicate()
            }
            
            Button("삭제하기", role: .destructive) {
                onDelete()
            }
        }
        .onDrop(of: [UTType.text, UTType.plainText], isTargeted: $isDropTargeted) { providers in
            // Call onDragEnter when drop target enters
            if isDropTargeted && !isSelected && isDragging {
                onDragEnter()
            }
            
            let typeIdentifiers = [UTType.text.identifier, UTType.plainText.identifier]
            
            for provider in providers {
                guard let typeId = typeIdentifiers.first(where: { provider.hasItemConformingToTypeIdentifier($0) }) else {
                    continue
                }
                
                provider.loadDataRepresentation(forTypeIdentifier: typeId) { data, _ in
                    guard let data = data, let text = String(data: data, encoding: .utf8) else { return }
                    let ids = text.split(separator: ",").map { String($0) }
                    DispatchQueue.main.async {
                        onDropItems(ids)
                        onDragExit()
                    }
                }
            }
            return true
        }
        .onChange(of: isDropTargeted) { oldValue, newValue in
            if newValue && isDragging && !isSelected {
                onDragEnter()
            } else if !newValue && isDragging && isSelected {
                onDragExit()
            }
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

#if !os(iOS) || targetEnvironment(macCatalyst)
struct RenameDialogView: View {
    @Binding var name: String
    var onCancel: () -> Void
    var onConfirm: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("이름 변경")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text("새로운 이름을 입력하세요")
                .font(.subheadline)
                .foregroundColor(.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            TextField("폴더 이름", text: $name)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            HStack {
                Spacer()
                Button("취소") {
                    onCancel()
                }
                Button("변경") {
                    onConfirm()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(Spacing.lg)
    }
}
#endif


#Preview {
    FoldersView(
        selectedScreenshots: .constant(Set<String>()),
        isDragging: .constant(false),
        dragItem: nil,
        dragOffset: .zero,
        onDrop: { _ in }
    )
}
