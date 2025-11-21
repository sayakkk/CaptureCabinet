//
//  ScreenshotWidgetLiveActivity.swift
//  ScreenshotWidget
//
//  Created by saya lee on 11/21/25.
//  iOS 18 Dynamic Island for Screenshot Capture
//

import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Live Activity Data Model
// Note: Attributes are defined in SharedActivityAttributes.swift
// This file should be added to both app and widget targets in Xcode

// MARK: - Live Activity Widget

struct ScreenshotWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ScreenshotWidgetAttributes.self) { context in
            // Lock screen/banner UI
            LockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // EXPANDED VIEW - Modern Design with Enhanced Vibrancy
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 10) {
                        // Vibrant gradient icon
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(red: 0.0, green: 0.5, blue: 1.0), Color(red: 0.3, green: 0.35, blue: 0.9)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 32, height: 32)

                            Image(systemName: "camera.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Screenshot")
                                .font(.system(.caption, design: .rounded, weight: .bold))
                            Text("Select folder")
                                .font(.system(.caption2, design: .rounded, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.isSaving {
                        ProgressView()
                            .tint(Color(red: 0.0, green: 0.5, blue: 1.0))
                            .scaleEffect(0.9)
                    } else if let success = context.state.savedSuccessfully {
                        ZStack {
                            Circle()
                                .fill(success ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                                .frame(width: 32, height: 32)

                            Image(systemName: success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(
                                    success
                                        ? LinearGradient(colors: [.green, Color(red: 0.2, green: 0.8, blue: 0.3)], startPoint: .top, endPoint: .bottom)
                                        : LinearGradient(colors: [.red, Color(red: 1.0, green: 0.3, blue: 0.3)], startPoint: .top, endPoint: .bottom)
                                )
                        }
                    }
                }

                DynamicIslandExpandedRegion(.center) {
                    // Empty - folders go in bottom region
                }

                DynamicIslandExpandedRegion(.bottom) {
                    FolderGridView(
                        folders: context.state.folders,
                        selectedFolderID: context.state.selectedFolderID
                    )
                }

            } compactLeading: {
                // COMPACT LEADING - Vibrant camera icon
                Image(systemName: "camera.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 0.0, green: 0.5, blue: 1.0), Color(red: 0.3, green: 0.35, blue: 0.9)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

            } compactTrailing: {
                // COMPACT TRAILING - Vibrant folder icon
                Image(systemName: "folder.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 1.0, green: 0.58, blue: 0.0), Color(red: 1.0, green: 0.45, blue: 0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

            } minimal: {
                // MINIMAL - Vibrant camera pulse
                Image(systemName: "camera.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 0.0, green: 0.5, blue: 1.0), Color(red: 0.3, green: 0.35, blue: 0.9)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .keylineTint(Color(red: 0.0, green: 0.5, blue: 1.0))
        }
    }
}

// MARK: - Lock Screen View (Modern Design)

struct LockScreenView: View {
    let context: ActivityViewContext<ScreenshotWidgetAttributes>

    var body: some View {
        HStack(spacing: 14) {
            // Enhanced icon with gradient
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.0, green: 0.5, blue: 1.0), Color(red: 0.3, green: 0.35, blue: 0.9)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)

                Image(systemName: "camera.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Screenshot Captured")
                    .font(.system(.headline, design: .rounded, weight: .bold))

                if let selectedFolder = context.state.folders.first(where: { $0.id == context.state.selectedFolderID }) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green.gradient)
                        Text("Saved to \(selectedFolder.name)")
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "hand.tap.fill")
                            .font(.caption)
                            .foregroundStyle(.blue.gradient)
                        Text("Tap to organize")
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()
        }
        .padding(16)
        .activityBackgroundTint(Color(red: 0.0, green: 0.48, blue: 1.0).opacity(0.08))
        .activitySystemActionForegroundColor(Color(red: 0.0, green: 0.48, blue: 1.0))
    }
}

// MARK: - Folder Grid View (Modern Design)

struct FolderGridView: View {
    let folders: [ScreenshotWidgetAttributes.FolderData]
    let selectedFolderID: String?

    var body: some View {
        if folders.isEmpty {
            VStack(spacing: 10) {
                // Modern gradient icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.gray.opacity(0.2), Color.gray.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)

                    Image(systemName: "folder.badge.plus")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.gray, Color.gray.opacity(0.7)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }

                Text("No folders yet")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text("Create folders in the app")
                    .font(.system(.caption2, design: .rounded, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        } else {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(folders.prefix(6)) { folder in
                    FolderButton(
                        folder: folder,
                        isSelected: folder.id == selectedFolderID
                    )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - Folder Button (Modern Design)

struct FolderButton: View {
    let folder: ScreenshotWidgetAttributes.FolderData
    let isSelected: Bool

    var body: some View {
        Button(intent: SelectFolderIntent(folderID: folder.id)) {
            VStack(spacing: 6) {
                // Enhanced icon with gradient
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 0.0, green: 0.5, blue: 1.0), Color(red: 0.3, green: 0.35, blue: 0.9)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 38, height: 38)

                        Image(systemName: "checkmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                    } else {
                        Image(systemName: "folder.fill")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(red: 1.0, green: 0.58, blue: 0.0), Color(red: 1.0, green: 0.45, blue: 0.0)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                }

                Text(folder.name)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .lineLimit(1)
                    .foregroundStyle(isSelected ? .primary : .secondary)

                if folder.screenshotCount > 0 {
                    Text("\(folder.screenshotCount)")
                        .font(.system(.caption2, design: .rounded, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.gray.opacity(0.15))
                        )
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        isSelected
                            ? LinearGradient(
                                colors: [Color.blue.opacity(0.2), Color.blue.opacity(0.1)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            : LinearGradient(
                                colors: [Color.gray.opacity(0.08), Color.gray.opacity(0.04)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        isSelected
                            ? LinearGradient(
                                colors: [Color.blue.opacity(0.6), Color.blue.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [Color.white.opacity(0.2), Color.white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .shadow(color: isSelected ? Color.blue.opacity(0.25) : Color.black.opacity(0.05), radius: isSelected ? 8 : 2, x: 0, y: isSelected ? 4 : 1)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview Data

extension ScreenshotWidgetAttributes {
    fileprivate static var preview: ScreenshotWidgetAttributes {
        ScreenshotWidgetAttributes(sessionID: "preview-session")
    }
}

extension ScreenshotWidgetAttributes.ContentState {
    fileprivate static var initial: ScreenshotWidgetAttributes.ContentState {
        ScreenshotWidgetAttributes.ContentState(
            screenshotAssetID: nil,
            screenshotTimestamp: Date(),
            folders: [
                .init(id: "1", name: "Work", screenshotCount: 5),
                .init(id: "2", name: "Personal", screenshotCount: 12),
                .init(id: "3", name: "Travel", screenshotCount: 8),
                .init(id: "4", name: "Ideas", screenshotCount: 3)
            ],
            selectedFolderID: nil,
            isSaving: false,
            savedSuccessfully: nil
        )
    }

    fileprivate static var selected: ScreenshotWidgetAttributes.ContentState {
        ScreenshotWidgetAttributes.ContentState(
            screenshotAssetID: "sample-asset-id",
            screenshotTimestamp: Date(),
            folders: [
                .init(id: "1", name: "Work", screenshotCount: 5),
                .init(id: "2", name: "Personal", screenshotCount: 12),
                .init(id: "3", name: "Travel", screenshotCount: 8),
                .init(id: "4", name: "Ideas", screenshotCount: 3)
            ],
            selectedFolderID: "2",
            isSaving: false,
            savedSuccessfully: true
        )
    }

    fileprivate static var empty: ScreenshotWidgetAttributes.ContentState {
        ScreenshotWidgetAttributes.ContentState(
            screenshotAssetID: nil,
            screenshotTimestamp: Date(),
            folders: [],
            selectedFolderID: nil,
            isSaving: false,
            savedSuccessfully: nil
        )
    }
}

#Preview("Notification", as: .content, using: ScreenshotWidgetAttributes.preview) {
   ScreenshotWidgetLiveActivity()
} contentStates: {
    ScreenshotWidgetAttributes.ContentState.initial
    ScreenshotWidgetAttributes.ContentState.selected
    ScreenshotWidgetAttributes.ContentState.empty
}
