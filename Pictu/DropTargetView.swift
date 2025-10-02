import SwiftUI
import UniformTypeIdentifiers

// MARK: - Drop Target View
struct DropTargetView: View {
    @Binding var isDragOver: Bool
    let onDrop: ([NSItemProvider]) -> Bool
    
    var body: some View {
        RoundedRectangle(cornerRadius: AppConstants.DropTarget.cornerRadius)
            .fill(isDragOver ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
            .overlay(
                VStack(spacing: 8) {
                    SwiftUI.Image(systemName: "photo.badge.plus")
                        .font(.system(size: AppConstants.DropTarget.iconSize))
                        .foregroundColor(.secondary)
                    Text("Drop an image here")
                        .foregroundColor(.secondary)
                }
            )
            .padding(AppConstants.DropTarget.padding)
            .onDrop(of: [.image], isTargeted: $isDragOver, perform: onDrop)
    }
}

// MARK: - Drop Target with Overlay
struct DropTargetWithOverlay: View {
    @Binding var isDragOver: Bool
    let onDrop: ([NSItemProvider]) -> Bool
    
    var body: some View {
        ZStack {
            // Base drop target
            RoundedRectangle(cornerRadius: AppConstants.DropTarget.cornerRadius)
                .fill(isDragOver ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
                .overlay(
                    VStack(spacing: 8) {
                        SwiftUI.Image(systemName: "photo.badge.plus")
                            .font(.system(size: AppConstants.DropTarget.iconSize))
                            .foregroundColor(.secondary)
                        Text("Drop an image here")
                            .foregroundColor(.secondary)
                    }
                )
                .padding(AppConstants.DropTarget.padding)
            
            // Drag overlay when dragging over
            if isDragOver {
                RoundedRectangle(cornerRadius: AppConstants.DropTarget.cornerRadius)
                    .fill(Color.blue.opacity(AppConstants.Layout.dragOverlayOpacity))
                    .overlay(
                        VStack(spacing: 8) {
                            SwiftUI.Image(systemName: "photo.badge.plus")
                                .font(.system(size: AppConstants.DropTarget.iconSize))
                                .foregroundColor(.blue)
                            Text("Drop image here")
                                .foregroundColor(.blue)
                                .font(.headline)
                        }
                    )
                    .padding(AppConstants.DropTarget.padding)
            }
        }
        .onDrop(of: [.image], isTargeted: $isDragOver, perform: onDrop)
    }
}
