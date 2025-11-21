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
                // Header
                HStack {
                    Text("폴더")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.textPrimary)
                    
                    Spacer()
                    
                    Button(action: {
                        showingAddFolder = true
                    }) {
                        Image(systemName: "plus")
                            .font(.title3)
                            .foregroundColor(.primaryBlue)
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
                
                Divider()
                    .background(Color.textTertiary.opacity(0.3))
                
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
        VStack(spacing: Spacing.sm) {
            Spacer()
            Text(folder.name ?? "Untitled")
                .font(.body)
                .fontWeight(.bold)
                .foregroundColor(.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .center)
            Spacer()
        }
        .frame(width: 100, height: 100)
        .padding(Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .fill(Color.surfacePrimary)
        )
        .overlay(
            Group {
                if isSelected && isDragging {
                    RoundedRectangle(cornerRadius: CornerRadius.lg)
                        .stroke(Color.primaryBlue, lineWidth: 3)
                } else if isDropTargeted {
                    RoundedRectangle(cornerRadius: CornerRadius.lg)
                        .stroke(Color.primaryBlue.opacity(0.5), lineWidth: 2)
                }
            }
        )
        .shadow(color: Shadow.small, radius: 2, x: 0, y: 1)
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isHovered)
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
