import SwiftUI
import UniformTypeIdentifiers


struct FixedImageView: NSViewRepresentable {
    let image: NSImage

    func makeNSView(context: Context) -> NSImageView {
        let imageView = NSImageView()
        imageView.imageAlignment = .alignCenter
        imageView.imageScaling = .scaleNone
        imageView.image = ImageSizing.scaledImage(for: image)
        return imageView
    }

    func updateNSView(_ imageView: NSImageView, context: Context) {
        imageView.image = ImageSizing.scaledImage(for: image)
    }
    
}

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var isDragOver = false

    var body: some View {
        VStack(spacing: 0) {
            // Image or default content - anchored to top
            if let image = appState.droppedImage {
                FixedImageView(image: image)
                    .cornerRadius(AppConstants.Layout.cornerRadius)
                    .padding(16)
            } else {
                // Show the same drop target as the settings Images pane
                RoundedRectangle(cornerRadius: 12)
                    .fill(isDragOver ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
                    .overlay(
                        VStack(spacing: 8) {
                            SwiftUI.Image(systemName: "photo.badge.plus")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            Text("Drop an image here")
                                .foregroundColor(.secondary)
                        }
                    )
                    .padding(8)
            }
            
        }
        .onDrop(of: [.image], isTargeted: $isDragOver) { providers in
            ImageDropHandler.handleDrop(providers: providers, appState: appState)
        }
        .background(
            KeyEventHandlingView { keyCode in
                if keyCode == AppConstants.KeyCodes.escape {
                    // Close the popover
                    NSApp.sendAction(#selector(AppDelegate.closePopover), to: nil, from: nil)
                } else if keyCode == AppConstants.KeyCodes.leftArrow {
                    appState.navigateToPreviousImage()
                } else if keyCode == AppConstants.KeyCodes.rightArrow {
                    appState.navigateToNextImage()
                }
            }
        )
        .overlay(
            // Drag overlay when dragging over
            isDragOver ? 
            RoundedRectangle(cornerRadius: AppConstants.Layout.cornerRadius)
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
            : nil
        )
        .alert("Error", isPresented: $appState.showError) {
            Button("OK") { appState.showError = false }
        } message: {
            Text(appState.errorMessage ?? "Unknown error")
        }
    }
    
    
}

