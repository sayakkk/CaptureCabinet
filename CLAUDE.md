# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

CaptureCabinet (캡쳐 캐비넷) is a native iOS app built with SwiftUI that helps users organize screenshots into folders. The app allows users to view recent screenshots from their photo library and drag-and-drop them into custom folders for organization.

## Build and Test Commands

```bash
# Build the project
xcodebuild -scheme CaptureCabinet -configuration Debug build

# Run tests
xcodebuild test -scheme CaptureCabinet -destination 'platform=iOS Simulator,name=iPhone 15'

# Build for release
xcodebuild -scheme CaptureCabinet -configuration Release build

# Clean build folder
xcodebuild clean -scheme CaptureCabinet
```

Open the project in Xcode:
```bash
open CaptureCabinet.xcodeproj
```

## Architecture

### Tech Stack
- **UI Framework**: SwiftUI (iOS)
- **Data Persistence**: Core Data
- **Photo Access**: Photos framework (PHPhotoLibrary, PHAsset)

### Core Data Model

Two main entities defined in `CaptureCabinet.xcdatamodel`:

1. **Folder**
   - `id: UUID` - Unique identifier
   - `name: String` - Folder name
   - `createdAt: Date` - Creation timestamp
   - `screenshots: [Screenshot]` - One-to-many relationship

2. **Screenshot**
   - `id: UUID` - Unique identifier
   - `phAssetID: String` - Reference to PHAsset in user's photo library
   - `createdAt: Date` - Creation timestamp
   - `folder: Folder` - Many-to-one relationship

**Key Point**: Screenshots are not duplicated. The app stores references (`phAssetID`) to photos in the user's photo library, not the images themselves.

### App Structure

The app follows a tab-based navigation pattern with custom drag-and-drop implementation:

```
CaptureCabinetApp (entry point)
└── ContentView
    └── MainTabView (custom tab container)
        ├── RecentScreenshotsView (Tab 0)
        └── FoldersView (Tab 1)
            └── FolderDetailView (navigation destination)
```

**MainTabView** is the orchestrator for the drag-and-drop feature. It:
- Manages tab switching
- Coordinates drag state across tabs
- Renders the drag overlay (DragItemOverlay) that follows the user's gesture
- Automatically switches from Recent to Folders tab when dragging right >150px

### Key Views and Responsibilities

**RecentScreenshotsView** (`Views/RecentScreenshotsView.swift`)
- Fetches screenshots from photo library using PHPhotoLibrary
- Filters for images with `mediaSubtypes.photoScreenshot`
- Displays screenshots in vertical scrolling list
- Handles selection mode and drag gestures
- Loads images asynchronously via PHImageManager
- Note: Includes test photo creation feature (+ button) for development

**FoldersView** (`Views/FoldersView.swift`)
- Displays folders in 3-column grid (LazyVGrid)
- Handles folder CRUD operations via Core Data
- Receives drops from dragged screenshots
- Highlights drop target folder during drag

**FolderDetailView** (`Views/FolderDetailView.swift`)
- Shows screenshots within a specific folder
- 3x3 grid layout using LazyVGrid
- Full-screen image viewer on tap
- Fetches screenshots via Core Data FetchRequest with folder predicate

### Drag-and-Drop Flow

The app implements a custom drag-and-drop system that works across tabs:

1. **User selects screenshots** in RecentScreenshotsView (tap to select)
2. **User begins drag gesture** on a selected screenshot
3. **MainTabView creates DragItem** containing:
   - Asset IDs (PHAsset identifiers)
   - Loaded UIImages (for visual feedback)
   - Start location and current offset
4. **DragItemOverlay renders** stacked preview of selected images
5. **Auto-tab-switch**: When dragging right >150px, automatically switches to FoldersView
6. **Drop on folder**: FolderCardView accepts drop and saves Screenshot entities
7. **Cleanup**: Selection cleared, drag state reset

**Important**: The drag overlay (`DragItemOverlay`) is rendered at the MainTabView level with `zIndex(1000)` so it appears above both tabs during the drag.

### Design System

Centralized in `DesignSystem.swift`:

**Colors**:
- `Color.primaryBlue` - Main accent color
- `Color.backgroundPrimary` - App background (light purple tint)
- `Color.surfacePrimary` - Card backgrounds (white)
- `Color.textPrimary`, `textSecondary`, `textTertiary` - Text hierarchy

**Spacing**: Use `Spacing.xs` through `Spacing.xxxl` (4px to 32px)

**Corner Radius**: Use `CornerRadius.xs` through `CornerRadius.xxl` (4px to 20px)

**Shadow**: Use `Shadow.small`, `Shadow.medium`, `Shadow.large`

### Persistence Layer

**PersistenceController** (`Models/Persistence.swift`)
- Singleton pattern: `PersistenceController.shared`
- Manages NSPersistentContainer with name "CaptureCabinet"
- Injected via environment: `.environment(\.managedObjectContext, persistenceController.container.viewContext)`
- Auto-merges changes from parent context

All Core Data operations use the injected `viewContext`:
```swift
@Environment(\.managedObjectContext) private var viewContext
```

### Photo Library Access

The app requires photo library permissions. Key permission handling in `RecentScreenshotsView.swift`:
- Checks `PHPhotoLibrary.authorizationStatus()`
- Shows alert directing users to Settings if permission denied
- Fetches only screenshots created after `appLaunchTime` (24 hours before app launch)

## Common Development Workflows

### Adding a New Folder Property
1. Open `CaptureCabinet.xcdatamodeld/CaptureCabinet.xcdatamodel/contents`
2. Add attribute to Folder entity
3. Regenerate Core Data classes or update manually
4. Update UI in `FoldersView.swift` and `FolderCardView`

### Adding a New View
1. Create Swift file in `Views/` directory
2. Import SwiftUI and required frameworks
3. If using Core Data, inject environment: `@Environment(\.managedObjectContext)`
4. Add navigation or presentation logic to parent view

### Modifying the Drag-and-Drop Behavior
The custom drag system spans three files:
- `MainTabView.swift` - Orchestration and overlay
- `RecentScreenshotsView.swift` - Drag source (ScreenshotCardView)
- `FoldersView.swift` - Drop target (FolderCardView)

The DragItem struct and callbacks (`onDragStart`, `onDragChange`, `onDragEnd`) coordinate state between these views.

## Testing

- **Unit Tests**: `CaptureCabinetTests/CaptureCabinetTests.swift`
- **UI Tests**: `CaptureCabinetUITests/`

Run tests using the xcodebuild commands above or via Xcode Test Navigator (⌘6).
