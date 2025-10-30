//
//  FoldersView.swift
//  CaptureCabinet
//
//  Created by saya lee on 10/1/25.
//

import SwiftUI
import CoreData

struct FoldersView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Folder.createdAt, ascending: true)],
        animation: .default
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
                                    onTap: {
                                        if !selectedScreenshots.isEmpty {
                                            saveScreenshotsToFolder(folder: folder)
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
    
    private func saveScreenshotsToFolder(folder: Folder) {
        for assetID in selectedScreenshots {
            let screenshot = Screenshot(context: viewContext)
            screenshot.id = UUID()
            screenshot.phAssetID = assetID
            screenshot.createdAt = Date()
            screenshot.folder = folder
        }
        
        do {
            try viewContext.save()
            // Clear selected screenshots
            selectedScreenshots.removeAll()
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
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovered = false
    
    private var screenshotCount: Int {
        folder.screenshots?.count ?? 0
    }
    
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
    FoldersView(selectedScreenshots: .constant(Set<String>()))
}
